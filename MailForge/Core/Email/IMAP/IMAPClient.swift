import Foundation
import NIOCore
import NIOPosix
import NIOSSL

/// SwiftNIO-based IMAP client for email operations
final class IMAPClient {

    // MARK: - Properties

    /// Server configuration
    private let host: String
    private let port: Int
    private let useTLS: Bool

    /// Authentication credentials
    private let username: String
    private let password: String

    /// NIO event loop group
    private let group: MultiThreadedEventLoopGroup

    /// Active channel
    private var channel: Channel?

    /// Current IMAP state
    private var state: IMAPState = .notAuthenticated

    /// Response handler
    private let responseHandler: IMAPResponseHandler

    /// Command tag counter
    private var tagCounter: Int = 0
    private let tagLock = NSLock()

    /// Logger category
    private let logCategory: Logger.Category = .imap

    // MARK: - Initialization

    /// Initialize IMAP client
    /// - Parameters:
    ///   - host: IMAP server host
    ///   - port: IMAP server port (default: 993 for TLS, 143 for non-TLS)
    ///   - useTLS: Whether to use TLS/SSL connection
    ///   - username: Email username
    ///   - password: Email password
    init(
        host: String,
        port: Int,
        useTLS: Bool = true,
        username: String,
        password: String
    ) {
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.username = username
        self.password = password
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.responseHandler = IMAPResponseHandler()

        Logger.debug("IMAP client initialized for \(host):\(port)", category: logCategory)
    }

    // MARK: - Connection Management

    /// Connect to IMAP server
    /// - Throws: IMAPError if connection fails
    func connect() async throws {
        Logger.info("Connecting to IMAP server \(host):\(port)...", category: logCategory)

        do {
            let bootstrap = ClientBootstrap(group: group)
                .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
                .channelInitializer { channel in
                    self.configureChannelPipeline(channel: channel)
                }

            let channel = try await bootstrap.connect(host: host, port: port).get()
            self.channel = channel

            Logger.info("Successfully connected to IMAP server", category: logCategory)

            // Wait for server greeting
            try await waitForGreeting()

            // Perform CAPABILITY check
            try await capability()

        } catch {
            Logger.error("Failed to connect to IMAP server", error: error, category: logCategory)
            throw IMAPError.connectionFailed(host: host, port: port)
        }
    }

    /// Configure channel pipeline with handlers
    /// - Parameter channel: NIO channel
    /// - Returns: EventLoopFuture
    private func configureChannelPipeline(channel: Channel) -> EventLoopFuture<Void> {
        let promise = channel.eventLoop.makePromise(of: Void.self)

        if useTLS {
            // Configure TLS/SSL
            do {
                let sslContext = try NIOSSLContext(configuration: .makeClientConfiguration())
                let sslHandler = try NIOSSLClientHandler(context: sslContext, serverHostname: host)

                channel.pipeline.addHandler(sslHandler).whenComplete { result in
                    switch result {
                    case .success:
                        self.addIMAPHandlers(to: channel, promise: promise)
                    case .failure(let error):
                        Logger.error("Failed to add SSL handler", error: error, category: self.logCategory)
                        promise.fail(IMAPError.tlsError)
                    }
                }
            } catch {
                Logger.error("Failed to create SSL context", error: error, category: logCategory)
                promise.fail(IMAPError.tlsError)
            }
        } else {
            // No TLS - add handlers directly
            addIMAPHandlers(to: channel, promise: promise)
        }

        return promise.futureResult
    }

    /// Add IMAP-specific handlers to pipeline
    /// - Parameters:
    ///   - channel: NIO channel
    ///   - promise: Promise to fulfill when done
    private func addIMAPHandlers(to channel: Channel, promise: EventLoopPromise<Void>) {
        // Pipeline order (closest to socket first):
        // [Socket] -> [TLS/SSL if enabled] -> [ByteToMessageHandler] -> [IMAPResponseDecoder] -> [IMAPResponseHandler]
        // Note: We write ByteBuffer directly in sendCommand(), so no MessageToByteHandler needed

        // Add handlers in order from closest to socket to furthest
        channel.pipeline.addHandler(ByteToMessageHandler(IMAPLineDecoder()), name: "lineDecoder").flatMap {
            // Add response decoder
            channel.pipeline.addHandler(IMAPResponseDecoder(), name: "responseDecoder")
        }.flatMap {
            // Add response handler (furthest from socket)
            channel.pipeline.addHandler(self.responseHandler, name: "responseHandler")
        }.whenComplete { result in
            switch result {
            case .success:
                Logger.debug("IMAP handlers added to pipeline", category: self.logCategory)
                promise.succeed(())
            case .failure(let error):
                Logger.error("Failed to add IMAP handlers", error: error, category: self.logCategory)
                promise.fail(error)
            }
        }
    }

    /// Wait for server greeting
    private func waitForGreeting() async throws {
        Logger.debug("Waiting for server greeting...", category: logCategory)
        // TODO: Implement greeting wait logic
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }

    /// Disconnect from server
    func disconnect() async throws {
        Logger.info("Disconnecting from IMAP server...", category: logCategory)

        guard let channel = channel else {
            Logger.warning("No active connection to disconnect", category: logCategory)
            return
        }

        // Send LOGOUT command
        try await sendCommand("LOGOUT")

        // Close channel
        try await channel.close()
        self.channel = nil
        self.state = .logout

        Logger.info("Disconnected from IMAP server", category: logCategory)
    }

    // MARK: - IMAP Commands

    /// Send CAPABILITY command
    /// - Returns: Server capabilities
    @discardableResult
    func capability() async throws -> [String] {
        Logger.debug("Sending CAPABILITY command", category: logCategory)

        let result = try await sendTaggedCommand("CAPABILITY")

        // Check if successful
        guard result.isSuccess else {
            throw IMAPError.serverError(message: result.errorMessage ?? "CAPABILITY failed")
        }

        // Extract capabilities from untagged responses
        let caps = result.capabilities
        Logger.info("CAPABILITY command successful: \(caps.count) capabilities", category: logCategory)
        return caps
    }

    /// Login to IMAP server
    /// - Throws: IMAPError if authentication fails
    func login() async throws {
        Logger.info("Authenticating with IMAP server...", category: logCategory)

        guard state == .notAuthenticated else {
            Logger.warning("Already authenticated", category: logCategory)
            return
        }

        // Quote username and password for safety
        let quotedUsername = "\"\(username)\""
        let quotedPassword = "\"\(password)\""

        let result = try await sendTaggedCommand("LOGIN \(quotedUsername) \(quotedPassword)")

        // Check response
        if result.isSuccess {
            state = .authenticated
            Logger.info("Successfully authenticated", category: logCategory)
        } else {
            Logger.error("Authentication failed: \(result.errorMessage ?? "Unknown error")", category: logCategory)
            throw IMAPError.authenticationFailed
        }
    }

    // MARK: - Folder Operations

    /// List available folders on server
    /// - Parameters:
    ///   - reference: Reference name (default: "")
    ///   - pattern: Mailbox pattern (default: "*" for all folders)
    /// - Returns: Array of folder information
    func list(reference: String = "", pattern: String = "*") async throws -> [IMAPFolder] {
        Logger.debug("Listing folders with pattern: \(pattern)", category: logCategory)

        guard state != .notAuthenticated && state != .logout else {
            throw IMAPError.authenticationFailed
        }

        let quotedRef = reference.isEmpty ? "\"\"" : "\"\(reference)\""
        let quotedPattern = "\"\(pattern)\""

        let result = try await sendTaggedCommand("LIST \(quotedRef) \(quotedPattern)")

        // Check response
        guard result.isSuccess else {
            throw IMAPError.serverError(message: result.errorMessage ?? "LIST failed")
        }

        // Extract folders from untagged LIST responses
        let folders = result.folders
        Logger.info("LIST command successful: found \(folders.count) folders", category: logCategory)
        return folders
    }

    /// Select a folder for reading and writing
    /// - Parameter folder: Folder path (e.g., "INBOX")
    /// - Returns: Folder information (message count, recent count, etc.)
    func select(folder: String) async throws -> IMAPFolderInfo {
        Logger.info("Selecting folder: \(folder)", category: logCategory)

        guard state != .notAuthenticated && state != .logout else {
            throw IMAPError.authenticationFailed
        }

        let quotedFolder = "\"\(folder)\""
        let result = try await sendTaggedCommand("SELECT \(quotedFolder)")

        // Check response
        guard result.isSuccess else {
            Logger.error("SELECT failed: \(result.errorMessage ?? "Unknown error")", category: logCategory)
            throw IMAPError.folderNotFound(name: folder)
        }

        state = .selected(folder: folder)
        Logger.info("Folder '\(folder)' selected successfully", category: logCategory)

        // Parse folder info from untagged responses (EXISTS, RECENT, FLAGS, etc.)
        var info = result.folderInfo ?? IMAPFolderInfo(
            name: folder,
            exists: 0,
            recent: 0,
            unseen: nil,
            flags: [],
            permanentFlags: []
        )
        info.name = folder

        return info
    }

    /// Examine a folder in read-only mode
    /// - Parameter folder: Folder path (e.g., "INBOX")
    /// - Returns: Folder information (message count, recent count, etc.)
    func examine(folder: String) async throws -> IMAPFolderInfo {
        Logger.info("Examining folder (read-only): \(folder)", category: logCategory)

        guard state != .notAuthenticated && state != .logout else {
            throw IMAPError.authenticationFailed
        }

        let quotedFolder = "\"\(folder)\""
        let result = try await sendTaggedCommand("EXAMINE \(quotedFolder)")

        // Check response
        guard result.isSuccess else {
            Logger.error("EXAMINE failed: \(result.errorMessage ?? "Unknown error")", category: logCategory)
            throw IMAPError.folderNotFound(name: folder)
        }

        state = .selected(folder: folder)
        Logger.info("Folder '\(folder)' examined successfully (read-only)", category: logCategory)

        // Parse folder info from untagged responses
        var info = result.folderInfo ?? IMAPFolderInfo(
            name: folder,
            exists: 0,
            recent: 0,
            unseen: nil,
            flags: [],
            permanentFlags: []
        )
        info.name = folder
        info.isReadOnly = true

        return info
    }

    /// Close currently selected folder
    func close() async throws {
        Logger.debug("Closing selected folder", category: logCategory)

        guard case .selected = state else {
            Logger.warning("No folder currently selected", category: logCategory)
            return
        }

        let result = try await sendTaggedCommand("CLOSE")

        guard result.isSuccess else {
            throw IMAPError.serverError(message: result.errorMessage ?? "CLOSE failed")
        }

        state = .authenticated
        Logger.info("Folder closed successfully", category: logCategory)
    }

    // MARK: - Message Fetching

    /// Fetch messages by sequence number
    /// - Parameters:
    ///   - sequenceSet: Sequence set (e.g., "1", "1:*", "1,3,5")
    ///   - items: Items to fetch (e.g., ["FLAGS", "RFC822.SIZE", "ENVELOPE"])
    /// - Returns: Array of fetched message data
    func fetch(sequenceSet: String, items: [String]) async throws -> [IMAPMessageData] {
        Logger.debug("Fetching messages: \(sequenceSet), items: \(items.joined(separator: ", "))", category: logCategory)

        guard case .selected = state else {
            throw IMAPError.serverError(message: "No folder selected")
        }

        let itemsString = items.joined(separator: " ")
        let result = try await sendTaggedCommand("FETCH \(sequenceSet) (\(itemsString))")

        guard result.isSuccess else {
            throw IMAPError.messageFetchFailed
        }

        // Extract messages from untagged FETCH responses
        let messages = result.messages
        Logger.info("FETCH command successful: \(messages.count) messages", category: logCategory)
        return messages
    }

    /// Fetch messages by UID (more reliable than sequence numbers)
    /// - Parameters:
    ///   - uidSet: UID set (e.g., "1", "1:100", "1,3,5")
    ///   - items: Items to fetch
    /// - Returns: Array of fetched message data
    func uidFetch(uidSet: String, items: [String]) async throws -> [IMAPMessageData] {
        Logger.debug("UID Fetching messages: \(uidSet), items: \(items.joined(separator: ", "))", category: logCategory)

        guard case .selected = state else {
            throw IMAPError.serverError(message: "No folder selected")
        }

        let itemsString = items.joined(separator: " ")
        let result = try await sendTaggedCommand("UID FETCH \(uidSet) (\(itemsString))")

        guard result.isSuccess else {
            throw IMAPError.messageFetchFailed
        }

        // Extract messages from untagged UID FETCH responses
        let messages = result.messages
        Logger.info("UID FETCH command successful: \(messages.count) messages", category: logCategory)
        return messages
    }

    /// Fetch message headers (envelope)
    /// - Parameter uid: Message UID
    /// - Returns: Message data with envelope
    func fetchEnvelope(uid: Int64) async throws -> IMAPMessageData {
        Logger.debug("Fetching envelope for UID: \(uid)", category: logCategory)

        let messages = try await uidFetch(uidSet: "\(uid)", items: ["UID", "FLAGS", "ENVELOPE", "RFC822.SIZE", "INTERNALDATE"])

        guard let message = messages.first else {
            throw IMAPError.messageFetchFailed
        }

        return message
    }

    /// Fetch message body without marking as read (BODY.PEEK)
    /// - Parameter uid: Message UID
    /// - Returns: Message body data
    func fetchBodyPeek(uid: Int64) async throws -> Data {
        Logger.debug("Fetching body (peek) for UID: \(uid)", category: logCategory)

        let messages = try await uidFetch(uidSet: "\(uid)", items: ["BODY.PEEK[]"])

        guard let message = messages.first, let body = message.rfc822 else {
            throw IMAPError.messageFetchFailed
        }

        Logger.info("Body fetched successfully (not marked as read)", category: logCategory)
        return body
    }

    /// Fetch message body and mark as read
    /// - Parameter uid: Message UID
    /// - Returns: Message body data
    func fetchBody(uid: Int64) async throws -> Data {
        Logger.debug("Fetching body for UID: \(uid)", category: logCategory)

        let messages = try await uidFetch(uidSet: "\(uid)", items: ["BODY[]"])

        guard let message = messages.first, let body = message.rfc822 else {
            throw IMAPError.messageFetchFailed
        }

        Logger.info("Body fetched successfully (marked as read)", category: logCategory)
        return body
    }

    /// Fetch specific body section
    /// - Parameters:
    ///   - uid: Message UID
    ///   - section: Body section (e.g., "1", "1.MIME", "TEXT")
    ///   - peek: If true, don't mark as read
    /// - Returns: Section data
    func fetchBodySection(uid: Int64, section: String, peek: Bool = true) async throws -> Data {
        Logger.debug("Fetching body section [\(section)] for UID: \(uid), peek: \(peek)", category: logCategory)

        let bodyCommand = peek ? "BODY.PEEK[\(section)]" : "BODY[\(section)]"
        let messages = try await uidFetch(uidSet: "\(uid)", items: [bodyCommand])

        guard let message = messages.first, let body = message.rfc822 else {
            throw IMAPError.messageFetchFailed
        }

        return body
    }

    /// Fetch message flags
    /// - Parameter uid: Message UID
    /// - Returns: Array of flags
    func fetchFlags(uid: Int64) async throws -> [String] {
        Logger.debug("Fetching flags for UID: \(uid)", category: logCategory)

        let messages = try await uidFetch(uidSet: "\(uid)", items: ["FLAGS"])

        guard let message = messages.first else {
            throw IMAPError.messageFetchFailed
        }

        return message.flags
    }

    /// Fetch headers for multiple messages (optimized)
    /// - Parameter uidRange: UID range (e.g., "1:100")
    /// - Returns: Array of message data with headers
    func fetchHeaders(uidRange: String) async throws -> [IMAPMessageData] {
        Logger.debug("Fetching headers for UID range: \(uidRange)", category: logCategory)

        return try await uidFetch(
            uidSet: uidRange,
            items: ["UID", "FLAGS", "ENVELOPE", "RFC822.SIZE", "INTERNALDATE", "BODY.PEEK[HEADER]"]
        )
    }

    // MARK: - Search

    /// Search messages using criteria
    /// - Parameter criteria: Search criteria
    /// - Returns: Array of message sequence numbers matching criteria
    func search(criteria: IMAPSearchCriteria) async throws -> [Int] {
        Logger.debug("Searching with criteria: \(criteria.toIMAPString())", category: logCategory)

        guard case .selected = state else {
            throw IMAPError.serverError(message: "No folder selected")
        }

        let criteriaString = criteria.toIMAPString()
        let result = try await sendTaggedCommand("SEARCH \(criteriaString)")

        guard result.isSuccess else {
            throw IMAPError.serverError(message: result.errorMessage ?? "SEARCH failed")
        }

        // Extract search results from untagged response
        let results = result.searchResults.map { Int($0) }
        Logger.info("SEARCH command successful: \(results.count) results", category: logCategory)
        return results
    }

    /// Search messages by UID using criteria
    /// - Parameter criteria: Search criteria
    /// - Returns: Array of message UIDs matching criteria
    func uidSearch(criteria: IMAPSearchCriteria) async throws -> [Int64] {
        Logger.debug("UID Searching with criteria: \(criteria.toIMAPString())", category: logCategory)

        guard case .selected = state else {
            throw IMAPError.serverError(message: "No folder selected")
        }

        let criteriaString = criteria.toIMAPString()
        let result = try await sendTaggedCommand("UID SEARCH \(criteriaString)")

        guard result.isSuccess else {
            throw IMAPError.serverError(message: result.errorMessage ?? "UID SEARCH failed")
        }

        // Extract UID search results from untagged response
        let results = result.searchResults
        Logger.info("UID SEARCH command successful: \(results.count) UIDs", category: logCategory)
        return results
    }

    // MARK: - Flags & State Management

    /// Store (set) flags for messages
    /// - Parameters:
    ///   - uidSet: UID set (e.g., "1", "1:100")
    ///   - flags: Flags to set
    ///   - mode: Store mode (.add, .remove, .replace)
    func storeFlags(uidSet: String, flags: [IMAPMessageFlag], mode: StoreFlagsMode) async throws {
        Logger.debug("Storing flags for UIDs: \(uidSet), mode: \(mode)", category: logCategory)

        guard case .selected = state else {
            throw IMAPError.serverError(message: "No folder selected")
        }

        let flagsString = flags.map { $0.rawValue }.joined(separator: " ")
        let command: String

        switch mode {
        case .replace:
            command = "UID STORE \(uidSet) FLAGS (\(flagsString))"
        case .add:
            command = "UID STORE \(uidSet) +FLAGS (\(flagsString))"
        case .remove:
            command = "UID STORE \(uidSet) -FLAGS (\(flagsString))"
        }

        let result = try await sendTaggedCommand(command)

        guard result.isSuccess else {
            throw IMAPError.serverError(message: result.errorMessage ?? "STORE failed")
        }

        Logger.info("Flags stored successfully", category: logCategory)
    }

    /// Mark message as read
    /// - Parameter uid: Message UID
    func markAsRead(uid: Int64) async throws {
        Logger.debug("Marking UID \(uid) as read", category: logCategory)
        try await storeFlags(uidSet: "\(uid)", flags: [.seen], mode: .add)
    }

    /// Mark message as unread
    /// - Parameter uid: Message UID
    func markAsUnread(uid: Int64) async throws {
        Logger.debug("Marking UID \(uid) as unread", category: logCategory)
        try await storeFlags(uidSet: "\(uid)", flags: [.seen], mode: .remove)
    }

    /// Flag/star message
    /// - Parameter uid: Message UID
    func flagMessage(uid: Int64) async throws {
        Logger.debug("Flagging UID \(uid)", category: logCategory)
        try await storeFlags(uidSet: "\(uid)", flags: [.flagged], mode: .add)
    }

    /// Unflag/unstar message
    /// - Parameter uid: Message UID
    func unflagMessage(uid: Int64) async throws {
        Logger.debug("Unflagging UID \(uid)", category: logCategory)
        try await storeFlags(uidSet: "\(uid)", flags: [.flagged], mode: .remove)
    }

    /// Mark message for deletion (doesn't delete until EXPUNGE)
    /// - Parameter uid: Message UID
    func markAsDeleted(uid: Int64) async throws {
        Logger.debug("Marking UID \(uid) for deletion", category: logCategory)
        try await storeFlags(uidSet: "\(uid)", flags: [.deleted], mode: .add)
    }

    /// Permanently delete messages marked as deleted
    func expunge() async throws {
        Logger.info("Expunging deleted messages", category: logCategory)

        guard case .selected = state else {
            throw IMAPError.serverError(message: "No folder selected")
        }

        let result = try await sendTaggedCommand("EXPUNGE")

        guard result.isSuccess else {
            throw IMAPError.serverError(message: result.errorMessage ?? "EXPUNGE failed")
        }

        Logger.info("Messages expunged successfully", category: logCategory)
    }

    /// Copy messages to another folder
    /// - Parameters:
    ///   - uidSet: UID set to copy
    ///   - destinationFolder: Destination folder name
    func copyMessages(uidSet: String, to destinationFolder: String) async throws {
        Logger.info("Copying UIDs \(uidSet) to folder: \(destinationFolder)", category: logCategory)

        guard case .selected = state else {
            throw IMAPError.serverError(message: "No folder selected")
        }

        let quotedFolder = "\"\(destinationFolder)\""
        let result = try await sendTaggedCommand("UID COPY \(uidSet) \(quotedFolder)")

        guard result.isSuccess else {
            throw IMAPError.serverError(message: result.errorMessage ?? "COPY failed")
        }

        Logger.info("Messages copied successfully", category: logCategory)
    }

    /// Move messages to another folder (copy + delete)
    /// - Parameters:
    ///   - uidSet: UID set to move
    ///   - destinationFolder: Destination folder name
    func moveMessages(uidSet: String, to destinationFolder: String) async throws {
        Logger.info("Moving UIDs \(uidSet) to folder: \(destinationFolder)", category: logCategory)

        // Copy messages
        try await copyMessages(uidSet: uidSet, to: destinationFolder)

        // Mark as deleted
        try await markAsDeleted(uid: Int64(uidSet.split(separator: ":").first.map(String.init) ?? "0") ?? 0)

        Logger.info("Messages moved successfully", category: logCategory)
    }

    // MARK: - Helper Methods

    /// Send raw IMAP command
    /// - Parameter command: IMAP command string
    private func sendCommand(_ command: String) async throws {
        guard let channel = channel else {
            throw IMAPError.connectionFailed(host: host, port: port)
        }

        Logger.debug("Sending command: \(command)", category: logCategory)

        let data = command + "\r\n"
        guard let buffer = channel.allocator.buffer(string: data) as ByteBuffer? else {
            throw IMAPError.serverError(message: "Failed to create buffer")
        }

        try await channel.writeAndFlush(buffer)
    }

    /// Generate unique tag for IMAP command
    /// - Returns: Tag string (e.g., "A001")
    private func generateTag() -> String {
        tagLock.lock()
        defer { tagLock.unlock() }

        tagCounter += 1
        return String(format: "A%03d", tagCounter)
    }

    /// Send IMAP command and wait for tagged response
    /// - Parameter command: IMAP command (without tag)
    /// - Returns: IMAPCommandResult with tagged and untagged responses
    private func sendTaggedCommand(_ command: String) async throws -> IMAPCommandResult {
        let tag = generateTag()
        let fullCommand = "\(tag) \(command)"

        // Create collector for this command
        let collector = IMAPResponseCollector()

        // Register collector with response handler
        responseHandler.registerCollector(tag: tag, collector: collector)

        // Send command
        try await sendCommand(fullCommand)

        // Wait for response
        let result = try await collector.wait()

        return result
    }

    // MARK: - Cleanup

    deinit {
        // Shutdown event loop group
        do {
            try group.syncShutdownGracefully()
            Logger.debug("IMAP client shutdown complete", category: logCategory)
        } catch {
            Logger.error("Error shutting down IMAP client", error: error, category: logCategory)
        }
    }
}

// MARK: - IMAP State

/// IMAP connection states
enum IMAPState: Equatable {
    case notAuthenticated
    case authenticated
    case selected(folder: String)
    case logout
}

// MARK: - Store Flags Mode

/// Mode for storing flags
enum StoreFlagsMode {
    case replace  // Replace all flags
    case add      // Add flags to existing
    case remove   // Remove flags from existing
}
