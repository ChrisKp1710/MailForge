import SwiftUI

/// Main entry point for MailForge app
@main
struct MailForgeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Custom menu commands will go here
            CommandGroup(replacing: .newItem) {
                Button("New Email") {
                    // TODO: Open composer
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
