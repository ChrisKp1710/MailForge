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
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    // MARK: - Queries

    @Query(sort: \Account.emailAddress) private var accounts: [Account]

    // MARK: - Body

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
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
                VStack(spacing: 20) {
                    Image(systemName: "envelope.open")
                        .font(.system(size: 64))
                        .foregroundStyle(.tertiary)
                        .symbolRenderingMode(.hierarchical)

                    VStack(spacing: 8) {
                        Text("Nessun messaggio selezionato")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("Seleziona un messaggio dalla lista\nper visualizzarlo")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Material.regular)
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

            // Auto-sync folders for accounts without folders
            Task {
                await syncFoldersForAccountsWithoutFolders()
            }
        }
    }

    // MARK: - Auto-sync

    /// Automatically sync folders for accounts that don't have any folders yet
    @MainActor
    private func syncFoldersForAccountsWithoutFolders() async {
        Logger.info("Checking accounts for folder sync...", category: .email)

        let accountManager = AccountManager(modelContext: modelContext)

        for account in accounts {
            // Sync if account has no folders or very few folders (< 2)
            if account.folders.isEmpty || account.folders.count < 2 {
                Logger.info("Auto-syncing folders for account: \(account.emailAddress)", category: .email)

                do {
                    try await accountManager.syncFolders(for: account)
                    Logger.info("Auto-sync completed for \(account.emailAddress)", category: .email)
                } catch {
                    Logger.error("Auto-sync failed for \(account.emailAddress)", error: error, category: .email)
                    // Continue with other accounts even if one fails
                }
            } else {
                Logger.debug("Account \(account.emailAddress) already has folders, skipping auto-sync", category: .email)
            }
        }

        Logger.info("Auto-sync check completed", category: .email)
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .modelContainer(for: [Account.self, Folder.self, Message.self, Attachment.self])
}
