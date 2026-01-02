import Foundation
import SwiftMail

/// IMAP client wrapper around SwiftMail for email operations
/// This actor provides a clean interface to SwiftMail's IMAPServer
actor IMAPClient {

    // MARK: - Properties

    /// SwiftMail IMAP server instance
    private let server: IMAPServer

    /// Server configuration
    private let host: String
    private let port: Int

    /// Authentication credentials
    private let username: String
    private let password: String?
    private let oauth2Token: String?

    /// Currently selected folder
    private var selectedFolder: String?

    /// Last folder info from SELECT/EXAMINE
    private var lastFolderInfo: IMAPFolderInfo?

    /// Logger category
    private let logCategory: Logger.Category = .imap

    // MARK: - Initialization

    /// Initialize IMAP client with password authentication
    /// - Parameters:
    ///   - host: IMAP server host
    ///   - port: IMAP server port (default: 993 for TLS)
    ///   - username: Email username
    ///   - password: Email password
    init(
        host: String,
        port: Int,
        username: String,
        password: String
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.oauth2Token = nil
        self.server = IMAPServer(host: host, port: port)

        Logger.debug("IMAP client initialized for \(host):\(port)", category: logCategory)
    }

    /// Initialize IMAP client with OAuth2 authentication
    /// - Parameters:
    ///   - host: IMAP server host
    ///   - port: IMAP server port
    ///   - username: Email address
    ///   - oauth2Token: OAuth2 access token
    init(
        host: String,
        port: Int,
        username: String,
        oauth2Token: String
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.password = nil
        self.oauth2Token = oauth2Token
        self.server = IMAPServer(host: host, port: port)

        Logger.debug("IMAP client initialized with OAuth2 for \(host):\(port)", category: logCategory)
    }

    // MARK: - Connection Management

    /// Connect to IMAP server
    /// - Throws: IMAPError if connection fails
    func connect() async throws {
        Logger.info("Connecting to IMAP server \(host):\(port)...", category: logCategory)

        do {
            try await server.connect()
            Logger.info("Successfully connected to IMAP server", category: logCategory)
        } catch {
            Logger.error("Failed to connect to IMAP server", error: error, category: logCategory)
            throw IMAPError.connectionFailed(host: host, port: port)
        }
    }

    /// Login to IMAP server
    /// - Throws: IMAPError if authentication fails
    func login() async throws {
        Logger.info("Authenticating with IMAP server...", category: logCategory)

        do {
            if let oauth2Token = oauth2Token {
                // OAuth2 authentication
                try await server.authenticateXOAUTH2(email: username, accessToken: oauth2Token)
                Logger.info("Successfully authenticated with OAuth2", category: logCategory)
            } else if let password = password {
                // Password authentication
                try await server.login(username: username, password: password)
                Logger.info("Successfully authenticated with password", category: logCategory)
            } else {
                throw IMAPError.authenticationFailed
            }
        } catch {
            Logger.error("Authentication failed", error: error, category: logCategory)
            throw IMAPError.authenticationFailed
        }
    }

    /// Disconnect from server
    func disconnect() async throws {
        Logger.info("Disconnecting from IMAP server...", category: logCategory)

        do {
            try await server.logout()
            Logger.info("Disconnected from IMAP server", category: logCategory)
        } catch {
            // Ignore logout errors, connection will be closed anyway
            Logger.debug("Logout error (ignored): \(error)", category: logCategory)
        }
    }

    // MARK: - Folder Operations

    /// List available folders on server
    /// - Returns: Array of folder information
    func list(reference: String = "", pattern: String = "*") async throws -> [IMAPFolder] {
        Logger.debug("Listing folders with pattern: \(pattern)", category: logCategory)

        do {
            // SwiftMail uses listMailboxes(wildcard:) method
            let mailboxes = try await server.listMailboxes(wildcard: pattern)

            // Convert SwiftMail Mailbox.Info to our IMAPFolder
            let folders = mailboxes.map { mailbox in
                let attributeStrings: [String]
                if mailbox.attributes.contains(.noSelect) {
                    attributeStrings = ["\\Noselect"]
                } else {
                    attributeStrings = []
                }
                
                return IMAPFolder(
                    name: mailbox.name,
                    path: mailbox.name,
                    delimiter: mailbox.hierarchyDelimiter?.description,
                    attributes: attributeStrings
                )
            }

            Logger.info("LIST command successful: found \(folders.count) folders", category: logCategory)
            return folders
        } catch {
            Logger.error("LIST command failed", error: error, category: logCategory)
            throw IMAPError.serverError(message: "LIST failed: \(error.localizedDescription)")
        }
    }

    /// Select a folder for reading and writing
    /// - Parameter folder: Folder path (e.g., "INBOX")
    /// - Returns: Folder information
    func select(folder: String) async throws -> IMAPFolderInfo {
        Logger.info("Selecting folder: \(folder)", category: logCategory)

        do {
            let status = try await server.selectMailbox(folder)
            selectedFolder = folder

            Logger.info("Folder '\(folder)' selected successfully", category: logCategory)

            // Convert SwiftMail Mailbox.Status to our IMAPFolderInfo
            let flagStrings = status.availableFlags.map { flag -> String in
                switch flag {
                case .answered: return "\\Answered"
                case .flagged: return "\\Flagged"
                case .deleted: return "\\Deleted"
                case .seen: return "\\Seen"
                case .draft: return "\\Draft"
                default: return ""
                }
            }.filter { !$0.isEmpty }

            let permFlagStrings = status.permanentFlags.map { flag -> String in
                switch flag {
                case .answered: return "\\Answered"
                case .flagged: return "\\Flagged"
                case .deleted: return "\\Deleted"
                case .seen: return "\\Seen"
                case .draft: return "\\Draft"
                default: return ""
                }
            }.filter { !$0.isEmpty }

            let folderInfo = IMAPFolderInfo(
                name: folder,
                exists: status.messageCount,
                recent: 0, // SwiftMail doesn't expose recent count directly
                unseen: nil, // SwiftMail doesn't expose unseen directly
                flags: flagStrings,
                permanentFlags: permFlagStrings
            )

            // Store folder info for later use (e.g., sequence number fetching)
            lastFolderInfo = folderInfo

            return folderInfo
        } catch {
            Logger.error("SELECT failed", error: error, category: logCategory)
            throw IMAPError.folderNotFound(name: folder)
        }
    }

    /// Examine a folder in read-only mode
    /// - Parameter folder: Folder path
    /// - Returns: Folder information
    func examine(folder: String) async throws -> IMAPFolderInfo {
        Logger.info("Examining folder (read-only): \(folder)", category: logCategory)

        do {
            // For now, use select - SwiftMail might have examine method
            let status = try await server.selectMailbox(folder)
            selectedFolder = folder

            Logger.info("Folder '\(folder)' examined successfully (read-only)", category: logCategory)

            let flagStrings = status.availableFlags.map { flag -> String in
                switch flag {
                case .answered: return "\\Answered"
                case .flagged: return "\\Flagged"
                case .deleted: return "\\Deleted"
                case .seen: return "\\Seen"
                case .draft: return "\\Draft"
                default: return ""
                }
            }.filter { !$0.isEmpty }
            
            let permFlagStrings = status.permanentFlags.map { flag -> String in
                switch flag {
                case .answered: return "\\Answered"
                case .flagged: return "\\Flagged"
                case .deleted: return "\\Deleted"
                case .seen: return "\\Seen"
                case .draft: return "\\Draft"
                default: return ""
                }
            }.filter { !$0.isEmpty }

            var info = IMAPFolderInfo(
                name: folder,
                exists: status.messageCount,
                recent: 0,
                unseen: nil,
                flags: flagStrings,
                permanentFlags: permFlagStrings
            )
            info.isReadOnly = true

            // Store folder info for later use
            lastFolderInfo = info

            return info
        } catch {
            Logger.error("EXAMINE failed", error: error, category: logCategory)
            throw IMAPError.folderNotFound(name: folder)
        }
    }

    /// Close currently selected folder
    func close() async throws {
        Logger.debug("Closing selected folder", category: logCategory)

        guard selectedFolder != nil else {
            Logger.warning("No folder currently selected", category: logCategory)
            return
        }

        do {
            try await server.closeMailbox()
            selectedFolder = nil
            Logger.info("Folder closed successfully", category: logCategory)
        } catch {
            Logger.error("CLOSE failed", error: error, category: logCategory)
            throw IMAPError.serverError(message: "CLOSE failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Message Fetching

    /// Fetch messages by UID
    /// - Parameters:
    ///   - uidSet: UID set (e.g., "1:100")
    ///   - items: Items to fetch (ignored, SwiftMail fetches all needed)
    /// - Returns: Array of fetched message data
    func uidFetch(uidSet: String, items: [String]) async throws -> [IMAPMessageData] {
        Logger.debug("UID Fetching messages: \(uidSet) (from database)", category: logCategory)

        guard selectedFolder != nil else {
            throw IMAPError.serverError(message: "No folder selected")
        }

        do {
            // Parse the UID range directly without SEARCH ALL (to avoid PayloadTooLargeError)
            var requestedUIDs: [UInt32]

            // For ranges ending with *, we can't use SEARCH ALL on large mailboxes
            // Instead, we'll estimate the range and try to fetch
            if uidSet.contains("*") {
                Logger.debug("Parsing range with wildcard: \(uidSet)", category: logCategory)
                requestedUIDs = try await parseUIDRangeWithWildcard(uidSet)
            } else {
                // For specific ranges or lists, use SEARCH
                Logger.debug("Searching for messages in range: \(uidSet)", category: logCategory)
                let allResults: MessageIdentifierSet<SwiftMail.UID> = try await server.search(criteria: [.all])
                let allUIDs = allResults.toArray().map { $0.value }.sorted()
                requestedUIDs = filterUIDsByRange(allUIDs: allUIDs, uidSet: uidSet)
            }

            Logger.debug("Will attempt to fetch \(requestedUIDs.count) UIDs", category: logCategory)

            // IMPORTANT: For large ranges, limit to last 200 UIDs to avoid timeout
            // This is a safety measure since we're fetching one at a time
            if requestedUIDs.count > 200 {
                Logger.warning("⚠️ Range has \(requestedUIDs.count) UIDs, limiting to last 200 for performance", category: logCategory)
                requestedUIDs = Array(requestedUIDs.suffix(200))
            }

            var messages: [IMAPMessageData] = []
            var fetchedCount = 0

            // Fetch message info for each UID
            Logger.debug("Fetching message info for \(requestedUIDs.count) UIDs...", category: logCategory)
            for (index, uid) in requestedUIDs.enumerated() {
                if let messageInfo = try await server.fetchMessageInfo(for: SwiftMail.UID(uid)) {
                    let messageData = convertMessageInfoToIMAPData(messageInfo)
                    messages.append(messageData)
                    fetchedCount += 1

                    // Log progress every 10 messages
                    if (index + 1) % 10 == 0 {
                        Logger.debug("Progress: \(index + 1)/\(requestedUIDs.count) messages fetched", category: logCategory)
                    }
                }
            }

            Logger.info("UID FETCH command successful: \(fetchedCount) messages fetched from range \(uidSet)", category: logCategory)
            return messages
        } catch {
            Logger.error("UID FETCH failed", error: error, category: logCategory)
            throw IMAPError.messageFetchFailed
        }
    }

    /// Fetch last N messages using sequence numbers (avoids SEARCH ALL)
    /// - Parameter limit: Maximum number of messages to fetch
    /// - Returns: Array of fetched message data
    func fetchLastMessagesUsingSequenceNumbers(limit: Int) async throws -> [IMAPMessageData] {
        Logger.debug("Fetching last \(limit) messages using sequence numbers", category: logCategory)

        guard let folderInfo = lastFolderInfo else {
            throw IMAPError.serverError(message: "No folder selected or folder info not available")
        }

        let totalMessages = folderInfo.exists
        guard totalMessages > 0 else {
            Logger.info("Folder is empty, no messages to fetch", category: logCategory)
            return []
        }

        // Calculate sequence number range for last N messages
        let startSeq = max(1, totalMessages - limit + 1)
        let endSeq = totalMessages

        Logger.info("Fetching sequence range \(startSeq):\(endSeq) (last \(min(limit, totalMessages)) of \(totalMessages) messages)", category: logCategory)

        var messages: [IMAPMessageData] = []
        var fetchedCount = 0

        // Fetch messages one by one using sequence numbers
        for seqNum in startSeq...endSeq {
            do {
                if let messageInfo = try await server.fetchMessageInfo(for: SequenceNumber(UInt32(seqNum))) {
                    let messageData = convertMessageInfoToIMAPData(messageInfo)
                    messages.append(messageData)
                    fetchedCount += 1

                    // Log progress every 20 messages
                    if fetchedCount % 20 == 0 {
                        Logger.debug("Progress: \(fetchedCount)/\(endSeq - startSeq + 1) messages fetched", category: logCategory)
                    }
                }
            } catch {
                Logger.warning("Failed to fetch message at sequence \(seqNum): \(error)", category: logCategory)
                // Continue with next message instead of failing completely
            }
        }

        Logger.info("Sequence fetch completed: \(fetchedCount) messages fetched", category: logCategory)
        return messages
    }

    /// Parse UID range with wildcard by getting actual UIDs from server
    /// - Parameter uidSet: UID set with wildcard (e.g., "2340:*")
    /// - Returns: Array of UIDs to fetch (last 200 real UIDs)
    private func parseUIDRangeWithWildcard(_ uidSet: String) async throws -> [UInt32] {
        // For "*" ranges, we need to get the LAST N messages
        // Try SEARCH to get all UIDs, with fallback for large mailboxes
        Logger.debug("Getting last 200 UIDs from server...", category: logCategory)

        do {
            let allResults: MessageIdentifierSet<SwiftMail.UID> = try await server.search(criteria: [.all])
            let allUIDs = allResults.toArray().map { $0.value }.sorted()

            // Take last 200 UIDs (most recent messages)
            let lastUIDs = Array(allUIDs.suffix(200))
            Logger.debug("Got \(lastUIDs.count) most recent UIDs (out of \(allUIDs.count) total)", category: logCategory)

            return lastUIDs
        } catch {
            // If SEARCH ALL fails (PayloadTooLarge), estimate based on highest UIDs
            Logger.warning("SEARCH ALL failed, will try fetching estimated range: \(error)", category: logCategory)

            // Parse start UID and try a conservative range
            if let colonIndex = uidSet.firstIndex(of: ":") {
                let startStr = String(uidSet[..<colonIndex])
                if let start = UInt32(startStr) {
                    // Try a range that's likely to contain recent messages
                    let estimatedUIDs = Array(start...(start + 300)).suffix(200)
                    return Array(estimatedUIDs)
                }
            }

            throw error
        }
    }

    /// Filter UIDs by range specification
    /// - Parameters:
    ///   - allUIDs: All UIDs available
    ///   - uidSet: UID set specification (e.g., "1:10", "100:*", "1,3,5")
    /// - Returns: Filtered array of UIDs
    private func filterUIDsByRange(allUIDs: [UInt32], uidSet: String) -> [UInt32] {
        // Handle single UID
        if let singleUID = UInt32(uidSet) {
            return allUIDs.contains(singleUID) ? [singleUID] : []
        }

        // Handle range (e.g., "1:10" or "100:*")
        if let colonIndex = uidSet.firstIndex(of: ":") {
            let startStr = String(uidSet[..<colonIndex])
            let endStr = String(uidSet[uidSet.index(after: colonIndex)...])

            guard let start = UInt32(startStr) else {
                return []
            }

            // Handle "*" as end (means highest UID)
            if endStr == "*" {
                return allUIDs.filter { $0 >= start }
            }

            // Handle numeric end
            if let end = UInt32(endStr) {
                return allUIDs.filter { $0 >= start && $0 <= end }
            }
        }

        // Handle comma-separated list (e.g., "1,3,5")
        if uidSet.contains(",") {
            let requestedUIDs = Set(uidSet.split(separator: ",").compactMap { UInt32($0) })
            return allUIDs.filter { requestedUIDs.contains($0) }
        }

        return []
    }

    /// Fetch message body (marks as read)
    /// - Parameter uid: Message UID
    /// - Returns: Message body data
    func fetchBody(uid: Int64) async throws -> Data {
        Logger.debug("Fetching body for UID: \(uid) (from database)", category: logCategory)

        do {
            // First get the message info
            Logger.debug("Step 1: Fetching message info for UID \(uid)", category: logCategory)
            guard let messageInfo = try await server.fetchMessageInfo(for: SwiftMail.UID(UInt32(uid))) else {
                Logger.error("❌ fetchMessageInfo returned nil for UID \(uid)", category: logCategory)

                // Diagnostic: Check if UID exists and get UID range info
                Logger.warning("🔍 DIAGNOSTIC: Checking UID validity on server...", category: logCategory)
                do {
                    // First, check if this specific UID exists
                    let exists = try await uidExistsOnServer(UInt32(uid))
                    Logger.warning("   UID \(uid) exists on server: \(exists ? "YES ✅" : "NO ❌")", category: logCategory)

                    // Get UID range info
                    let range = try await getServerUIDRange()
                    Logger.warning("   Server UID range: \(range.min) to \(range.max) (total: \(range.count) messages)", category: logCategory)

                    if !exists {
                        if UInt32(uid) < range.min {
                            Logger.warning("   ⚠️ UID \(uid) is BELOW server range - message was likely deleted", category: logCategory)
                        } else if UInt32(uid) > range.max {
                            Logger.warning("   ⚠️ UID \(uid) is ABOVE server range - database has invalid UID", category: logCategory)
                        } else {
                            Logger.warning("   ⚠️ UID \(uid) is within range but missing - message was deleted", category: logCategory)
                        }
                        Logger.warning("   💡 SOLUTION: Re-sync this folder to update UIDs in database", category: logCategory)
                    }
                } catch {
                    Logger.error("   Diagnostic failed: \(error)", category: logCategory)
                }

                throw IMAPError.messageFetchFailed
            }
            Logger.debug("Step 1 OK: Got message info for UID \(uid)", category: logCategory)

            // Fetch complete message with all parts
            Logger.debug("Step 2: Fetching complete message with all parts", category: logCategory)
            let message = try await server.fetchMessage(from: messageInfo)
            Logger.debug("Step 2 OK: Got message with \(message.parts.count) parts", category: logCategory)

            // Convert message parts to RFC822 format
            Logger.debug("Step 3: Converting message to RFC822 format", category: logCategory)
            let rfc822Data = try convertMessageToRFC822(message)
            Logger.debug("Step 3 OK: Converted to \(rfc822Data.count) bytes", category: logCategory)

            Logger.info("Body fetched successfully (marked as read)", category: logCategory)
            return rfc822Data
        } catch {
            Logger.error("Failed to fetch body - Detailed error: \(error.localizedDescription)", error: error, category: logCategory)
            throw IMAPError.messageFetchFailed
        }
    }

    /// Fetch message body without marking as read
    /// - Parameter uid: Message UID
    /// - Returns: Message body data
    func fetchBodyPeek(uid: Int64) async throws -> Data {
        // Note: SwiftMail automatically uses BODY.PEEK internally
        // So this is the same as fetchBody but doesn't mark as read
        return try await fetchBody(uid: uid)
    }

    /// Fetch message headers (envelope)
    /// - Parameter uid: Message UID
    /// - Returns: Message data with envelope
    func fetchEnvelope(uid: Int64) async throws -> IMAPMessageData {
        Logger.debug("Fetching envelope for UID: \(uid)", category: logCategory)

        guard let messageInfo = try await server.fetchMessageInfo(for: SwiftMail.UID(UInt32(uid))) else {
            throw IMAPError.messageFetchFailed
        }

        return convertMessageInfoToIMAPData(messageInfo)
    }

    // MARK: - Search

    /// Search messages by UID
    /// - Parameter criteria: Search criteria
    /// - Returns: Array of message UIDs
    func uidSearch(criteria: IMAPSearchCriteria) async throws -> [Int64] {
        Logger.debug("UID Searching with criteria: \(criteria.toIMAPString())", category: logCategory)

        guard selectedFolder != nil else {
            throw IMAPError.serverError(message: "No folder selected")
        }

        do {
            // Convert our search criteria to SwiftMail search
            let searchCriteria = try convertSearchCriteria(criteria)
            let results: MessageIdentifierSet<SwiftMail.UID> = try await server.search(criteria: searchCriteria)

            // Extract UIDs from results
            // UID values can be converted directly to Int64
            let uids = results.toArray().map { uid in Int64(uid.value) }

            Logger.info("UID SEARCH successful: \(uids.count) UIDs", category: logCategory)
            return uids
        } catch {
            Logger.error("UID SEARCH failed", error: error, category: logCategory)
            throw IMAPError.serverError(message: "UID SEARCH failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Flags Management

    /// Mark message as read
    /// - Parameter uid: Message UID
    func markAsRead(uid: Int64) async throws {
        Logger.debug("Marking UID \(uid) as read", category: logCategory)

        do {
            // TODO: Implement with proper SwiftMail API
            // For now, just log
            Logger.warning("markAsRead not implemented yet", category: logCategory)
        } catch {
            Logger.error("Failed to mark as read", error: error, category: logCategory)
            throw IMAPError.serverError(message: "STORE failed: \(error.localizedDescription)")
        }
    }

    /// Mark message as unread
    /// - Parameter uid: Message UID
    func markAsUnread(uid: Int64) async throws {
        Logger.debug("Marking UID \(uid) as unread", category: logCategory)

        do {
            // TODO: Implement with proper SwiftMail API
            // For now, just log
            Logger.warning("markAsUnread not implemented yet", category: logCategory)
        } catch {
            Logger.error("Failed to mark as unread", error: error, category: logCategory)
            throw IMAPError.serverError(message: "STORE failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Helper Methods

    /// Get UID range information from the server
    /// - Returns: Tuple with (min UID, max UID, count)
    private func getServerUIDRange() async throws -> (min: UInt32, max: UInt32, count: Int) {
        // Search for all messages to get UID range
        let results: MessageIdentifierSet<SwiftMail.UID> = try await server.search(criteria: [.all])
        let uids = results.toArray().map { $0.value }

        guard !uids.isEmpty else {
            throw IMAPError.serverError(message: "No messages on server")
        }

        return (min: uids.min()!, max: uids.max()!, count: uids.count)
    }

    /// Check if a specific UID exists on the server by searching for it
    /// - Parameter uid: UID to check
    /// - Returns: True if UID exists
    private func uidExistsOnServer(_ uid: UInt32) async throws -> Bool {
        // Search for specific UID
        let results: MessageIdentifierSet<SwiftMail.UID> = try await server.search(criteria: [.uid(Int(uid))])
        return !results.toArray().isEmpty
    }

    /// Parse UID set string into array of UIDs
    /// - Parameter uidSet: UID set string (e.g., "1:10", "1,3,5", "1:*")
    /// - Returns: Array of UIDs
    private func parseUIDSet(_ uidSet: String) -> [UInt32] {
        var uids: [UInt32] = []

        // Handle single UID
        if let uid = UInt32(uidSet) {
            return [uid]
        }

        // Handle range (e.g., "1:10")
        if let colonIndex = uidSet.firstIndex(of: ":") {
            let startStr = String(uidSet[..<colonIndex])
            let endStr = String(uidSet[uidSet.index(after: colonIndex)...])

            if let start = UInt32(startStr), let end = UInt32(endStr) {
                uids = Array(start...end)
            }
        }
        // Handle comma-separated list (e.g., "1,3,5")
        else if uidSet.contains(",") {
            uids = uidSet.split(separator: ",").compactMap { UInt32($0) }
        }

        return uids
    }

    /// Convert SwiftMail MessageInfo to our IMAPMessageData
    /// - Parameter messageInfo: SwiftMail message info
    /// - Returns: Our IMAPMessageData
    private func convertMessageInfoToIMAPData(_ messageInfo: SwiftMail.MessageInfo) -> IMAPMessageData {
        // Convert flags
        let flagStrings = messageInfo.flags.map { flag -> String in
            switch flag {
            case .answered: return "\\Answered"
            case .flagged: return "\\Flagged"
            case .deleted: return "\\Deleted"
            case .seen: return "\\Seen"
            case .draft: return "\\Draft"
            // .recent doesn't exist in SwiftMail Flag enum
            default: return ""
            }
        }.filter { !$0.isEmpty }

        // Extract UID value
        let uidValue: Int64
        if let uid = messageInfo.uid {
            // UID has a 'value' property of type UInt32
            uidValue = Int64(uid.value)
        } else {
            uidValue = 0
        }

        // Extract sequence number
        // SequenceNumber has a 'value' property of type UInt32
        let seqNum = Int(messageInfo.sequenceNumber.value)

        // Parse from address into IMAPAddress
        let fromAddresses: [IMAPAddress] = if let from = messageInfo.from {
            [parseEmailAddress(from)]
        } else {
            []
        }

        // Parse to addresses
        let toAddresses = messageInfo.to.map { parseEmailAddress($0) }

        // Parse cc addresses
        let ccAddresses = messageInfo.cc.map { parseEmailAddress($0) }

        // Parse bcc addresses
        let bccAddresses = messageInfo.bcc.map { parseEmailAddress($0) }

        // Build envelope with actual data from MessageInfo
        return IMAPMessageData(
            uid: uidValue,
            sequenceNumber: seqNum,
            flags: flagStrings,
            size: nil, // SwiftMail MessageInfo doesn't have size directly
            envelope: IMAPEnvelope(
                date: messageInfo.date,
                subject: messageInfo.subject,
                from: fromAddresses,
                sender: fromAddresses, // Use from as sender if not available
                replyTo: fromAddresses, // Use from as replyTo if not available
                to: toAddresses,
                cc: ccAddresses,
                bcc: bccAddresses,
                inReplyTo: nil,
                messageId: messageInfo.messageId
            ),
            bodyStructure: nil,
            rfc822: nil,
            internalDate: messageInfo.date
        )
    }

    /// Parse email address string into IMAPAddress
    /// - Parameter email: Email string (can be "Name <email@example.com>" or just "email@example.com")
    /// - Returns: IMAPAddress
    private func parseEmailAddress(_ email: String) -> IMAPAddress {
        var name: String?
        var emailAddr: String

        // Handle format: "Name <email@example.com>"
        if let angleStart = email.firstIndex(of: "<"),
           let angleEnd = email.firstIndex(of: ">") {
            let nameStr = String(email[..<angleStart]).trimmingCharacters(in: .whitespaces)
            name = nameStr.isEmpty ? nil : nameStr
            emailAddr = String(email[email.index(after: angleStart)..<angleEnd])
        } else {
            // Plain email address
            emailAddr = email.trimmingCharacters(in: .whitespaces)
        }

        // Split email into mailbox and host
        let parts = emailAddr.split(separator: "@", maxSplits: 1)
        let mailbox = parts.first.map(String.init) ?? emailAddr
        let host = parts.count > 1 ? String(parts[1]) : ""

        return IMAPAddress(name: name, mailbox: mailbox, host: host)
    }

    /// Convert SwiftMail Message to RFC822 format
    /// - Parameter message: SwiftMail message
    /// - Returns: RFC822 data
    private func convertMessageToRFC822(_ message: SwiftMail.Message) throws -> Data {
        // Combine all message parts into RFC822 format
        var rfc822String = ""

        // Add message parts
        for part in message.parts {
            if let data = part.data {
                if let text = String(data: data, encoding: .utf8) {
                    rfc822String += text
                } else {
                    // Binary data, append as-is
                    rfc822String += String(decoding: data, as: UTF8.self)
                }
            }
        }

        return Data(rfc822String.utf8)
    }

    /// Convert our search criteria to SwiftMail SearchCriteria
    /// - Parameter criteria: Our search criteria
    /// - Returns: SwiftMail SearchCriteria array
    private func convertSearchCriteria(_ criteria: IMAPSearchCriteria) throws -> [SwiftMail.SearchCriteria] {
        // For now, support basic ALL search
        // TODO: Implement full criteria conversion
        return [.all]
    }
}
