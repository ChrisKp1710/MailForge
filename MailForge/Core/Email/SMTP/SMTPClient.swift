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

    /// Response handler
    private let responseHandler: SMTPResponseHandler

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
        self.responseHandler = SMTPResponseHandler()

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
            MessageToByteHandler(SMTPLineEncoder()),
            responseHandler
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

        let responses = try await waitForResponse()

        // Check for 220 Service Ready
        guard let firstResponse = responses.first, firstResponse.code == 220 else {
            let code = responses.first?.code ?? 0
            let message = responses.first?.message ?? "Unknown error"
            throw SMTPError.serverError(message: "Expected 220 greeting, got \(code): \(message)")
        }

        Logger.info("Server greeting received: \(firstResponse.message)", category: logCategory)
    }

    /// Disconnect from server
    func disconnect() async throws {
        Logger.info("Disconnecting from SMTP server...", category: logCategory)

        guard let channel = channel else {
            Logger.warning("No active connection to disconnect", category: logCategory)
            return
        }

        // Send QUIT command - expect 221 (Service closing)
        _ = try await sendCommandAndWait("QUIT", expectedCodes: [221])

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
        let responses = try await sendCommandAndWait("EHLO \(hostname)", expectedCodes: [250])

        // Parse EHLO response and extract capabilities
        serverCapabilities = responses.compactMap { response in
            // Skip the first line (250 hostname)
            guard response.code == 250, !response.message.isEmpty else { return nil }
            return response.message.trimmingCharacters(in: .whitespaces)
        }

        state = .ready

        Logger.info("EHLO successful - \(serverCapabilities.count) capabilities", category: logCategory)
    }

    /// Authenticate with server using AUTH LOGIN
    func authenticate() async throws {
        Logger.info("Authenticating with SMTP server...", category: logCategory)

        guard state == .ready else {
            throw SMTPError.authenticationFailed
        }

        // Send AUTH LOGIN command - expect 334 (Auth Continue)
        _ = try await sendCommandAndWait("AUTH LOGIN", expectedCodes: [334])

        // Send base64-encoded username - expect 334
        let usernameBase64 = Data(username.utf8).base64EncodedString()
        _ = try await sendCommandAndWait(usernameBase64, expectedCodes: [334])

        // Send base64-encoded password - expect 235 (Auth Success)
        let passwordBase64 = Data(password.utf8).base64EncodedString()
        let authResponse = try await sendCommandAndWait(passwordBase64, expectedCodes: [235])

        // Check authentication success
        guard authResponse.first?.code == 235 else {
            Logger.error("Authentication failed", category: logCategory)
            throw SMTPError.authenticationFailed
        }

        state = .authenticated
        Logger.info("Successfully authenticated", category: logCategory)
    }

    /// Send email using MIME message builder
    /// - Parameter message: MIME message to send
    func sendEmail(message: MIMEMessageBuilder) async throws {
        // Build recipients list (to + cc + bcc)
        let allRecipients = message.getAllRecipients()

        Logger.info("Sending email to \(allRecipients.count) recipient(s)...", category: logCategory)

        guard state == .authenticated else {
            throw SMTPError.authenticationFailed
        }

        // MAIL FROM command - expect 250
        _ = try await sendCommandAndWait("MAIL FROM:<\(message.getFrom())>")

        // RCPT TO commands (one per recipient) - expect 250
        for recipient in allRecipients {
            _ = try await sendCommandAndWait("RCPT TO:<\(recipient)>")
        }

        // DATA command - expect 354 (Start mail input)
        let dataResponse = try await sendCommandAndWait("DATA", expectedCodes: [354])
        guard dataResponse.first?.code == 354 else {
            throw SMTPError.sendFailed(reason: "DATA command rejected")
        }

        // Send complete MIME message (without waiting for response)
        let mimeContent = message.build()
        try await sendRawData(mimeContent)

        // End with CRLF.CRLF - expect 250 (Message accepted)
        let endResponse = try await sendCommandAndWait(".")
        guard endResponse.first?.isSuccess == true else {
            throw SMTPError.sendFailed(reason: "Message rejected by server")
        }

        Logger.info("Email sent successfully", category: logCategory)
    }

    /// Send email (simple convenience method)
    /// - Parameters:
    ///   - from: Sender email address
    ///   - to: Recipient email addresses
    ///   - subject: Email subject
    ///   - body: Email body (plain text)
    func sendEmail(from: String, to: [String], subject: String, body: String) async throws {
        let message = MIMEMessageBuilder(from: from, to: to, subject: subject)
            .textBody(body)

        try await sendEmail(message: message)
    }

    // MARK: - Raw Data Sending

    /// Send raw data without CRLF appending (for MIME content)
    /// - Parameter data: Raw data string
    private func sendRawData(_ data: String) async throws {
        guard let channel = channel else {
            throw SMTPError.connectionFailed(host: host, port: port)
        }

        Logger.debug("SMTP → [MIME content, \(data.count) bytes]", category: logCategory)

        guard let buffer = channel.allocator.buffer(string: data) as ByteBuffer? else {
            throw SMTPError.serverError(message: "Failed to create buffer")
        }

        try await channel.writeAndFlush(buffer)
    }

    // MARK: - Helper Methods

    /// Send raw SMTP command (without waiting for response)
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

    /// Wait for server response using collector
    /// - Returns: Array of SMTP responses (multi-line responses will have multiple entries)
    private func waitForResponse() async throws -> [SMTPResponse] {
        let collector = SMTPResponseCollector()
        responseHandler.registerCollector(collector)
        return try await collector.wait()
    }

    /// Send command and wait for response, checking for success
    /// - Parameters:
    ///   - command: SMTP command to send
    ///   - expectedCodes: Expected success codes (default: 250)
    /// - Returns: Array of responses
    /// - Throws: SMTPError if response indicates failure
    private func sendCommandAndWait(_ command: String, expectedCodes: [Int] = [250]) async throws -> [SMTPResponse] {
        // Send command
        try await sendCommand(command)

        // Wait for response
        let responses = try await waitForResponse()

        // Check if successful
        guard let firstResponse = responses.first else {
            throw SMTPError.serverError(message: "No response from server")
        }

        // Check if response code is expected
        if !expectedCodes.contains(firstResponse.code) && !firstResponse.isSuccess {
            throw SMTPError.serverError(message: "Command failed (\(firstResponse.code)): \(firstResponse.message)")
        }

        return responses
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

