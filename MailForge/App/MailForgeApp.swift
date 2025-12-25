import SwiftUI
import SwiftData

/// Main entry point for MailForge app
@main
struct MailForgeApp: App {

    // MARK: - Model Container

    var modelContainer: ModelContainer = {
        let schema = Schema([
            Account.self,
            Folder.self,
            Message.self,
            Attachment.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            MainView()
                .modelContainer(modelContainer)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Custom menu commands
            CommandGroup(replacing: .newItem) {
                Button("New Email") {
                    // TODO: Open composer
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
