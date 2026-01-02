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
            // TEMPORARY: Force sync to update envelope data after SwiftMail migration
            // TODO: Remove this after confirming email bodies work correctly
            let shouldSync = true // shouldPerformSync(for: account)

            if !shouldSync {
                Logger.debug("Account \(account.emailAddress) was synced recently, skipping", category: .email)
                continue
            }

            Logger.warning("🔄 FORCE SYNC: Forcing sync to update message data with correct envelopes", category: .email)

            // Sync if account has no folders or very few folders (< 2)
            if account.folders.isEmpty || account.folders.count < 2 {
                Logger.info("Auto-syncing folders for account: \(account.emailAddress)", category: .email)

                do {
                    try await accountManager.syncFolders(for: account)
                    Logger.info("Auto-sync folders completed for \(account.emailAddress)", category: .email)

                    // After folders are synced, sync messages for important folders
                    await syncMessagesForImportantFolders(account: account, accountManager: accountManager)

                    // Update last sync date
                    account.lastSyncDate = Date()
                    try? modelContext.save()

                } catch {
                    Logger.error("Auto-sync folders failed for \(account.emailAddress)", error: error, category: .email)
                    // Continue with other accounts even if one fails
                }
            } else {
                Logger.debug("Account \(account.emailAddress) already has folders", category: .email)

                // Even if folders exist, check if messages need syncing
                await syncMessagesForImportantFolders(account: account, accountManager: accountManager)

                // Update last sync date
                account.lastSyncDate = Date()
                try? modelContext.save()
            }
        }

        Logger.info("Auto-sync check completed", category: .email)
    }

    /// Check if sync should be performed based on last sync time
    /// - Parameter account: Account to check
    /// - Returns: True if sync should be performed
    private func shouldPerformSync(for account: Account) -> Bool {
        guard let lastSync = account.lastSyncDate else {
            // Never synced, should sync
            return true
        }

        // Don't sync if last sync was less than 5 minutes ago
        let minimumSyncInterval: TimeInterval = 5 * 60 // 5 minutes
        let timeSinceLastSync = Date().timeIntervalSince(lastSync)

        return timeSinceLastSync >= minimumSyncInterval
    }

    /// Sync messages for all folders in the account
    @MainActor
    private func syncMessagesForImportantFolders(account: Account, accountManager: AccountManager) async {
        Logger.info("Syncing messages for all folders: \(account.emailAddress)", category: .email)

        // Priority order: INBOX first, then other important folders, then all others
        let priorityOrder: [FolderType] = [.inbox, .sent, .drafts, .trash]

        // Separate folders into priority and others
        var priorityFolders: [Folder] = []
        var otherFolders: [Folder] = []

        for folder in account.folders {
            if priorityOrder.contains(folder.type) {
                priorityFolders.append(folder)
            } else {
                otherFolders.append(folder)
            }
        }

        // Sort priority folders by their priority order
        priorityFolders.sort { folder1, folder2 in
            let index1 = priorityOrder.firstIndex(of: folder1.type) ?? Int.max
            let index2 = priorityOrder.firstIndex(of: folder2.type) ?? Int.max
            return index1 < index2
        }

        // Combine: priority folders first, then others
        let allFolders = priorityFolders + otherFolders

        for folder in allFolders {
            // Check if messages need to be re-synced (corrupted data with unknown@unknown.com)
            let hasCorruptedMessages = folder.messages.contains { $0.from == "unknown@unknown.com" }

            if hasCorruptedMessages {
                Logger.warning("Folder '\(folder.name)' has corrupted messages, deleting and re-syncing", category: .email)

                // Delete all corrupted messages
                for message in folder.messages {
                    modelContext.delete(message)
                }

                // Save deletion
                try? modelContext.save()
            } else if !folder.messages.isEmpty {
                // Check if this folder needs force resync (to fix stale UIDs from old parser)
                let needsForceResync = folder.name == "INBOX" ||
                                      folder.path == "INBOX" ||
                                      priorityFolders.contains(folder)

                if needsForceResync {
                    Logger.warning("🔄 Folder '\(folder.name)' needs force resync to fix stale UIDs from old parser", category: .email)
                    // Continue to resync this folder
                } else {
                    Logger.debug("Folder '\(folder.name)' already has valid messages, skipping", category: .email)
                    continue
                }
            }

            Logger.info("Syncing messages for folder: \(folder.name)", category: .email)

            // Use larger limit for INBOX to show more recent messages
            let messageLimit: Int
            if folder.name == "INBOX" || folder.path == "INBOX" {
                messageLimit = 200  // Show last 200 messages for INBOX
            } else if priorityFolders.contains(folder) {
                messageLimit = 100  // Increased from 50
            } else {
                messageLimit = 50   // Increased from 20
            }

            // Force resync for folders with existing messages (to fix stale UIDs)
            let forceResync = !folder.messages.isEmpty

            do {
                try await accountManager.syncMessages(for: folder, limit: messageLimit, forceResync: forceResync)
                Logger.info("Successfully synced messages for '\(folder.name)'", category: .email)
            } catch {
                Logger.error("Failed to sync messages for '\(folder.name)'", error: error, category: .email)
                // Continue with other folders even if one fails
            }
        }

        Logger.info("All folders message sync completed for \(account.emailAddress)", category: .email)
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .modelContainer(for: [Account.self, Folder.self, Message.self, Attachment.self])
}
