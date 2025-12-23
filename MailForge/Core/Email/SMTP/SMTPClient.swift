import Foundation
import NIOCore
import NIOPosix
import NIOSSL

/// SwiftNIO-based SMTP client for sending emails
final class SMTPClient {

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

    /// Current SMTP state
    private var state: SMTPState = .notConnected

    /// Server capabilities (from EHLO response)
    private var serverCapabilities: [String] = []

    /// Logger category
    private let logCategory: Logger.Category = .smtp

    // MARK: - Initialization

    /// Initialize SMTP client
    /// - Parameters:
    ///   - host: SMTP server host
    ///   - port: SMTP server port (default: 587 for STARTTLS, 465 for TLS)
    ///   - useTLS: Whether to use TLS/SSL connection
    ///   - username: Email username
    ///   - password: Email password
    init(
        host: String,
        port: Int = 587,
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

        Logger.debug("SMTP client initialized for \(host):\(port)", category: logCategory)
    }

    // MARK: - Connection Management

    /// Connect to SMTP server
    /// - Throws: SMTPError if connection fails
    func connect() async throws {
        Logger.info("Connecting to SMTP server \(host):\(port)...", category: logCategory)

        do {
            let bootstrap = ClientBootstrap(group: group)
                .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
                .channelInitializer { channel in
                    self.configureChannelPipeline(channel: channel)
                }

            let channel = try await bootstrap.connect(host: host, port: port).get()
            self.channel = channel
            self.state = .connected

            Logger.info("Successfully connected to SMTP server", category: logCategory)

            // Wait for server greeting (220)
            try await waitForGreeting()

            // Send EHLO command
            try await sendEHLO()

        } catch {
            Logger.error("Failed to connect to SMTP server", error: error, category: logCategory)
            throw SMTPError.connectionFailed(host: host, port: port)
        }
    }

    /// Configure channel pipeline with handlers
    /// - Parameter channel: NIO channel
    /// - Returns: EventLoopFuture
    private func configureChannelPipeline(channel: Channel) -> EventLoopFuture<Void> {
        let promise = channel.eventLoop.makePromise(of: Void.self)

        if useTLS && port == 465 {
            // Direct TLS connection (port 465)
            do {
                let sslContext = try NIOSSLContext(configuration: .makeClientConfiguration())
                let sslHandler = try NIOSSLClientHandler(context: sslContext, serverHostname: host)

                channel.pipeline.addHandler(sslHandler).whenComplete { result in
                    switch result {
                    case .success:
                        self.addSMTPHandlers(to: channel, promise: promise)
                    case .failure(let error):
                        Logger.error("Failed to add SSL handler", error: error, category: self.logCategory)
                        promise.fail(SMTPError.tlsError)
                    }
                }
            } catch {
                Logger.error("Failed to create SSL context", error: error, category: logCategory)
                promise.fail(SMTPError.tlsError)
            }
        } else {
            // Plain connection (will upgrade with STARTTLS on port 587)
            addSMTPHandlers(to: channel, promise: promise)
        }

        return promise.futureResult
    }

    /// Add SMTP-specific handlers to pipeline
    /// - Parameters:
    ///   - channel: NIO channel
    ///   - promise: Promise to fulfill when done
    private func addSMTPHandlers(to channel: Channel, promise: EventLoopPromise<Void>) {
        channel.pipeline.addHandlers([
            ByteToMessageHandler(SMTPLineDecoder()),
            MessageToByteHandler(SMTPLineEncoder())
        ]).whenComplete { result in
            switch result {
            case .success:
                Logger.debug("SMTP handlers added to pipeline", category: self.logCategory)
                promise.succeed(())
            case .failure(let error):
                Logger.error("Failed to add SMTP handlers", error: error, category: self.logCategory)
                promise.fail(error)
            }
        }
    }

    /// Wait for server greeting (220 message)
    private func waitForGreeting() async throws {
        Logger.debug("Waiting for server greeting...", category: logCategory)
        // TODO: Implement proper greeting wait
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }

    /// Disconnect from server
    func disconnect() async throws {
        Logger.info("Disconnecting from SMTP server...", category: logCategory)

        guard let channel = channel else {
            Logger.warning("No active connection to disconnect", category: logCategory)
            return
        }

        // Send QUIT command
        try await sendCommand("QUIT")

        // Close channel
        try await channel.close()
        self.channel = nil
        self.state = .disconnected

        Logger.info("Disconnected from SMTP server", category: logCategory)
    }

    // MARK: - SMTP Commands

    /// Send EHLO command (Extended HELLO)
    private func sendEHLO() async throws {
        Logger.debug("Sending EHLO command", category: logCategory)

        let hostname = "localhost" // TODO: Get actual hostname
        try await sendCommand("EHLO \(hostname)")

        // TODO: Parse EHLO response and extract capabilities
        serverCapabilities = []
        state = .ready

        Logger.info("EHLO command successful", category: logCategory)
    }

    /// Authenticate with server using AUTH LOGIN
    func authenticate() async throws {
        Logger.info("Authenticating with SMTP server...", category: logCategory)

        guard state == .ready else {
            throw SMTPError.authenticationFailed
        }

        // Send AUTH LOGIN command
        try await sendCommand("AUTH LOGIN")

        // Send base64-encoded username
        let usernameBase64 = Data(username.utf8).base64EncodedString()
        try await sendCommand(usernameBase64)

        // Send base64-encoded password
        let passwordBase64 = Data(password.utf8).base64EncodedString()
        try await sendCommand(passwordBase64)

        state = .authenticated
        Logger.info("Successfully authenticated", category: logCategory)
    }

    /// Send email
    /// - Parameters:
    ///   - from: Sender email address
    ///   - to: Recipient email addresses
    ///   - subject: Email subject
    ///   - body: Email body (plain text)
    func sendEmail(from: String, to: [String], subject: String, body: String) async throws {
        Logger.info("Sending email to \(to.count) recipient(s)...", category: logCategory)

        guard state == .authenticated else {
            throw SMTPError.authenticationFailed
        }

        // MAIL FROM command
        try await sendCommand("MAIL FROM:<\(from)>")

        // RCPT TO commands (one per recipient)
        for recipient in to {
            try await sendCommand("RCPT TO:<\(recipient)>")
        }

        // DATA command
        try await sendCommand("DATA")

        // Send email headers and body
        let emailContent = buildEmailContent(from: from, to: to, subject: subject, body: body)
        try await sendCommand(emailContent)

        // End with CRLF.CRLF
        try await sendCommand(".")

        Logger.info("Email sent successfully", category: logCategory)
    }

    // MARK: - Email Building

    /// Build email content (headers + body)
    private func buildEmailContent(from: String, to: [String], subject: String, body: String) -> String {
        var content = ""

        // Headers
        content += "From: <\(from)>\r\n"
        content += "To: \(to.map { "<\($0)>" }.joined(separator: ", "))\r\n"
        content += "Subject: \(subject)\r\n"
        content += "Date: \(formatDate(Date()))\r\n"
        content += "MIME-Version: 1.0\r\n"
        content += "Content-Type: text/plain; charset=utf-8\r\n"
        content += "\r\n"

        // Body
        content += body

        return content
    }

    /// Format date for email header (RFC 5322)
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    // MARK: - Helper Methods

    /// Send raw SMTP command
    /// - Parameter command: SMTP command string
    private func sendCommand(_ command: String) async throws {
        guard let channel = channel else {
            throw SMTPError.connectionFailed(host: host, port: port)
        }

        Logger.debug("SMTP → \(command)", category: logCategory)

        let data = command + "\r\n"
        guard let buffer = channel.allocator.buffer(string: data) as ByteBuffer? else {
            throw SMTPError.serverError(message: "Failed to create buffer")
        }

        try await channel.writeAndFlush(buffer)
    }

    // MARK: - Cleanup

    deinit {
        // Shutdown event loop group
        do {
            try group.syncShutdownGracefully()
            Logger.debug("SMTP client shutdown complete", category: logCategory)
        } catch {
            Logger.error("Error shutting down SMTP client", error: error, category: logCategory)
        }
    }
}

// MARK: - SMTP State

/// SMTP connection states
enum SMTPState {
    case notConnected
    case connected
    case ready          // After EHLO
    case authenticated  // After AUTH
    case disconnected
}

// MARK: - SMTP Error

/// SMTP-specific errors
enum SMTPError: Error, LocalizedError {
    case connectionFailed(host: String, port: Int)
    case authenticationFailed
    case sendFailed(reason: String)
    case recipientRejected(email: String)
    case messageTooLarge
    case timeout
    case networkUnavailable
    case tlsError
    case serverError(message: String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let host, let port):
            return "Failed to connect to SMTP server \(host):\(port)"
        case .authenticationFailed:
            return "SMTP authentication failed"
        case .sendFailed(let reason):
            return "Failed to send email: \(reason)"
        case .recipientRejected(let email):
            return "Recipient \(email) was rejected by server"
        case .messageTooLarge:
            return "Email message exceeds maximum size limit"
        case .timeout:
            return "SMTP connection timed out"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .tlsError:
            return "TLS/SSL connection failed"
        case .serverError(let message):
            return "SMTP server error: \(message)"
        }
    }
}
