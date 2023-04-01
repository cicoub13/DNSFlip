import Foundation

func changeDNSSettings(primaryDNS: String, secondaryDNS: String) {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
    
    let service = "Wi-Fi" // Change this to the appropriate network service name
    task.arguments = ["-setdnsservers", service, primaryDNS, secondaryDNS]
    
    do {
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus == 0 {
            print("DNS settings successfully changed.")
        } else {
            print("Error: Failed to change DNS settings.")
        }
    } catch {
        print("Error: \(error.localizedDescription)")
    }
}

guard CommandLine.argc == 3 else {
    print("Usage: DNSSwitcherHelper <primaryDNS> <secondaryDNS>")
    exit(1)
}

let primaryDNS = CommandLine.arguments[1]
let secondaryDNS = CommandLine.arguments[2]

changeDNSSettings(primaryDNS: primaryDNS, secondaryDNS: secondaryDNS)
