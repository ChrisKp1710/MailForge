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

            return IMAPFolderInfo(
                name: folder,
                exists: status.messageCount,
                recent: 0, // SwiftMail doesn't expose recent count directly
                unseen: nil, // SwiftMail doesn't expose unseen directly
                flags: flagStrings,
                permanentFlags: permFlagStrings
            )
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
        Logger.debug("UID Fetching messages: \(uidSet)", category: logCategory)

        guard selectedFolder != nil else {
            throw IMAPError.serverError(message: "No folder selected")
        }

        do {
            // Parse UID set into array of UIDs
            let uids = parseUIDSet(uidSet)
            var messages: [IMAPMessageData] = []

            for uid in uids {
                // Fetch message info (headers, flags, etc.)
                if let messageInfo = try await server.fetchMessageInfo(for: SwiftMail.UID(uid)) {

                    // Convert SwiftMail MessageInfo to our IMAPMessageData
                    let messageData = convertMessageInfoToIMAPData(messageInfo)
                    messages.append(messageData)
                }
            }

            Logger.info("UID FETCH command successful: \(messages.count) messages", category: logCategory)
            return messages
        } catch {
            Logger.error("UID FETCH failed", error: error, category: logCategory)
            throw IMAPError.messageFetchFailed
        }
    }

    /// Fetch message body (marks as read)
    /// - Parameter uid: Message UID
    /// - Returns: Message body data
    func fetchBody(uid: Int64) async throws -> Data {
        Logger.debug("Fetching body for UID: \(uid)", category: logCategory)

        do {
            // First get the message info
            Logger.debug("Step 1: Fetching message info for UID \(uid)", category: logCategory)
            guard let messageInfo = try await server.fetchMessageInfo(for: SwiftMail.UID(UInt32(uid))) else {
                Logger.error("fetchMessageInfo returned nil for UID \(uid)", category: logCategory)
                throw IMAPError.messageFetchFailed
            }
            Logger.debug("Step 1 OK: Got message info", category: logCategory)

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
        
        // Basic conversion with available fields
        return IMAPMessageData(
            uid: uidValue,
            sequenceNumber: seqNum,
            flags: flagStrings,
            size: nil, // SwiftMail MessageInfo doesn't have size directly
            envelope: IMAPEnvelope(
                date: nil,
                subject: "",
                from: [],
                sender: [],
                replyTo: [],
                to: [],
                cc: [],
                bcc: [],
                inReplyTo: nil,
                messageId: nil
            ),
            bodyStructure: nil,
            rfc822: nil,
            internalDate: nil
        )
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
