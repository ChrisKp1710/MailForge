import Foundation
import NIOCore

// MARK: - SMTP Line Decoder

/// Decodes incoming bytes into lines (SMTP responses are line-based)
final class SMTPLineDecoder: ByteToMessageDecoder {
    typealias InboundOut = String

    /// Delimiter for SMTP lines
    private let delimiter: UInt8 = 10 // '\n'

    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        let readable = buffer.withUnsafeReadableBytes { $0.firstIndex(of: delimiter) }

        guard let index = readable else {
            // No complete line yet, need more data
            return .needMoreData
        }

        // Extract line including delimiter
        guard let line = buffer.readString(length: index + 1) else {
            throw SMTPError.serverError(message: "Failed to read line from buffer")
        }

        // Remove CRLF or LF
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        Logger.debug("SMTP ← \(trimmed)", category: .smtp)

        // Forward to next handler
        context.fireChannelRead(self.wrapInboundOut(trimmed))

        return .continue
    }

    func decodeLast(context: ChannelHandlerContext, buffer: inout ByteBuffer, seenEOF: Bool) throws -> DecodingState {
        // Process any remaining data
        if buffer.readableBytes > 0 {
            if let line = buffer.readString(length: buffer.readableBytes) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                Logger.debug("SMTP ← \(trimmed)", category: .smtp)
                context.fireChannelRead(self.wrapInboundOut(trimmed))
            }
        }
        return .needMoreData
    }
}

// MARK: - SMTP Line Encoder

/// Encodes outgoing strings into bytes
final class SMTPLineEncoder: MessageToByteEncoder {
    typealias OutboundIn = String

    func encode(data: String, out: inout ByteBuffer) throws {
        out.writeString(data)
    }
}

// MARK: - SMTP Response

/// Represents an SMTP server response
struct SMTPResponse {
    /// Response code (e.g., 220, 250, 354, 535)
    let code: Int

    /// Response message
    let message: String

    /// Is this a multi-line response?
    let isMultiLine: Bool

    /// Parse SMTP response line
    /// - Parameter line: Raw response line
    /// - Returns: Parsed SMTPResponse or nil if invalid
    static func parse(_ line: String) -> SMTPResponse? {
        // SMTP response format: "CODE MESSAGE" or "CODE-MESSAGE" (multi-line)
        guard line.count >= 3 else {
            return nil
        }

        let codeString = String(line.prefix(3))
        guard let code = Int(codeString) else {
            return nil
        }

        let isMultiLine = line.count > 3 && line[line.index(line.startIndex, offsetBy: 3)] == "-"

        let messageStart = line.index(line.startIndex, offsetBy: min(4, line.count))
        let message = messageStart < line.endIndex ? String(line[messageStart...]) : ""

        return SMTPResponse(code: code, message: message, isMultiLine: isMultiLine)
    }

    /// Check if response indicates success (2xx codes)
    var isSuccess: Bool {
        return code >= 200 && code < 300
    }

    /// Check if response indicates error (4xx or 5xx codes)
    var isError: Bool {
        return code >= 400
    }

    /// Check if response is intermediate (3xx codes)
    var isIntermediate: Bool {
        return code >= 300 && code < 400
    }
}

// MARK: - SMTP Response Codes

/// Common SMTP response codes
enum SMTPResponseCode: Int {
    // 2xx Success
    case serviceReady = 220                    // Service ready
    case serviceClosing = 221                  // Service closing
    case authSuccess = 235                     // Authentication successful
    case ok = 250                              // Requested mail action okay, completed
    case userNotLocal = 251                    // User not local; will forward
    case cannotVerify = 252                    // Cannot verify user, but will accept

    // 3xx Intermediate
    case startMailInput = 354                  // Start mail input; end with <CRLF>.<CRLF>
    case authContinue = 334                    // Server challenge (AUTH continuation)

    // 4xx Temporary Error
    case serviceNotAvailable = 421             // Service not available
    case mailboxBusy = 450                     // Mailbox unavailable
    case localError = 451                      // Requested action aborted: local error
    case insufficientStorage = 452             // Insufficient system storage

    // 5xx Permanent Error
    case syntaxError = 500                     // Syntax error, command unrecognized
    case parameterError = 501                  // Syntax error in parameters
    case commandNotImplemented = 502           // Command not implemented
    case badSequence = 503                     // Bad sequence of commands
    case parameterNotImplemented = 504         // Command parameter not implemented
    case authFailed = 535                      // Authentication failed
    case mailboxNotFound = 550                 // Mailbox not found
    case userNotLocal551 = 551                 // User not local; please try <forward-path>
    case exceededStorage = 552                 // Exceeded storage allocation
    case mailboxNameNotAllowed = 553           // Mailbox name not allowed
    case transactionFailed = 554               // Transaction failed

    /// Get error description for code
    var description: String {
        switch self {
        case .serviceReady: return "Service ready"
        case .serviceClosing: return "Service closing"
        case .authSuccess: return "Authentication successful"
        case .ok: return "OK"
        case .userNotLocal: return "User not local; will forward"
        case .cannotVerify: return "Cannot verify user"
        case .startMailInput: return "Start mail input"
        case .authContinue: return "Authentication continue"
        case .serviceNotAvailable: return "Service not available"
        case .mailboxBusy: return "Mailbox busy"
        case .localError: return "Local error"
        case .insufficientStorage: return "Insufficient storage"
        case .syntaxError: return "Syntax error"
        case .parameterError: return "Parameter error"
        case .commandNotImplemented: return "Command not implemented"
        case .badSequence: return "Bad sequence"
        case .parameterNotImplemented: return "Parameter not implemented"
        case .authFailed: return "Authentication failed"
        case .mailboxNotFound: return "Mailbox not found"
        case .userNotLocal551: return "User not local"
        case .exceededStorage: return "Exceeded storage"
        case .mailboxNameNotAllowed: return "Mailbox name not allowed"
        case .transactionFailed: return "Transaction failed"
        }
    }
}

// MARK: - SMTP Response Handler

/// Channel handler that processes SMTP server responses
final class SMTPResponseHandler: ChannelInboundHandler {
    typealias InboundIn = String

    /// Active response collector (waiting for server response)
    private var collector: SMTPResponseCollector?
    private let collectorLock = NSLock()

    /// Logger category
    private let logCategory: Logger.Category = .smtp

    // MARK: - Channel Handler

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let line = unwrapInboundIn(data)

        // Parse SMTP response
        guard let response = SMTPResponse.parse(line) else {
            Logger.warning("Failed to parse SMTP response: \(line)", category: logCategory)
            return
        }

        Logger.debug("SMTP response: \(response.code) - \(response.message)", category: logCategory)

        // Forward to collector if one is registered
        collectorLock.lock()
        defer { collectorLock.unlock() }

        if let collector = collector {
            collector.addResponse(response)

            // If this is the final line (not multi-line), complete the collector
            if !response.isMultiLine {
                collector.complete()
                self.collector = nil
            }
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        Logger.error("SMTP handler error", error: error, category: logCategory)

        collectorLock.lock()
        defer { collectorLock.unlock() }

        if let collector = collector {
            collector.fail(error: error)
            self.collector = nil
        }

        context.fireErrorCaught(error)
    }

    // MARK: - Collector Management

    /// Register a collector to receive the next response
    func registerCollector(_ collector: SMTPResponseCollector) {
        collectorLock.lock()
        defer { collectorLock.unlock() }

        self.collector = collector
    }
}

// MARK: - SMTP Response Collector

/// Collects SMTP responses for a single command/operation
final class SMTPResponseCollector {

    /// Collected responses (can be multi-line)
    private var responses: [SMTPResponse] = []

    /// Continuation to resume when response is complete
    private var continuation: CheckedContinuation<[SMTPResponse], Error>?

    /// Lock for thread-safe access
    private let lock = NSLock()

    /// Logger category
    private let logCategory: Logger.Category = .smtp

    // MARK: - Response Collection

    /// Add a response line
    func addResponse(_ response: SMTPResponse) {
        lock.lock()
        defer { lock.unlock() }

        responses.append(response)
        Logger.debug("Collected SMTP response: \(response.code) - \(response.message)", category: logCategory)
    }

    /// Mark collection as complete and resume waiting task
    func complete() {
        lock.lock()
        defer { lock.unlock() }

        if let continuation = continuation {
            Logger.debug("SMTP response collection complete: \(responses.count) line(s)", category: logCategory)
            continuation.resume(returning: responses)
            self.continuation = nil
        }
    }

    /// Fail the collection with an error
    func fail(error: Error) {
        lock.lock()
        defer { lock.unlock() }

        if let continuation = continuation {
            Logger.error("SMTP response collection failed", error: error, category: logCategory)
            continuation.resume(throwing: error)
            self.continuation = nil
        }
    }

    // MARK: - Async Wait

    /// Wait for the response to be collected
    /// - Returns: Array of SMTP responses (multi-line responses will have multiple entries)
    func wait() async throws -> [SMTPResponse] {
        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            defer { lock.unlock() }

            self.continuation = continuation
        }
    }
}
