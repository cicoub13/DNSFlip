import SwiftUI

struct DNSConfig: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var primaryDNS: String
    var secondaryDNS: String
}

struct DNSConfigurationsView: View {
    @State private var dnsConfigs: [DNSConfig] = [
        DNSConfig(name: "OpenDNS", primaryDNS: "208.67.222.222", secondaryDNS: "208.67.220.220")
    ]
    @State private var selectedConfig: DNSConfig?
    @State private var showingForm = false
    @State private var formConfig: DNSConfig?
    
    var body: some View {
        VStack {
            List(selection: $selectedConfig) {
                ForEach(dnsConfigs) { config in
                    Text(config.name)
                }
            }
            
            HStack {
                Button("Add") {
                    formConfig = DNSConfig(name: "", primaryDNS: "", secondaryDNS: "")
                    showingForm.toggle()
                }
                
                Button("Change DNS") {
                                    if let config = selectedConfig {
                                        changeDNSSettings(config: config)
                                    }
                                }
                                .disabled(selectedConfig == nil)
                            
                
                Button("Edit") {
                    if let config = selectedConfig {
                        formConfig = config
                        showingForm.toggle()
                    }
                }
                .disabled(selectedConfig == nil)
                
                Button("Remove") {
                    if let config = selectedConfig {
                        dnsConfigs.removeAll { $0.id == config.id }
                    }
                }
                .disabled(selectedConfig == nil)
            }
            .padding()
        }
        .sheet(isPresented: $showingForm) {
            DNSConfigForm(config: $formConfig) { newConfig in
                if let index = dnsConfigs.firstIndex(where: { $0.id == newConfig.id }) {
                    dnsConfigs[index] = newConfig
                } else {
                    dnsConfigs.append(newConfig)
                }
                showingForm = false
            }
        }
    }


    func changeDNSSettings(config: DNSConfig) {
        let helperURL = Bundle.main.url(forResource: "DNSChangerHelper", withExtension: "bundle")!
        
        let task = Process()
        task.executableURL = helperURL
        task.arguments = [config.primaryDNS, config.secondaryDNS]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)
            
            if task.terminationStatus == 0 {
                print("DNS settings successfully changed.")
            } else {
                print("Error: Failed to change DNS settings.")
                if let output = output {
                    print("Output: \(output)")
                }
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }

}
