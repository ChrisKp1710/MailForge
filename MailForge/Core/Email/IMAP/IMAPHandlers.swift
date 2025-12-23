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
        if content.hasPrefix("LIST") {
            // TODO: Parse LIST response properly
            return .list(folders: [])
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
}

// MARK: - IMAP Response Handler

/// Handles parsed IMAP responses
final class IMAPResponseHandler: ChannelInboundHandler {
    typealias InboundIn = IMAPResponse

    /// Pending responses waiting for completion
    private var pendingResponses: [String: CheckedContinuation<IMAPResponse, Error>] = [:]

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let response = self.unwrapInboundIn(data)

        // Handle response based on type
        switch response {
        case .greeting(let message):
            Logger.info("Server greeting: \(message)", category: .imap)

        case .capability(let capabilities):
            Logger.debug("Server capabilities: \(capabilities.joined(separator: ", "))", category: .imap)

        case .tagged(let tag, let status, let message):
            handleTaggedResponse(tag: tag, status: status, message: message)

        case .untagged(let data):
            Logger.debug("Untagged response: \(data)", category: .imap)

        case .continuation(let message):
            Logger.debug("Continuation: \(message)", category: .imap)

        case .exists(let count):
            Logger.debug("Messages exist: \(count)", category: .imap)

        case .recent(let count):
            Logger.debug("Recent messages: \(count)", category: .imap)

        case .flags, .list, .fetch:
            // TODO: Handle these response types
            break

        case .unknown(let raw):
            Logger.warning("Unknown response: \(raw)", category: .imap)
        }
    }

    /// Handle tagged response
    private func handleTaggedResponse(tag: String, status: IMAPResponseStatus, message: String) {
        Logger.debug("Response [\(tag)]: \(status) - \(message)", category: .imap)

        // Resume continuation waiting for this tag
        if let continuation = pendingResponses.removeValue(forKey: tag) {
            let response = IMAPResponse.tagged(tag: tag, status: status, message: message)
            continuation.resume(returning: response)
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        Logger.error("IMAP handler error", error: error, category: .imap)
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
    case list(folders: [String])
    case fetch(uid: Int64, data: [String: String])
    case unknown(raw: String)
}

/// IMAP response status
enum IMAPResponseStatus: String {
    case ok = "OK"
    case no = "NO"
    case bad = "BAD"
}
