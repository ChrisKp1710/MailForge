import Foundation
import SwiftData

// MARK: - Account Manager

/// Manages email accounts - creation, authentication, switching, deletion
@Observable
final class AccountManager {

    // MARK: - Properties

    /// SwiftData model context
    private let modelContext: ModelContext

    /// Keychain manager
    private let keychainManager = KeychainManager()

    /// Currently selected account
    var currentAccount: Account?

    /// All accounts
    private(set) var accounts: [Account] = []

    /// Logger category
    private let logCategory: Logger.Category = .email

    // MARK: - Initialization

    /// Initialize account manager
    /// - Parameter modelContext: SwiftData model context
    init(modelContext: ModelContext) {
        self.modelContext = modelContext

        // Load accounts
        loadAccounts()

        // Set first account as current if available
        if currentAccount == nil {
            currentAccount = accounts.first
        }

        Logger.debug("Account manager initialized with \(accounts.count) accounts", category: logCategory)
    }

    // MARK: - Load Accounts

    /// Load all accounts from SwiftData
    private func loadAccounts() {
        do {
            let descriptor = FetchDescriptor<Account>(
                sortBy: [SortDescriptor(\.email)]
            )

            accounts = try modelContext.fetch(descriptor)

            Logger.info("Loaded \(accounts.count) accounts", category: logCategory)
        } catch {
            Logger.error("Failed to load accounts", error: error, category: logCategory)
            accounts = []
        }
    }

    // MARK: - Add Account

    /// Add new account
    /// - Parameters:
    ///   - email: Email address
    ///   - password: Password
    ///   - preset: Account preset configuration
    ///   - displayName: Optional display name
    /// - Returns: Created account
    @discardableResult
    func addAccount(
        email: String,
        password: String,
        preset: AccountPreset,
        displayName: String? = nil
    ) async throws -> Account {
        Logger.info("Adding account: \(email)", category: logCategory)

        // Validate email
        guard isValidEmail(email) else {
            throw AccountError.invalidEmail(email)
        }

        // Check if account already exists
        if accounts.contains(where: { $0.email == email }) {
            throw AccountError.duplicateAccount(email)
        }

        // Create account model
        let account = Account(
            email: email,
            displayName: displayName ?? email,
            type: preset.type,
            imapServer: preset.imapHost,
            imapPort: preset.imapPort,
            imapUseTLS: preset.imapUseTLS,
            smtpServer: preset.smtpHost,
            smtpPort: preset.smtpPort,
            smtpUseTLS: preset.smtpUseTLS
        )

        // Save password to keychain
        try account.savePassword(password, using: keychainManager)

        // Save account to SwiftData
        modelContext.insert(account)
        try modelContext.save()

        // Reload accounts
        loadAccounts()

        // Set as current if first account
        if currentAccount == nil {
            currentAccount = account
        }

        Logger.info("Account added successfully: \(email)", category: logCategory)

        return account
    }

    // MARK: - Test Connection

    /// Test IMAP connection
    /// - Parameter account: Account to test
    /// - Returns: True if connection successful
    func testIMAPConnection(for account: Account) async throws -> Bool {
        Logger.info("Testing IMAP connection for \(account.email)...", category: logCategory)

        guard let password = try account.loadPassword(using: keychainManager) else {
            throw AccountError.passwordNotFound(account.email)
        }

        let client = IMAPClient(
            host: account.imapServer,
            port: account.imapPort,
            useTLS: account.imapUseTLS,
            username: account.email,
            password: password
        )

        do {
            try await client.connect()
            try await client.disconnect()

            Logger.info("IMAP connection test successful", category: logCategory)
            return true
        } catch {
            Logger.error("IMAP connection test failed", error: error, category: logCategory)
            throw error
        }
    }

    /// Test SMTP connection
    /// - Parameter account: Account to test
    /// - Returns: True if connection successful
    func testSMTPConnection(for account: Account) async throws -> Bool {
        Logger.info("Testing SMTP connection for \(account.email)...", category: logCategory)

        guard let password = try account.loadPassword(using: keychainManager) else {
            throw AccountError.passwordNotFound(account.email)
        }

        let client = SMTPClient(
            host: account.smtpServer,
            port: account.smtpPort,
            useTLS: account.smtpUseTLS,
            username: account.email,
            password: password
        )

        do {
            try await client.connect()
            try await client.authenticate()
            try await client.disconnect()

            Logger.info("SMTP connection test successful", category: logCategory)
            return true
        } catch {
            Logger.error("SMTP connection test failed", error: error, category: logCategory)
            throw error
        }
    }

    // MARK: - Switch Account

    /// Switch to different account
    /// - Parameter account: Account to switch to
    func switchToAccount(_ account: Account) {
        Logger.info("Switching to account: \(account.email)", category: logCategory)

        currentAccount = account
    }

    // MARK: - Update Account

    /// Update account settings
    /// - Parameters:
    ///   - account: Account to update
    ///   - displayName: New display name (optional)
    ///   - password: New password (optional)
    func updateAccount(
        _ account: Account,
        displayName: String? = nil,
        password: String? = nil
    ) throws {
        Logger.info("Updating account: \(account.email)", category: logCategory)

        // Update display name
        if let displayName = displayName {
            account.displayName = displayName
        }

        // Update password
        if let password = password {
            try account.savePassword(password, using: keychainManager)
        }

        // Save changes
        try modelContext.save()

        Logger.info("Account updated successfully", category: logCategory)
    }

    // MARK: - Delete Account

    /// Delete account
    /// - Parameter account: Account to delete
    func deleteAccount(_ account: Account) throws {
        Logger.info("Deleting account: \(account.email)", category: logCategory)

        // Delete password from keychain
        try? account.deletePassword(using: keychainManager)

        // Delete from SwiftData (will cascade delete folders and messages)
        modelContext.delete(account)
        try modelContext.save()

        // Reload accounts
        loadAccounts()

        // Switch to another account if current was deleted
        if currentAccount == account {
            currentAccount = accounts.first
        }

        Logger.info("Account deleted successfully", category: logCategory)
    }

    // MARK: - Unified Inbox

    /// Get all unread messages across all accounts
    /// - Returns: Array of unread messages
    func getUnifiedInbox() throws -> [Message] {
        var allMessages: [Message] = []

        for account in accounts {
            for folder in account.folders {
                let descriptor = FetchDescriptor<Message>(
                    predicate: #Predicate { message in
                        message.folder == folder && !message.isRead
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )

                let messages = try modelContext.fetch(descriptor)
                allMessages.append(contentsOf: messages)
            }
        }

        // Sort by date
        allMessages.sort { $0.date > $1.date }

        Logger.debug("Unified inbox: \(allMessages.count) unread messages", category: logCategory)

        return allMessages
    }

    /// Get total unread count across all accounts
    /// - Returns: Total unread count
    func getTotalUnreadCount() throws -> Int {
        var totalCount = 0

        for account in accounts {
            for folder in account.folders {
                let descriptor = FetchDescriptor<Message>(
                    predicate: #Predicate { message in
                        message.folder == folder && !message.isRead
                    }
                )

                let count = try modelContext.fetchCount(descriptor)
                totalCount += count
            }
        }

        return totalCount
    }

    // MARK: - Validation

    /// Validate email address format
    /// - Parameter email: Email address
    /// - Returns: True if valid
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}
