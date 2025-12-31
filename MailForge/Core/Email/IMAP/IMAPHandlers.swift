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
        // Format: * <seq> FETCH (KEY value KEY value ...)
        // Example: * 186 FETCH (UID 2394 FLAGS (\Seen) ENVELOPE (...) ...)
        if content.contains("FETCH") {
            if let fetchData = parseFETCHResponse(content) {
                return .fetch(sequenceNumber: fetchData.sequenceNumber, data: fetchData.data)
            }
            // If parsing fails, log and return as unknown
            Logger.warning("Failed to parse FETCH response: \(line)", category: .imap)
            return .unknown(raw: line)
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

    /// Parse FETCH response
    /// Format: <seq> FETCH (KEY value KEY value ...)
    /// Example: 186 FETCH (UID 2394 FLAGS (\Seen) ENVELOPE (...) ...)
    private func parseFETCHResponse(_ content: String) -> (sequenceNumber: Int, data: IMAPFetchData)? {
        // Extract sequence number
        let components = content.split(separator: " ", maxSplits: 2)
        guard components.count >= 3,
              let seqNum = Int(components[0]),
              components[1] == "FETCH" else {
            return nil
        }

        // Extract the content inside parentheses
        let afterFetch = String(components[2])
        guard afterFetch.hasPrefix("("), afterFetch.hasSuffix(")") else {
            return nil
        }

        let dataContent = String(afterFetch.dropFirst().dropLast())

        // Parse key-value pairs
        var fetchData = IMAPFetchData()
        var position = dataContent.startIndex

        while position < dataContent.endIndex {
            // Skip whitespace
            while position < dataContent.endIndex && dataContent[position].isWhitespace {
                position = dataContent.index(after: position)
            }

            guard position < dataContent.endIndex else { break }

            // Extract key
            var keyEnd = position
            while keyEnd < dataContent.endIndex && !dataContent[keyEnd].isWhitespace {
                keyEnd = dataContent.index(after: keyEnd)
            }

            let key = String(dataContent[position..<keyEnd]).uppercased()
            position = keyEnd

            // Skip whitespace
            while position < dataContent.endIndex && dataContent[position].isWhitespace {
                position = dataContent.index(after: position)
            }

            guard position < dataContent.endIndex else { break }

            // Parse value based on key
            switch key {
            case "UID":
                if let (value, newPos) = parseNumber(from: dataContent, at: position) {
                    fetchData.uid = Int64(value)
                    position = newPos
                }

            case "RFC822.SIZE":
                if let (value, newPos) = parseNumber(from: dataContent, at: position) {
                    fetchData.size = Int64(value)
                    position = newPos
                }

            case "FLAGS":
                if let (flags, newPos) = parseFlags(from: dataContent, at: position) {
                    fetchData.flags = flags
                    position = newPos
                }

            case "INTERNALDATE":
                if let (date, newPos) = parseQuotedString(from: dataContent, at: position) {
                    fetchData.internalDate = date
                    position = newPos
                }

            case "ENVELOPE":
                if let (envelope, newPos) = parseEnvelope(from: dataContent, at: position) {
                    fetchData.envelope = envelope
                    position = newPos
                }

            case "BODYSTRUCTURE", "BODY":
                if let (_, newPos) = parseParenthesizedList(from: dataContent, at: position) {
                    // Skip body structure for now
                    position = newPos
                }

            default:
                // Unknown key, try to skip value
                if dataContent[position] == "(" {
                    if let (_, newPos) = parseParenthesizedList(from: dataContent, at: position) {
                        position = newPos
                    }
                } else if dataContent[position] == "\"" {
                    if let (_, newPos) = parseQuotedString(from: dataContent, at: position) {
                        position = newPos
                    }
                } else {
                    // Skip to next space or end
                    while position < dataContent.endIndex && !dataContent[position].isWhitespace {
                        position = dataContent.index(after: position)
                    }
                }
            }
        }

        return (seqNum, fetchData)
    }

    /// Parse a number from string
    private func parseNumber(from string: String, at position: String.Index) -> (Int, String.Index)? {
        var pos = position
        var numberStr = ""

        while pos < string.endIndex && string[pos].isNumber {
            numberStr.append(string[pos])
            pos = string.index(after: pos)
        }

        guard let number = Int(numberStr) else {
            return nil
        }

        return (number, pos)
    }

    /// Parse a quoted string
    private func parseQuotedString(from string: String, at position: String.Index) -> (String, String.Index)? {
        guard position < string.endIndex, string[position] == "\"" else {
            return nil
        }

        var pos = string.index(after: position)
        var result = ""
        var escaped = false

        while pos < string.endIndex {
            let char = string[pos]

            if escaped {
                result.append(char)
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else if char == "\"" {
                // End of string
                return (result, string.index(after: pos))
            } else {
                result.append(char)
            }

            pos = string.index(after: pos)
        }

        return nil // Unclosed quote
    }

    /// Parse flags list: (\Seen \Flagged)
    private func parseFlags(from string: String, at position: String.Index) -> ([String], String.Index)? {
        guard position < string.endIndex, string[position] == "(" else {
            return nil
        }

        var pos = string.index(after: position)
        var flags: [String] = []
        var currentFlag = ""

        while pos < string.endIndex {
            let char = string[pos]

            if char == ")" {
                // End of flags
                if !currentFlag.isEmpty {
                    flags.append(currentFlag)
                }
                return (flags, string.index(after: pos))
            } else if char.isWhitespace {
                if !currentFlag.isEmpty {
                    flags.append(currentFlag)
                    currentFlag = ""
                }
            } else {
                currentFlag.append(char)
            }

            pos = string.index(after: pos)
        }

        return nil // Unclosed parenthesis
    }

    /// Parse generic parenthesized list (returns raw content)
    private func parseParenthesizedList(from string: String, at position: String.Index) -> (String, String.Index)? {
        guard position < string.endIndex, string[position] == "(" else {
            return nil
        }

        var pos = string.index(after: position)
        var depth = 1
        var content = ""
        var inQuote = false
        var escaped = false

        while pos < string.endIndex && depth > 0 {
            let char = string[pos]

            if escaped {
                content.append(char)
                escaped = false
            } else if char == "\\" && inQuote {
                escaped = true
                content.append(char)
            } else if char == "\"" {
                inQuote.toggle()
                content.append(char)
            } else if char == "(" && !inQuote {
                depth += 1
                content.append(char)
            } else if char == ")" && !inQuote {
                depth -= 1
                if depth > 0 {
                    content.append(char)
                }
            } else {
                content.append(char)
            }

            pos = string.index(after: pos)
        }

        guard depth == 0 else {
            return nil // Unclosed parenthesis
        }

        return (content, pos)
    }

    /// Parse ENVELOPE structure
    /// Format: (date subject from sender reply-to to cc bcc in-reply-to message-id)
    private func parseEnvelope(from string: String, at position: String.Index) -> (IMAPEnvelopeRaw, String.Index)? {
        guard let (content, newPos) = parseParenthesizedList(from: string, at: position) else {
            return nil
        }

        // Parse envelope fields
        var fields: [String?] = []
        var pos = content.startIndex

        while pos < content.endIndex && fields.count < 10 {
            // Skip whitespace
            while pos < content.endIndex && content[pos].isWhitespace {
                pos = content.index(after: pos)
            }

            guard pos < content.endIndex else { break }

            if content[pos] == "\"" {
                // Quoted string
                if let (value, nextPos) = parseQuotedString(from: content, at: pos) {
                    fields.append(value)
                    pos = nextPos
                } else {
                    fields.append(nil)
                    break
                }
            } else if content[pos...].hasPrefix("NIL") {
                // NIL value
                fields.append(nil)
                pos = content.index(pos, offsetBy: 3)
            } else if content[pos] == "(" {
                // Address list or nested structure
                if let (_, nextPos) = parseParenthesizedList(from: content, at: pos) {
                    // Store the raw address list content for later parsing
                    let addressContent = String(content[pos..<nextPos])
                    fields.append(addressContent)
                    pos = nextPos
                } else {
                    fields.append(nil)
                    break
                }
            } else {
                // Unknown format, skip
                while pos < content.endIndex && !content[pos].isWhitespace && content[pos] != "(" {
                    pos = content.index(after: pos)
                }
            }
        }

        // Ensure we have enough fields (10 total)
        while fields.count < 10 {
            fields.append(nil)
        }

        // Parse address lists
        let from = parseAddressList(fields[2])
        let sender = parseAddressList(fields[3])
        let replyTo = parseAddressList(fields[4])
        let to = parseAddressList(fields[5])
        let cc = parseAddressList(fields[6])
        let bcc = parseAddressList(fields[7])

        let envelope = IMAPEnvelopeRaw(
            date: fields[0],
            subject: fields[1],
            from: from,
            sender: sender,
            replyTo: replyTo,
            to: to,
            cc: cc,
            bcc: bcc,
            inReplyTo: fields[8],
            messageId: fields[9]
        )

        return (envelope, newPos)
    }

    /// Parse address list from string
    /// Format: (("name" NIL "mailbox" "host") (...))
    private func parseAddressList(_ addressListStr: String?) -> [IMAPAddressRaw] {
        guard let str = addressListStr, str.hasPrefix("("), str.hasSuffix(")") else {
            return []
        }

        var addresses: [IMAPAddressRaw] = []
        let content = String(str.dropFirst().dropLast())
        var pos = content.startIndex

        while pos < content.endIndex {
            // Skip whitespace
            while pos < content.endIndex && content[pos].isWhitespace {
                pos = content.index(after: pos)
            }

            guard pos < content.endIndex else { break }

            if content[pos] == "(" {
                // Parse single address: ("name" NIL "mailbox" "host")
                if let (addressContent, newPos) = parseParenthesizedList(from: content, at: pos) {
                    if let address = parseSingleAddress(addressContent) {
                        addresses.append(address)
                    }
                    pos = newPos
                } else {
                    break
                }
            } else {
                // Unexpected format
                break
            }
        }

        return addresses
    }

    /// Parse single address
    /// Format: "name" "route" "mailbox" "host"
    /// Note: route is obsolete and usually NIL
    private func parseSingleAddress(_ content: String) -> IMAPAddressRaw? {
        var fields: [String?] = []
        var pos = content.startIndex

        while pos < content.endIndex && fields.count < 4 {
            // Skip whitespace
            while pos < content.endIndex && content[pos].isWhitespace {
                pos = content.index(after: pos)
            }

            guard pos < content.endIndex else { break }

            if content[pos] == "\"" {
                if let (value, nextPos) = parseQuotedString(from: content, at: pos) {
                    fields.append(value)
                    pos = nextPos
                } else {
                    break
                }
            } else if content[pos...].hasPrefix("NIL") {
                fields.append(nil)
                pos = content.index(pos, offsetBy: 3)
            } else {
                // Skip unknown
                while pos < content.endIndex && !content[pos].isWhitespace {
                    pos = content.index(after: pos)
                }
            }
        }

        guard fields.count >= 4 else {
            return nil
        }

        // IMAP address format: (name route mailbox host)
        // fields[0] = name
        // fields[1] = route (obsolete, usually NIL)
        // fields[2] = mailbox (local part)
        // fields[3] = host (domain part)
        return IMAPAddressRaw(
            name: fields[0],
            mailbox: fields[2],  // Skip route, use mailbox
            host: fields[3]      // Use host
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
    case fetch(sequenceNumber: Int, data: IMAPFetchData)
    case unknown(raw: String)
}

/// IMAP response status
enum IMAPResponseStatus: String {
    case ok = "OK"
    case no = "NO"
    case bad = "BAD"
}

/// IMAP FETCH data (parsed from FETCH response)
struct IMAPFetchData {
    var uid: Int64?
    var flags: [String]?
    var size: Int64?
    var internalDate: String?
    var envelope: IMAPEnvelopeRaw?
    var bodyStructure: String?
    var rfc822: Data?
    var bodyPeek: Data?
}

/// Raw ENVELOPE data (before parsing into IMAPEnvelope)
struct IMAPEnvelopeRaw {
    let date: String?
    let subject: String?
    let from: [IMAPAddressRaw]
    let sender: [IMAPAddressRaw]
    let replyTo: [IMAPAddressRaw]
    let to: [IMAPAddressRaw]
    let cc: [IMAPAddressRaw]
    let bcc: [IMAPAddressRaw]
    let inReplyTo: String?
    let messageId: String?
}

/// Raw address data (before parsing)
struct IMAPAddressRaw {
    let name: String?
    let mailbox: String?
    let host: String?
}
