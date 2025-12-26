import Foundation
import NIOCore

// MARK: - IMAP Line Decoder

/// Decodes incoming bytes into lines (IMAP responses are line-based)
final class IMAPLineDecoder: ByteToMessageDecoder {
    typealias InboundOut = String

    /// Delimiter for IMAP lines
    private let delimiter: UInt8 = 10 // '\n'

    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        let readable = buffer.withUnsafeReadableBytes { $0.firstIndex(of: delimiter) }

        guard let index = readable else {
            // No complete line yet, need more data
            return .needMoreData
        }

        // Extract line including delimiter
        guard let line = buffer.readString(length: index + 1) else {
            throw IMAPError.serverError(message: "Failed to read line from buffer")
        }

        // Remove CRLF or LF
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // Forward to next handler
        context.fireChannelRead(self.wrapInboundOut(trimmed))

        return .continue
    }

    func decodeLast(context: ChannelHandlerContext, buffer: inout ByteBuffer, seenEOF: Bool) throws -> DecodingState {
        // Process any remaining data
        if buffer.readableBytes > 0 {
            if let line = buffer.readString(length: buffer.readableBytes) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                context.fireChannelRead(self.wrapInboundOut(trimmed))
            }
        }
        return .needMoreData
    }
}

// MARK: - IMAP Line Encoder

/// Encodes outgoing strings into bytes
final class IMAPLineEncoder: MessageToByteEncoder {
    typealias OutboundIn = String

    func encode(data: String, out: inout ByteBuffer) throws {
        out.writeString(data)
    }
}

// MARK: - IMAP Response Decoder

/// Decodes IMAP response lines into structured responses
final class IMAPResponseDecoder: ChannelInboundHandler {
    typealias InboundIn = String
    typealias InboundOut = IMAPResponse

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let line = self.unwrapInboundIn(data)

        Logger.debug("IMAP ← \(line)", category: .imap)

        // Parse response
        let response = parseResponse(line)

        // Forward parsed response
        context.fireChannelRead(self.wrapInboundOut(response))
    }

    /// Parse IMAP response line
    /// - Parameter line: Raw response line
    /// - Returns: Parsed IMAPResponse
    private func parseResponse(_ line: String) -> IMAPResponse {
        // Untagged response (starts with *)
        if line.hasPrefix("* ") {
            return parseUntaggedResponse(line)
        }

        // Tagged response (starts with tag like A001)
        if let spaceIndex = line.firstIndex(of: " ") {
            let tag = String(line[..<spaceIndex])
            let remainder = String(line[line.index(after: spaceIndex)...])

            // Check status (OK, NO, BAD)
            if remainder.hasPrefix("OK") {
                return .tagged(tag: tag, status: .ok, message: extractMessage(remainder, prefix: "OK"))
            } else if remainder.hasPrefix("NO") {
                return .tagged(tag: tag, status: .no, message: extractMessage(remainder, prefix: "NO"))
            } else if remainder.hasPrefix("BAD") {
                return .tagged(tag: tag, status: .bad, message: extractMessage(remainder, prefix: "BAD"))
            }
        }

        // Continuation response (starts with +)
        if line.hasPrefix("+ ") {
            let message = String(line.dropFirst(2))
            return .continuation(message: message)
        }

        // Unknown format
        return .unknown(raw: line)
    }

    /// Parse untagged response
    private func parseUntaggedResponse(_ line: String) -> IMAPResponse {
        let content = String(line.dropFirst(2)) // Remove "* "

        // Server greeting (OK at start)
        if content.hasPrefix("OK") {
            return .greeting(message: extractMessage(content, prefix: "OK"))
        }

        // CAPABILITY response
        if content.hasPrefix("CAPABILITY") {
            let caps = content.dropFirst("CAPABILITY ".count).split(separator: " ").map(String.init)
            return .capability(capabilities: caps)
        }

        // EXISTS response
        if content.hasSuffix("EXISTS") {
            if let count = Int(content.split(separator: " ").first ?? "") {
                return .exists(count: count)
            }
        }

        // RECENT response
        if content.hasSuffix("RECENT") {
            if let count = Int(content.split(separator: " ").first ?? "") {
                return .recent(count: count)
            }
        }

        // FLAGS response
        if content.hasPrefix("FLAGS") {
            // TODO: Parse flags properly
            return .flags(flags: [])
        }

        // LIST response
        // Format: LIST (attributes) "delimiter" "folder-name"
        // Example: LIST (\HasNoChildren) "/" "INBOX"
        if content.hasPrefix("LIST") {
            let parsed = parseLISTResponse(content)
            if let folder = parsed {
                return .list(folder: folder)
            }
            // If parsing fails, return as unknown
            return .unknown(raw: line)
        }

        // FETCH response
        if content.contains("FETCH") {
            // TODO: Parse FETCH response properly
            return .fetch(uid: 0, data: [:])
        }

        // Generic untagged response
        return .untagged(data: content)
    }

    /// Extract message after status keyword
    private func extractMessage(_ text: String, prefix: String) -> String {
        guard let range = text.range(of: prefix) else {
            return text
        }

        let afterPrefix = text[range.upperBound...].trimmingCharacters(in: .whitespaces)
        return afterPrefix
    }

    /// Parse LIST response
    /// Format: LIST (attributes) "delimiter" "folder-name"
    /// Example: LIST (\HasNoChildren) "/" "INBOX"
    private func parseLISTResponse(_ content: String) -> IMAPFolder? {
        // Remove "LIST " prefix
        let afterLIST = content.dropFirst(5).trimmingCharacters(in: .whitespaces)

        // Extract attributes (between parentheses)
        var attributes: [String] = []
        var remainder = afterLIST

        if afterLIST.hasPrefix("(") {
            guard let closeParenIndex = afterLIST.firstIndex(of: ")") else {
                return nil
            }

            let attrsString = afterLIST[afterLIST.index(after: afterLIST.startIndex)..<closeParenIndex]
            attributes = attrsString.split(separator: " ").map { String($0) }

            remainder = String(afterLIST[afterLIST.index(after: closeParenIndex)...]).trimmingCharacters(in: .whitespaces)
        }

        // Extract delimiter (quoted string)
        var delimiter: String? = nil
        if remainder.hasPrefix("\"") {
            let afterQuote = remainder.dropFirst()
            guard let endQuoteIndex = afterQuote.firstIndex(of: "\"") else {
                return nil
            }

            delimiter = String(afterQuote[..<endQuoteIndex])
            remainder = String(afterQuote[afterQuote.index(after: endQuoteIndex)...]).trimmingCharacters(in: .whitespaces)
        } else if remainder.hasPrefix("NIL") {
            delimiter = nil
            remainder = String(remainder.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        }

        // Extract folder name (quoted string or unquoted)
        var folderName = ""
        if remainder.hasPrefix("\"") {
            let afterQuote = remainder.dropFirst()
            guard let endQuoteIndex = afterQuote.firstIndex(of: "\"") else {
                return nil
            }

            folderName = String(afterQuote[..<endQuoteIndex])
        } else {
            // Unquoted folder name
            folderName = remainder
        }

        guard !folderName.isEmpty else {
            return nil
        }

        return IMAPFolder(
            name: folderName,
            path: folderName,
            delimiter: delimiter,
            attributes: attributes
        )
    }
}

// MARK: - IMAP Response Handler

/// Handles parsed IMAP responses
final class IMAPResponseHandler: ChannelInboundHandler {
    typealias InboundIn = IMAPResponse

    /// Active collectors for pending commands
    private var collectors: [String: IMAPResponseCollector] = [:]
    private let lock = NSLock()

    /// Current tag being processed (for untagged responses)
    private var currentTag: String?

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let response = self.unwrapInboundIn(data)

        // Handle response based on type
        switch response {
        case .greeting(let message):
            Logger.info("Server greeting: \(message)", category: .imap)

        case .tagged(let tag, let status, let message):
            handleTaggedResponse(response)

        case .capability, .exists, .recent, .flags, .list, .fetch, .untagged, .continuation:
            // These are untagged responses - add to current collector
            handleUntaggedResponse(response)

        case .unknown(let raw):
            Logger.warning("Unknown response: \(raw)", category: .imap)
        }
    }

    /// Register a collector for a tag
    func registerCollector(tag: String, collector: IMAPResponseCollector) {
        lock.lock()
        defer { lock.unlock() }

        collectors[tag] = collector
        currentTag = tag
        Logger.debug("Registered collector for tag: \(tag)", category: .imap)
    }

    /// Handle tagged response (final response for command)
    private func handleTaggedResponse(_ response: IMAPResponse) {
        guard case .tagged(let tag, let status, let message) = response else {
            return
        }

        Logger.debug("Tagged response [\(tag)]: \(status) - \(message)", category: .imap)

        lock.lock()
        let collector = collectors.removeValue(forKey: tag)
        lock.unlock()

        collector?.complete(with: response)
    }

    /// Handle untagged response
    private func handleUntaggedResponse(_ response: IMAPResponse) {
        lock.lock()
        let tag = currentTag
        let collector = tag.flatMap { collectors[$0] }
        lock.unlock()

        if let collector = collector {
            collector.addUntagged(response)
        } else {
            // No collector - just log
            logUntaggedResponse(response)
        }
    }

    /// Log untagged response
    private func logUntaggedResponse(_ response: IMAPResponse) {
        switch response {
        case .capability(let capabilities):
            Logger.debug("Capabilities: \(capabilities.joined(separator: ", "))", category: .imap)
        case .exists(let count):
            Logger.debug("Messages exist: \(count)", category: .imap)
        case .recent(let count):
            Logger.debug("Recent messages: \(count)", category: .imap)
        case .untagged(let data):
            Logger.debug("Untagged: \(data)", category: .imap)
        default:
            break
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        // Check if this is an SSL shutdown error (expected during disconnect)
        let errorDescription = String(describing: error)
        let isSSLShutdownError = errorDescription.contains("NIOSSL") || errorDescription.contains("SSL")

        lock.lock()
        let allCollectors = Array(collectors.values)
        collectors.removeAll()
        lock.unlock()

        // SSL errors during shutdown are always benign and expected
        if isSSLShutdownError {
            Logger.debug("SSL shutdown (expected during disconnect): \(error)", category: .imap)
        } else {
            // Real non-SSL error - log it and fail pending collectors
            Logger.error("IMAP handler error", error: error, category: .imap)

            for collector in allCollectors {
                collector.fail(with: error)
            }
        }

        context.close(promise: nil)
    }
}

// MARK: - IMAP Response Types

/// Parsed IMAP response
enum IMAPResponse {
    case greeting(message: String)
    case capability(capabilities: [String])
    case tagged(tag: String, status: IMAPResponseStatus, message: String)
    case untagged(data: String)
    case continuation(message: String)
    case exists(count: Int)
    case recent(count: Int)
    case flags(flags: [String])
    case list(folder: IMAPFolder)
    case fetch(uid: Int64, data: [String: String])
    case unknown(raw: String)
}

/// IMAP response status
enum IMAPResponseStatus: String {
    case ok = "OK"
    case no = "NO"
    case bad = "BAD"
}
