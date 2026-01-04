import Foundation
import SwiftData

// MARK: - Account Manager

/// Manages email accounts - creation, authentication, switching, deletion
@Observable
final class AccountManager: @unchecked Sendable {

    // MARK: - Properties

    /// SwiftData model context
    private let modelContext: ModelContext

    /// Keychain manager
    private let keychainManager = KeychainManager.shared

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
                sortBy: [SortDescriptor<Account>(\.emailAddress)]
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
            throw AccountError.invalidEmailAddress
        }

        // Check if account already exists
        if accounts.contains(where: { $0.emailAddress == email }) {
            throw AccountError.accountAlreadyExists
        }

        // Create account model
        let account = Account(
            name: displayName ?? email,
            emailAddress: email,
            type: preset.type,
            imapHost: preset.imapHost,
            imapPort: preset.imapPort,
            imapUseTLS: preset.imapUseTLS,
            smtpHost: preset.smtpHost,
            smtpPort: preset.smtpPort,
            smtpUseTLS: preset.smtpUseTLS
        )

        // Save password to keychain
        try account.savePassword(password)

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

    // MARK: - Sync Folders

    /// Sync IMAP folders for an account
    /// - Parameter account: Account to sync folders for
    @MainActor
    func syncFolders(for account: Account) async throws {
        Logger.info("Syncing folders for \(account.emailAddress)...", category: logCategory)

        // Create IMAP client
        let client: IMAPClient

        if account.authType == .oauth2 {
            // OAuth2 authentication
            var accessToken = try KeychainManager.shared.loadOAuth2AccessToken(for: account.keychainIdentifier)

            // Check if token needs refresh (expired or expiring soon)
            if account.isTokenExpired || account.needsTokenRefresh {
                Logger.info("Access token expired or expiring soon, refreshing...", category: logCategory)

                // Get refresh token
                guard let refreshToken = try? KeychainManager.shared.loadOAuth2RefreshToken(for: account.keychainIdentifier) else {
                    throw AccountError.passwordNotFound(emailAddress: account.emailAddress)
                }

                // Determine OAuth2 provider from account
                let provider: OAuth2Provider
                if account.type == .gmail {
                    provider = .google
                } else if account.type == .outlook {
                    provider = .microsoft
                } else {
                    throw AccountError.invalidAccount
                }

                // Refresh the token
                let oauth2Manager = OAuth2Manager(provider: provider)
                let newTokens = try await oauth2Manager.refreshAccessToken(refreshToken: refreshToken)

                // Save new tokens
                try KeychainManager.shared.saveOAuth2AccessToken(newTokens.accessToken, for: account.keychainIdentifier)
                if let newRefreshToken = newTokens.refreshToken {
                    try KeychainManager.shared.saveOAuth2RefreshToken(newRefreshToken, for: account.keychainIdentifier)
                }

                // Update expiration date
                account.oauthTokenExpiration = newTokens.expirationDate
                try modelContext.save()

                // Use the new token
                accessToken = newTokens.accessToken

                Logger.info("Access token refreshed successfully", category: logCategory)
            }

            // Create client with OAuth2 token
            client = IMAPClient(
                host: account.imapHost,
                port: account.imapPort,
                username: account.emailAddress,
                oauth2Token: accessToken
            )

        } else {
            // Password authentication
            guard let password = try? account.loadPassword() else {
                throw AccountError.passwordNotFound(emailAddress: account.emailAddress)
            }

            // Create client with password
            client = IMAPClient(
                host: account.imapHost,
                port: account.imapPort,
                username: account.emailAddress,
                password: password
            )
        }

        // Connect and authenticate (OAuth2 or password)
        try await client.connect()
        try await client.login()

        // List all folders
        let imapFolders = try await client.list()
        Logger.info("Found \(imapFolders.count) folders on server", category: logCategory)

        // Get existing folders for this account
        let existingFolders = account.folders

        // Track display order
        var displayOrder = 0

        // Process each IMAP folder
        for imapFolder in imapFolders {
            // Skip non-selectable folders
            guard imapFolder.isSelectable else {
                Logger.debug("Skipping non-selectable folder: \(imapFolder.name)", category: logCategory)
                continue
            }

            // Check if folder already exists
            if existingFolders.contains(where: { $0.path == imapFolder.path }) {
                Logger.debug("Folder already exists: \(imapFolder.name)", category: logCategory)
                continue
            }

            // Determine folder type
            let folderType = imapFolder.specialType ?? .custom

            // Create new folder
            let folder = Folder(
                name: imapFolder.name,
                path: imapFolder.path,
                type: folderType,
                displayOrder: displayOrder
            )
            folder.account = account

            // Insert into database
            modelContext.insert(folder)

            Logger.info("Created folder: \(imapFolder.name) (type: \(folderType.rawValue))", category: logCategory)

            displayOrder += 1
        }

        // Save changes
        try modelContext.save()

        // Disconnect
        try await client.disconnect()

        Logger.info("Folder sync completed: \(displayOrder) new folders added", category: logCategory)
    }

    // MARK: - Sync Messages

    /// Sync messages for a folder
    /// - Parameters:
    ///   - folder: Folder to sync messages for
    ///   - limit: Maximum number of messages to fetch (default: 100, most recent)
    @MainActor
    func syncMessages(for folder: Folder, limit: Int = 100, forceResync: Bool = false) async throws {
        guard let account = folder.account else {
            throw AccountError.accountNotFound
        }

        Logger.info("Syncing messages for folder: \(folder.name) (account: \(account.emailAddress))\(forceResync ? " [FORCE RESYNC]" : "")", category: logCategory)

        // If force resync, delete all existing messages first
        if forceResync {
            Logger.warning("🔄 Force resync enabled - deleting \(folder.messages.count) old messages from database...", category: logCategory)
            for message in folder.messages {
                modelContext.delete(message)
            }
            try modelContext.save()
            Logger.info("✅ Old messages deleted, fetching fresh data from server...", category: logCategory)
        }

        // Create IMAP client
        let client: IMAPClient

        if account.authType == .oauth2 {
            // OAuth2 authentication with refresh
            var accessToken = try KeychainManager.shared.loadOAuth2AccessToken(for: account.keychainIdentifier)

            // Check if token needs refresh
            if account.isTokenExpired || account.needsTokenRefresh {
                Logger.info("Access token expired or expiring soon, refreshing...", category: logCategory)

                guard let refreshToken = try? KeychainManager.shared.loadOAuth2RefreshToken(for: account.keychainIdentifier) else {
                    throw AccountError.passwordNotFound(emailAddress: account.emailAddress)
                }

                let provider: OAuth2Provider
                if account.type == .gmail {
                    provider = .google
                } else if account.type == .outlook {
                    provider = .microsoft
                } else {
                    throw AccountError.invalidAccount
                }

                let oauth2Manager = OAuth2Manager(provider: provider)
                let newTokens = try await oauth2Manager.refreshAccessToken(refreshToken: refreshToken)

                try KeychainManager.shared.saveOAuth2AccessToken(newTokens.accessToken, for: account.keychainIdentifier)
                if let newRefreshToken = newTokens.refreshToken {
                    try KeychainManager.shared.saveOAuth2RefreshToken(newRefreshToken, for: account.keychainIdentifier)
                }

                account.oauthTokenExpiration = newTokens.expirationDate
                try modelContext.save()

                accessToken = newTokens.accessToken
                Logger.info("Access token refreshed successfully", category: logCategory)
            }

            // Create client with OAuth2 token
            client = IMAPClient(
                host: account.imapHost,
                port: account.imapPort,
                username: account.emailAddress,
                oauth2Token: accessToken
            )

        } else {
            // Password authentication
            guard let password = try? account.loadPassword() else {
                throw AccountError.passwordNotFound(emailAddress: account.emailAddress)
            }

            // Create client with password
            client = IMAPClient(
                host: account.imapHost,
                port: account.imapPort,
                username: account.emailAddress,
                password: password
            )
        }

        // Connect and authenticate (OAuth2 or password)
        try await client.connect()
        try await client.login()

        // Select the folder
        let folderInfo = try await client.select(folder: folder.path)
        Logger.info("Folder '\(folder.name)' selected: \(folderInfo.exists) messages", category: logCategory)

        // Update folder counts
        folder.totalCount = folderInfo.exists
        folder.unreadCount = folderInfo.unseen ?? 0

        // If folder is empty, we're done
        guard folderInfo.exists > 0 else {
            Logger.info("Folder is empty, nothing to sync", category: logCategory)
            try await client.disconnect()
            return
        }

        // Fetch recent messages using sequence numbers (avoids PayloadTooLargeError)
        // This method directly calculates sequence range from folder.exists without SEARCH ALL
        Logger.info("Fetching last \(limit) messages using sequence numbers (avoids SEARCH ALL)", category: logCategory)

        let messagesData = try await client.fetchLastMessagesUsingSequenceNumbers(limit: limit)
        Logger.info("Fetched \(messagesData.count) message envelopes", category: logCategory)

        // Get existing message UIDs to avoid duplicates
        let existingUIDs = Set(folder.messages.map { $0.uid })

        // Process and save messages
        var newMessagesCount = 0
        for messageData in messagesData {
            // Skip if already exists
            if existingUIDs.contains(messageData.uid) {
                continue
            }

            // Parse envelope
            guard let envelope = messageData.envelope else {
                Logger.warning("Message UID \(messageData.uid) has no envelope, skipping", category: logCategory)
                continue
            }

            // Create Message model
            let message = Message(
                messageID: envelope.messageId ?? "\(messageData.uid)",
                uid: messageData.uid,
                subject: envelope.subject ?? "(No Subject)",
                from: envelope.from.first?.email ?? "unknown@unknown.com",
                fromName: envelope.from.first?.name,
                to: envelope.to.map { $0.email },
                cc: envelope.cc.map { $0.email },
                bcc: envelope.bcc.map { $0.email },
                date: envelope.date ?? messageData.internalDate ?? Date(),
                preview: envelope.subject ?? "",
                isRead: messageData.flags.contains("\\Seen"),
                isStarred: messageData.flags.contains("\\Flagged"),
                isFlagged: messageData.flags.contains("\\Flagged"),
                isDraft: messageData.flags.contains("\\Draft"),
                hasAttachments: false, // TODO: parse body structure
                size: messageData.size ?? 0,
                isPEC: false // TODO: detect PEC
            )

            message.folder = folder
            modelContext.insert(message)
            newMessagesCount += 1
        }

        // Save changes
        try modelContext.save()

        // Disconnect
        try await client.disconnect()

        Logger.info("Message sync completed: \(newMessagesCount) new messages added to '\(folder.name)'", category: logCategory)
    }

    // MARK: - Fetch Message Body

    /// Fetch full body for a specific message
    /// - Parameter message: Message to fetch body for
    @MainActor
    func fetchMessageBody(for message: Message) async throws {
        guard let folder = message.folder,
              let account = folder.account else {
            throw AccountError.accountNotFound
        }

        Logger.info("Fetching body for message UID \(message.uid) in folder '\(folder.name)'", category: logCategory)

        // Create IMAP client
        let client: IMAPClient

        if account.authType == .oauth2 {
            var accessToken = try KeychainManager.shared.loadOAuth2AccessToken(for: account.keychainIdentifier)

            if account.isTokenExpired || account.needsTokenRefresh {
                Logger.info("Access token expired, refreshing...", category: logCategory)

                guard let refreshToken = try? KeychainManager.shared.loadOAuth2RefreshToken(for: account.keychainIdentifier) else {
                    throw AccountError.passwordNotFound(emailAddress: account.emailAddress)
                }

                let provider: OAuth2Provider = account.type == .gmail ? .google : .microsoft
                let oauth2Manager = OAuth2Manager(provider: provider)
                let newTokens = try await oauth2Manager.refreshAccessToken(refreshToken: refreshToken)

                try KeychainManager.shared.saveOAuth2AccessToken(newTokens.accessToken, for: account.keychainIdentifier)
                if let newRefreshToken = newTokens.refreshToken {
                    try KeychainManager.shared.saveOAuth2RefreshToken(newRefreshToken, for: account.keychainIdentifier)
                }

                account.oauthTokenExpiration = newTokens.expirationDate
                try modelContext.save()

                accessToken = newTokens.accessToken
            }

            // Create client with OAuth2 token
            client = IMAPClient(
                host: account.imapHost,
                port: account.imapPort,
                username: account.emailAddress,
                oauth2Token: accessToken
            )

        } else {
            guard let password = try? account.loadPassword() else {
                throw AccountError.passwordNotFound(emailAddress: account.emailAddress)
            }

            // Create client with password
            client = IMAPClient(
                host: account.imapHost,
                port: account.imapPort,
                username: account.emailAddress,
                password: password
            )
        }

        // Connect and authenticate (OAuth2 or password)
        try await client.connect()
        try await client.login()

        // Select the folder
        _ = try await client.select(folder: folder.path)

        // Fetch entire body (marks as read, but acceptable when user opens email)
        Logger.info("Fetching body for message UID \(message.uid)", category: logCategory)

        let bodyData = try await client.fetchBody(uid: message.uid)

        // Convert to string
        let bodyString = String(data: bodyData, encoding: .utf8) ??
                        String(data: bodyData, encoding: .isoLatin1) ??
                        String(data: bodyData, encoding: .ascii) ?? ""

        Logger.debug("Fetched body: \(bodyString.prefix(200))...", category: logCategory)

        // Parse the RFC822 message to extract HTML and text parts
        let (htmlPart, textPart) = parseEmailBody(bodyString)

        // Save the extracted content
        message.bodyHTML = htmlPart
        message.bodyText = textPart

        Logger.info("💾 Saved to message: bodyHTML=\(htmlPart != nil ? "\(htmlPart!.count) chars" : "nil"), bodyText=\(textPart != nil ? "\(textPart!.count) chars" : "nil")", category: logCategory)

        // If we got nothing, use the raw body as text fallback
        if (htmlPart == nil || htmlPart!.isEmpty) && (textPart == nil || textPart!.isEmpty) {
            Logger.warning("No HTML or text extracted, using raw body as text", category: logCategory)
            message.bodyText = bodyString
        }

        // Mark as read since we fetched the body
        if !message.isRead {
            message.isRead = true
        }

        // Save changes
        try modelContext.save()

        // Disconnect
        try await client.disconnect()

        Logger.info("Message body fetched successfully", category: logCategory)
    }

    // MARK: - Test Connection

    /// Test IMAP connection
    /// - Parameter account: Account to test
    /// - Returns: True if connection successful
    func testIMAPConnection(for account: Account) async throws -> Bool {
        Logger.info("Testing IMAP connection for \(account.emailAddress)...", category: logCategory)

        guard let password = try? account.loadPassword() else {
            throw AccountError.passwordNotFound(emailAddress: account.emailAddress)
        }

        let client = IMAPClient(
            host: account.imapHost,
            port: account.imapPort,
            username: account.emailAddress,
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
        Logger.info("Testing SMTP connection for \(account.emailAddress)...", category: logCategory)

        guard let password = try? account.loadPassword() else {
            throw AccountError.passwordNotFound(emailAddress: account.emailAddress)
        }

        let client = SMTPClient(
            host: account.smtpHost,
            port: account.smtpPort,
            useTLS: account.smtpUseTLS,
            username: account.emailAddress,
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
        Logger.info("Switching to account: \(account.emailAddress)", category: logCategory)

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
        Logger.info("Updating account: \(account.emailAddress)", category: logCategory)

        // Update display name
        if let displayName = displayName {
            account.name = displayName
        }

        // Update password
        if let password = password {
            try account.savePassword(password)
        }

        // Save changes
        try modelContext.save()

        Logger.info("Account updated successfully", category: logCategory)
    }

    // MARK: - Delete Account

    /// Delete account
    /// - Parameter account: Account to delete
    func deleteAccount(_ account: Account) throws {
        Logger.info("Deleting account: \(account.emailAddress)", category: logCategory)

        // Delete password from keychain
        try? account.deletePassword()

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
                // Fetch all messages for this folder manually
                let allFolderMessages = try modelContext.fetch(FetchDescriptor<Message>())
                let unreadMessages = allFolderMessages.filter { message in
                    message.folder == folder && !message.isRead
                }
                allMessages.append(contentsOf: unreadMessages)
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
                // Fetch all messages and filter manually
                let allMessages = try modelContext.fetch(FetchDescriptor<Message>())
                let unreadCount = allMessages.filter { message in
                    message.folder == folder && !message.isRead
                }.count
                totalCount += unreadCount
            }
        }

        return totalCount
    }

    // MARK: - Email Body Parsing

    /// Parse email body to extract HTML and text parts
    /// - Parameter bodyString: Raw RFC822 message body
    /// - Returns: Tuple of (HTML, Text) parts
    private func parseEmailBody(_ bodyString: String) -> (html: String?, text: String?) {
        Logger.debug("📧 Parsing email body (\(bodyString.count) chars)", category: logCategory)

        var htmlPart: String?
        var textPart: String?

        // Split by boundary to find multipart sections
        let lines = bodyString.components(separatedBy: .newlines)

        // Find Content-Type boundary
        var boundary: String?
        for line in lines {
            if line.lowercased().contains("boundary=") {
                let parts = line.components(separatedBy: "boundary=")
                if parts.count > 1 {
                    // Remove quotes and whitespace
                    var boundaryValue = parts[1].trimmingCharacters(in: .whitespaces)
                    
                    // Handle quoted boundaries: boundary="something" or boundary='something'
                    if boundaryValue.hasPrefix("\"") && boundaryValue.contains("\"", range: 1) {
                        // Extract until closing quote
                        let endQuoteIndex = boundaryValue.firstIndex(of: "\"", startingFrom: 1) ?? boundaryValue.endIndex
                        boundaryValue = String(boundaryValue[boundaryValue.index(after: boundaryValue.startIndex)..<endQuoteIndex])
                    } else if boundaryValue.hasPrefix("'") && boundaryValue.contains("'", range: 1) {
                        let endQuoteIndex = boundaryValue.firstIndex(of: "'", startingFrom: 1) ?? boundaryValue.endIndex
                        boundaryValue = String(boundaryValue[boundaryValue.index(after: boundaryValue.startIndex)..<endQuoteIndex])
                    } else {
                        // No quotes, take until semicolon or end of line
                        if let semicolonIndex = boundaryValue.firstIndex(of: ";") {
                            boundaryValue = String(boundaryValue[..<semicolonIndex])
                        }
                    }
                    
                    boundary = boundaryValue.trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
                    Logger.debug("Found boundary: '\(boundary ?? "")'", category: logCategory)
                    break
                }
            }
        }

        if let boundary = boundary {
            // Split by boundary
            let parts = bodyString.components(separatedBy: "--\(boundary)")

            for part in parts {
                let trimmedPart = part.trimmingCharacters(in: .whitespacesAndNewlines)

                // Extract Content-Transfer-Encoding if present
                var transferEncoding: String?
                let partLines = trimmedPart.components(separatedBy: .newlines)
                for line in partLines {
                    if line.lowercased().hasPrefix("content-transfer-encoding:") {
                        transferEncoding = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                        break
                    }
                }

                // Check if this part is HTML
                if trimmedPart.lowercased().contains("content-type: text/html") {
                    // Extract HTML content after headers
                    if let bodyStart = trimmedPart.range(of: "\n\n") ?? trimmedPart.range(of: "\r\n\r\n") {
                        let rawContent = String(trimmedPart[bodyStart.upperBound...])
                        let decodedHTML = decodeEmailContent(rawContent, encoding: transferEncoding)
                        
                        // Clean up any remaining MIME artifacts
                        htmlPart = cleanHTMLContent(decodedHTML)
                        
                        Logger.debug("   Extracted HTML part: \(htmlPart?.count ?? 0) chars", category: logCategory)
                    }
                }
                // Check if this part is plain text
                else if trimmedPart.lowercased().contains("content-type: text/plain") {
                    // Extract text content after headers
                    if let bodyStart = trimmedPart.range(of: "\n\n") ?? trimmedPart.range(of: "\r\n\r\n") {
                        let rawContent = String(trimmedPart[bodyStart.upperBound...])
                        textPart = decodeEmailContent(rawContent, encoding: transferEncoding)
                        
                        Logger.debug("   Extracted text part: \(textPart?.count ?? 0) chars", category: logCategory)
                    }
                }
            }
        } else {
            // No multipart, check if entire body is HTML or text
            Logger.debug("📄 Non-multipart email, processing entire body", category: logCategory)

            // Extract transfer encoding from headers (if present)
            var transferEncoding: String?
            let headerLines = bodyString.components(separatedBy: .newlines)
            for line in headerLines {
                if line.lowercased().hasPrefix("content-transfer-encoding:") {
                    transferEncoding = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                    Logger.debug("Found transfer encoding: \(transferEncoding ?? "nil")", category: logCategory)
                    break
                }
            }

            // Check if body starts with HTML (no headers present)
            let startsWithHTML = bodyString.lowercased().hasPrefix("<!doctype") ||
                                bodyString.lowercased().hasPrefix("<html")

            // Extract content after headers (only if headers exist)
            let rawContent: String
            if startsWithHTML {
                // No headers, entire body is content
                Logger.debug("📄 Body starts with HTML, no headers to strip", category: logCategory)
                rawContent = bodyString
            } else if let bodyStart = bodyString.range(of: "\n\n") ?? bodyString.range(of: "\r\n\r\n") {
                // Headers present, extract after double newline
                Logger.debug("📄 Headers found, extracting content after separator", category: logCategory)
                rawContent = String(bodyString[bodyStart.upperBound...])
            } else {
                // No separator found, use entire body
                Logger.debug("📄 No header separator found, using entire body", category: logCategory)
                rawContent = bodyString
            }

            Logger.debug("📄 Raw content length: \(rawContent.count) chars, preview: \(rawContent.prefix(200))...", category: logCategory)

            // Auto-detect quoted-printable if not specified
            if transferEncoding == nil && (rawContent.contains("=3D") || rawContent.contains("=\n") || rawContent.contains("=\r\n")) {
                Logger.debug("📄 Auto-detected quoted-printable encoding", category: logCategory)
                transferEncoding = "quoted-printable"
            }

            // Decode content first (base64, quoted-printable, etc.)
            let decodedContent = decodeEmailContent(rawContent, encoding: transferEncoding)

            Logger.debug("📄 Decoded content length: \(decodedContent.count) chars", category: logCategory)

            // NOW check if decoded content is HTML or text
            if decodedContent.lowercased().contains("<html") || decodedContent.lowercased().contains("<!doctype") {
                htmlPart = cleanHTMLContent(decodedContent)
                Logger.debug("📄 Content classified as HTML (\(htmlPart?.count ?? 0) chars after cleanup)", category: logCategory)
            } else {
                textPart = decodedContent
                Logger.debug("📄 Content classified as text", category: logCategory)
            }
        }

        Logger.debug("📧 Parsing result: HTML=\(htmlPart != nil ? "\(htmlPart!.count) chars" : "nil"), Text=\(textPart != nil ? "\(textPart!.count) chars" : "nil")", category: logCategory)

        return (htmlPart, textPart)
    }

    /// Decode email content (quoted-printable, base64, etc.)
    /// - Parameters:
    ///   - content: Encoded content
    ///   - encoding: Transfer encoding type
    /// - Returns: Decoded content
    private func decodeEmailContent(_ content: String, encoding: String? = nil) -> String {
        Logger.debug("🔄 decodeEmailContent called: encoding=\(encoding ?? "nil"), content preview: \(content.prefix(100))...", category: logCategory)

        var decoded = content

        // Check if content has base64 encoding
        let explicitBase64 = encoding?.lowercased().contains("base64") ?? false
        
        // Smart base64 detection: only if NO HTML tags present and looks like base64
        let looksLikeBase64 = !content.contains("<") && 
                             !content.contains(">") &&
                             content.count > 100 &&
                             content.range(of: "^[A-Za-z0-9+/=\\r\\n\\s]{100,}$", options: .regularExpression) != nil
        
        let isBase64 = explicitBase64 || looksLikeBase64
        
        if looksLikeBase64 {
            Logger.debug("🔍 Auto-detected base64 (no HTML tags, matches base64 pattern)", category: logCategory)
        }

        if isBase64 {
            Logger.debug("Decoding base64 content (\(content.count) chars)", category: logCategory)

            // Remove whitespace and newlines from base64 string
            let cleanedBase64 = content.replacingOccurrences(of: "\\s", with: "", options: .regularExpression)

            // Decode base64
            if let data = Data(base64Encoded: cleanedBase64),
               let decodedString = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) {
                Logger.info("✅ Base64 decoded successfully: \(decodedString.count) chars", category: logCategory)
                return decodedString
            } else {
                Logger.warning("⚠️ Base64 decoding failed, returning original", category: logCategory)
                return content
            }
        }

        // Decode quoted-printable encoding (or return as-is if not needed)
        
        // Check if content needs quoted-printable decoding
        let needsQuotedPrintableDecode = encoding?.lowercased().contains("quoted-printable") ?? false ||
                                         decoded.contains("=3D") ||
                                         decoded.contains("=20") ||
                                         decoded.range(of: "=[0-9A-Fa-f]{2}", options: .regularExpression) != nil

        if !needsQuotedPrintableDecode {
            Logger.debug("ℹ️ Content doesn't need quoted-printable decoding, returning as-is", category: logCategory)
            return decoded
        }
        
        Logger.debug("🔤 Decoding quoted-printable...", category: logCategory)

        // Remove soft line breaks (= at end of line)
        decoded = decoded.replacingOccurrences(of: "=\r\n", with: "")
        decoded = decoded.replacingOccurrences(of: "=\n", with: "")

        Logger.debug("🔤 After removing soft line breaks: \(decoded.count) chars, preview: \(decoded.prefix(200))...", category: logCategory)

        // Decode =XX sequences (improved for multi-byte UTF-8)
        let pattern = "=([0-9A-Fa-f]{2})"  // Match =XX where XX is hex (more specific than \\w)
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsString = decoded as NSString
            let matches = regex.matches(in: decoded, range: NSRange(location: 0, length: nsString.length))

            Logger.debug("✅ Quoted-printable regex created, found \(matches.count) sequences to decode", category: logCategory)

            if matches.count > 0 {
                // Collect all hex bytes first
                var bytes: [UInt8] = []
                var lastEnd = 0

                for match in matches {
                    // Add characters before this match
                    if match.range.location > lastEnd {
                        let beforeRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
                        let beforeText = nsString.substring(with: beforeRange)
                        if let data = beforeText.data(using: .utf8) {
                            bytes.append(contentsOf: data)
                        }
                    }

                    // Decode hex byte
                    let hexRange = match.range(at: 1)
                    let hexString = nsString.substring(with: hexRange)
                    if let byte = UInt8(hexString, radix: 16) {
                        bytes.append(byte)
                    } else {
                        Logger.warning("⚠️ Failed to decode hex: \(hexString)", category: logCategory)
                    }

                    lastEnd = match.range.location + match.range.length
                }

                // Add remaining text
                if lastEnd < nsString.length {
                    let remainingRange = NSRange(location: lastEnd, length: nsString.length - lastEnd)
                    let remainingText = nsString.substring(with: remainingRange)
                    if let data = remainingText.data(using: .utf8) {
                        bytes.append(contentsOf: data)
                    }
                }

                // Convert bytes to string
                if let decodedString = String(bytes: bytes, encoding: .utf8) ?? String(bytes: bytes, encoding: .isoLatin1) {
                    Logger.info("✅ Quoted-printable decoded successfully: \(matches.count) sequences → \(decodedString.count) chars", category: logCategory)
                    return decodedString
                } else {
                    Logger.warning("⚠️ Failed to convert decoded bytes to string", category: logCategory)
                }
            } else {
                // No sequences found, but soft line breaks were removed - return that
                Logger.debug("ℹ️ No quoted-printable sequences found, returning content with soft line breaks removed", category: logCategory)
                return decoded
            }
        }

        Logger.debug("🔄 Returning decoded content: \(decoded.count) chars", category: logCategory)
        return decoded
    }
    
    /// Clean HTML content by removing MIME artifacts and whitespace
    /// - Parameter html: Raw HTML content
    /// - Returns: Cleaned HTML
    private func cleanHTMLContent(_ html: String) -> String {
        var cleaned = html
        
        // Remove common MIME boundary artifacts that might remain
        if let boundaryPattern = try? NSRegularExpression(pattern: "^--.*?$", options: [.anchorsMatchLines]) {
            let nsString = cleaned as NSString
            let matches = boundaryPattern.matches(in: cleaned, range: NSRange(location: 0, length: nsString.length))
            
            // Remove from end to start to preserve ranges
            for match in matches.reversed() {
                let range = match.range
                if let swiftRange = Range(range, in: cleaned) {
                    cleaned.removeSubrange(swiftRange)
                }
            }
        }
        
        // Trim whitespace and newlines from start and end
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If HTML doesn't start with < but contains HTML, find where it starts
        if !cleaned.hasPrefix("<") {
            if let htmlStart = cleaned.range(of: "<", options: .literal) {
                cleaned = String(cleaned[htmlStart.lowerBound...])
            }
        }
        
        Logger.debug("🧹 HTML cleaned: \(html.count) → \(cleaned.count) chars", category: logCategory)
        
        return cleaned
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

// MARK: - String Extensions

extension String {
    /// Find first index of character starting from a given position
    func firstIndex(of character: Character, startingFrom index: Int) -> String.Index? {
        let startIndex = self.index(self.startIndex, offsetBy: index)
        return self[startIndex...].firstIndex(of: character)
    }
    
    /// Check if string contains a substring with optional range
    func contains(_ substring: String, range: Int) -> Bool {
        guard range < self.count else { return false }
        let startIndex = self.index(self.startIndex, offsetBy: range)
        return self[startIndex...].contains(substring)
    }
}

