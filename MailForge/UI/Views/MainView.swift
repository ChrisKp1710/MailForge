import SwiftUI
import SwiftData

// MARK: - Main View

/// Main application view with 3-column layout
struct MainView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @State private var selectedAccount: Account?
    @State private var selectedFolder: Folder?
    @State private var selectedMessage: Message?

    @State private var showAccountSetup = false

    // MARK: - Queries

    @Query(sort: \Account.emailAddress) private var accounts: [Account]

    // MARK: - Body

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            // Sidebar - Account & Folders
            SidebarView(
                accounts: accounts,
                selectedAccount: $selectedAccount,
                selectedFolder: $selectedFolder,
                onAddAccount: { showAccountSetup = true }
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)

        } content: {
            // Message List
            MessageListView(
                folder: selectedFolder,
                selectedMessage: $selectedMessage
            )
            .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: 600)

        } detail: {
            // Message Detail
            if let message = selectedMessage {
                MessageDetailView(message: message)
            } else {
                ContentUnavailableView(
                    "Nessun messaggio selezionato",
                    systemImage: "envelope.open",
                    description: Text("Seleziona un messaggio dalla lista per visualizzarlo")
                )
            }
        }
        .sheet(isPresented: $showAccountSetup) {
            AccountSetupView()
        }
        .onAppear {
            // Set initial selection
            if selectedAccount == nil {
                selectedAccount = accounts.first
            }
            if selectedFolder == nil, let account = selectedAccount {
                selectedFolder = account.folders.first { $0.name == "INBOX" } ?? account.folders.first
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .modelContainer(for: [Account.self, Folder.self, Message.self, Attachment.self])
}
