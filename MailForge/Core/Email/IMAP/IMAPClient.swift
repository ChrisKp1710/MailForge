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
        channel.pipeline.addHandlers([
            ByteToMessageHandler(IMAPLineDecoder()),
            MessageToByteHandler(IMAPLineEncoder()),
            IMAPResponseDecoder(),
            responseHandler
        ]).whenComplete { result in
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

        let response = try await sendTaggedCommand("CAPABILITY")

        // Check if successful
        if case .tagged(_, let status, let message) = response, status != .ok {
            throw IMAPError.serverError(message: "CAPABILITY failed: \(message)")
        }

        // TODO: Extract capabilities from untagged responses
        // For now, return empty array
        Logger.info("CAPABILITY command successful", category: logCategory)
        return []
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

        let response = try await sendTaggedCommand("LOGIN \(quotedUsername) \(quotedPassword)")

        // Check response
        if case .tagged(_, let status, let message) = response {
            if status == .ok {
                state = .authenticated
                Logger.info("Successfully authenticated", category: logCategory)
            } else {
                Logger.error("Authentication failed: \(message)", category: logCategory)
                throw IMAPError.authenticationFailed
            }
        } else {
            throw IMAPError.authenticationFailed
        }
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
    /// - Returns: IMAPResponse
    private func sendTaggedCommand(_ command: String) async throws -> IMAPResponse {
        let tag = generateTag()
        let fullCommand = "\(tag) \(command)"

        try await sendCommand(fullCommand)

        // TODO: Wait for tagged response with matching tag
        // For now, return a placeholder
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        return .tagged(tag: tag, status: .ok, message: "OK")
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
enum IMAPState {
    case notAuthenticated
    case authenticated
    case selected(folder: String)
    case logout
}
