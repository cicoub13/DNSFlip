import Cocoa
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var popover: NSPopover!
    var statusBarItem: NSStatusItem!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let contentView = DNSConfigurationsView()

        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 240)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)

        let statusBar = NSStatusBar.system
        statusBarItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        statusBarItem.button?.title = "DNSSwitcher"
        statusBarItem.button?.action = #selector(togglePopover(_:))
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            if let button = statusBarItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}
