import SwiftUI

struct DNSConfigForm: View {
    @Binding var config: DNSConfig?
    var onSave: (DNSConfig) -> Void
    
    @State private var name: String = ""
    @State private var primaryDNS: String = ""
    @State private var secondaryDNS: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Name", text: $name)
                TextField("Primary DNS", text: $primaryDNS)
                TextField("Secondary DNS", text: $secondaryDNS)
            }
            .navigationTitle("DNS Configuration")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        config = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let config = config {
                            onSave(DNSConfig(name: name, primaryDNS: primaryDNS, secondaryDNS: secondaryDNS))
                        } else {
                            onSave(DNSConfig(name: name, primaryDNS: primaryDNS, secondaryDNS: secondaryDNS))
                        }
                    }
                }
            }
            .onAppear {
                if let config = config {
                    name = config.name
                    primaryDNS = config.primaryDNS
                    secondaryDNS = config.secondaryDNS
                }
            }
        }
    }
}
