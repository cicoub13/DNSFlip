//
//  MenuBarExtra.swift
//  DNSSwitcher
//
//  Created by Cyril Beslay Home on 01/04/2023.
//

import SwiftUI

@main
struct DNSSwitcherApp: App {
    // 1
    @State var currentNumber: String = "1"
    
    var body: some Scene {
        // 2
        MenuBarExtra(currentNumber, systemImage: "\(currentNumber).circle") {
            // 3
            Button("One") {
                currentNumber = "1"
            }
            Button("Two") {
                currentNumber = "2"
            }
            Button("Three") {
                currentNumber = "3"
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }.keyboardShortcut("q")
        }
    }
}
