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

    // MARK: - State

    @State private var showIMAPTest = false

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            MainView()
                .modelContainer(modelContainer)
                .sheet(isPresented: $showIMAPTest) {
                    IMAPTestView()
                }
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

            // Debug menu for testing
            CommandMenu("Debug") {
                Button("Test IMAP Connection") {
                    showIMAPTest = true
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Divider()

                Button("Popola Dati di Test") {
                    TestDataGenerator.populateTestData(context: modelContainer.mainContext)
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Button("Cancella Dati di Test") {
                    TestDataGenerator.clearTestData(context: modelContainer.mainContext)
                }
                .keyboardShortcut("x", modifiers: [.command, .shift])
            }
        }
    }
}
