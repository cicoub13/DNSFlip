import SwiftUI

enum ConnectivityState { case testing, reachable, unreachable }

struct ProfileEditorView: View {
    let mode: ProfileEditorMode
    let profileStore: ProfileStore
    let onDismiss: () -> Void

    @State private var name: String
    @State private var serverFields: [String]
    @State private var connectivity: [String: ConnectivityState] = [:]
    @State private var probeTask: Task<Void, Never>?

    init(mode: ProfileEditorMode, profileStore: ProfileStore, onDismiss: @escaping () -> Void) {
        self.mode = mode
        self.profileStore = profileStore
        self.onDismiss = onDismiss
        switch mode {
        case .add:
            _name = State(initialValue: "")
            _serverFields = State(initialValue: [""])
        case .edit(let profile):
            _name = State(initialValue: profile.name)
            _serverFields = State(initialValue: profile.servers.isEmpty ? [""] : profile.servers)
        }
    }

    private var isAdding: Bool {
        if case .add = mode { return true }
        return false
    }

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty ||
        serverFields.contains(where: { fieldIsInvalid($0) })
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isAdding ? "Nouveau profil" : "Modifier le profil")
                    .font(.title2.weight(.semibold))
                Text("Configure un nom et les serveurs DNS pour ce profil.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(EdgeInsets(top: 20, leading: 20, bottom: 12, trailing: 20))

            Divider()

            Form {
                Section("Nom") {
                    TextField("Ex. : Cloudflare", text: $name)
                }
                Section {
                    ForEach(serverFields.indices, id: \.self) { idx in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                TextField("1.1.1.1 ou 2606:4700:4700::1111", text: $serverFields[idx])
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(
                                                fieldIsInvalid(serverFields[idx]) ? Color.red : Color.clear,
                                                lineWidth: 1.5
                                            )
                                    )
                                connectivityIndicator(for: serverFields[idx])
                                Button {
                                    serverFields.remove(at: idx)
                                    if serverFields.isEmpty { serverFields.append("") }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Supprimer ce serveur")
                            }
                            if fieldIsInvalid(serverFields[idx]) {
                                Label("Adresse IP invalide", systemImage: "exclamationmark.circle")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    Button {
                        serverFields.append("")
                    } label: {
                        Label("Ajouter un serveur", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                } header: {
                    Text("Serveurs DNS")
                } footer: {
                    Text("Laisser vide pour utiliser le DNS fourni par le routeur (DHCP).")
                }
            }
            .formStyle(.grouped)
            .onAppear { probe(debounce: false) }
            .onChange(of: serverFields) { _ in probe(debounce: true) }

            Divider()
            HStack {
                Spacer()
                Button("Annuler") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Enregistrer") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isSaveDisabled)
            }
            .padding(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
        }
        .frame(minWidth: 420, idealWidth: 480)
        .onDisappear { probeTask?.cancel() }
    }

    @ViewBuilder
    private func connectivityIndicator(for field: String) -> some View {
        let addr = field.trimmingCharacters(in: .whitespaces)
        if !addr.isEmpty && !fieldIsInvalid(addr) {
            switch connectivity[addr] {
            case nil:
                Color.clear.frame(width: 16, height: 16)
            case .testing:
                ProgressView().controlSize(.mini).frame(width: 16, height: 16)
            case .reachable:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
                    .frame(width: 16, height: 16)
            case .unreachable:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Color.orange)
                    .frame(width: 16, height: 16)
            }
        }
    }

    private func probe(debounce: Bool) {
        probeTask?.cancel()
        probeTask = Task {
            if debounce { try? await Task.sleep(for: .milliseconds(600)) }
            guard !Task.isCancelled else { return }
            let addrs = serverFields
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && isValidIP($0) }
            let addrSet = Set(addrs)
            connectivity = connectivity.filter { addrSet.contains($0.key) }
            for addr in addrs { connectivity[addr] = .testing }
            await withTaskGroup(of: (String, Bool).self) { group in
                for addr in addrs {
                    let a = addr
                    group.addTask { (a, await probeDNSServer(a)) }
                }
                for await (addr, ok) in group {
                    guard !Task.isCancelled else { return }
                    connectivity[addr] = ok ? .reachable : .unreachable
                }
            }
        }
    }

    private func fieldIsInvalid(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && !isValidIP(trimmed)
    }

    private func save() {
        let servers = serverFields
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        switch mode {
        case .add:
            profileStore.add(DNSProfile(name: trimmedName, servers: servers))
        case .edit(let original):
            profileStore.update(DNSProfile(id: original.id, name: trimmedName, servers: servers))
        }
        onDismiss()
    }
}
