import Foundation

// MARK: - Email Parser

/// Parser for RFC 5322 email messages
/// Handles headers, body extraction, MIME multipart, and attachments
final class EmailParser {

    // MARK: - Properties

    /// Logger category
    private let logCategory: Logger.Category = .email

    // MARK: - Parsing

    /// Parse raw email data into structured EmailMessage
    /// - Parameter data: Raw email data (headers + body)
    /// - Returns: Parsed EmailMessage
    /// - Throws: ParsingError if parsing fails
    func parse(data: Data) throws -> ParsedEmail {
        guard let rawString = String(data: data, encoding: .utf8) else {
            throw EmailParsingError.invalidEncoding
        }

        return try parse(string: rawString)
    }

    /// Parse raw email string into structured EmailMessage
    /// - Parameter string: Raw email string (headers + body)
    /// - Returns: Parsed EmailMessage
    /// - Throws: ParsingError if parsing fails
    func parse(string: String) throws -> ParsedEmail {
        Logger.debug("Parsing email (\(string.count) bytes)", category: logCategory)

        // Split headers and body (separated by double CRLF)
        let parts = string.components(separatedBy: "\r\n\r\n")
        guard parts.count >= 2 else {
            throw EmailParsingError.invalidFormat
        }

        let headerSection = parts[0]
        let bodySection = parts.dropFirst().joined(separator: "\r\n\r\n")

        // Parse headers
        let headers = try parseHeaders(headerSection)

        Logger.debug("Parsed \(headers.count) headers", category: logCategory)

        // Parse body based on Content-Type
        let contentType = headers["Content-Type"] ?? "text/plain"
        let body = try parseBody(bodySection, contentType: contentType, headers: headers)

        // Create parsed email
        let email = ParsedEmail(
            headers: headers,
            from: extractAddress(from: headers["From"]),
            to: extractAddresses(from: headers["To"]),
            cc: extractAddresses(from: headers["Cc"]),
            subject: decodeHeader(headers["Subject"]),
            date: parseDate(headers["Date"]),
            messageId: headers["Message-ID"],
            contentType: contentType,
            body: body
        )

        Logger.info("Email parsed successfully", category: logCategory)

        return email
    }

    // MARK: - Header Parsing

    /// Parse email headers (RFC 5322)
    /// - Parameter headerSection: Raw header string
    /// - Returns: Dictionary of header name → value
    private func parseHeaders(_ headerSection: String) throws -> [String: String] {
        var headers: [String: String] = [:]

        // Split into lines
        let lines = headerSection.components(separatedBy: "\r\n")

        var currentHeader: String?
        var currentValue = ""

        for line in lines {
            if line.isEmpty {
                continue
            }

            // Check if this is a continuation line (starts with whitespace)
            if line.first?.isWhitespace == true {
                // Continuation of previous header
                currentValue += " " + line.trimmingCharacters(in: .whitespaces)
            } else {
                // Save previous header if exists
                if let header = currentHeader {
                    headers[header] = currentValue.trimmingCharacters(in: .whitespaces)
                }

                // Parse new header (format: "Name: Value")
                if let colonIndex = line.firstIndex(of: ":") {
                    let headerName = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                    let headerValue = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

                    currentHeader = headerName
                    currentValue = headerValue
                } else {
                    Logger.warning("Invalid header line: \(line)", category: logCategory)
                }
            }
        }

        // Save last header
        if let header = currentHeader {
            headers[header] = currentValue.trimmingCharacters(in: .whitespaces)
        }

        return headers
    }

    // MARK: - Body Parsing

    /// Parse email body based on Content-Type
    /// - Parameters:
    ///   - bodySection: Raw body string
    ///   - contentType: Content-Type header value
    ///   - headers: All headers (for transfer encoding, etc.)
    /// - Returns: Parsed body
    private func parseBody(_ bodySection: String, contentType: String, headers: [String: String]) throws -> EmailBody {
        // Decode transfer encoding if present
        let transferEncoding = headers["Content-Transfer-Encoding"]?.lowercased()
        let decodedBody = try decodeBody(bodySection, encoding: transferEncoding)

        // Determine body type from Content-Type
        let contentTypeLower = contentType.lowercased()

        if contentTypeLower.contains("text/plain") {
            return .text(decodedBody)
        } else if contentTypeLower.contains("text/html") {
            return .html(decodedBody)
        } else if contentTypeLower.contains("multipart/") {
            // Parse multipart
            let boundary = extractBoundary(from: contentType)
            guard let boundary = boundary else {
                throw EmailParsingError.missingBoundary
            }

            let parts = try parseMultipart(decodedBody, boundary: boundary)
            return .multipart(parts)
        } else {
            // Unknown content type - treat as text
            Logger.warning("Unknown content type: \(contentType)", category: logCategory)
            return .text(decodedBody)
        }
    }

    /// Decode body based on transfer encoding (base64, quoted-printable, etc.)
    /// - Parameters:
    ///   - body: Encoded body string
    ///   - encoding: Transfer encoding (base64, quoted-printable, 7bit, 8bit, binary)
    /// - Returns: Decoded body string
    private func decodeBody(_ body: String, encoding: String?) throws -> String {
        guard let encoding = encoding else {
            // No encoding - return as is
            return body
        }

        switch encoding {
        case "base64":
            // Decode base64
            let cleanedBody = body.replacingOccurrences(of: "\r\n", with: "")
            guard let data = Data(base64Encoded: cleanedBody),
                  let decoded = String(data: data, encoding: .utf8) else {
                throw EmailParsingError.base64DecodingFailed
            }
            return decoded

        case "quoted-printable":
            // Decode quoted-printable
            return try decodeQuotedPrintable(body)

        case "7bit", "8bit", "binary":
            // No decoding needed
            return body

        default:
            Logger.warning("Unknown transfer encoding: \(encoding)", category: logCategory)
            return body
        }
    }

    /// Decode quoted-printable encoding
    /// - Parameter text: Quoted-printable encoded text
    /// - Returns: Decoded text
    private func decodeQuotedPrintable(_ text: String) throws -> String {
        var result = ""
        var i = text.startIndex

        while i < text.endIndex {
            let char = text[i]

            if char == "=" {
                // Encoded character or soft line break
                let nextIndex = text.index(after: i)

                if nextIndex < text.endIndex {
                    let next = text[nextIndex]

                    if next == "\r" || next == "\n" {
                        // Soft line break - skip
                        i = text.index(after: nextIndex)
                        if i < text.endIndex && text[i] == "\n" {
                            i = text.index(after: i)
                        }
                        continue
                    } else {
                        // Hex encoded character
                        let secondIndex = text.index(after: nextIndex)
                        if secondIndex < text.endIndex {
                            let hexString = String(text[nextIndex...secondIndex])
                            if let value = UInt8(hexString, radix: 16) {
                                let scalar = Unicode.Scalar(value)
                                result.append(Character(scalar))
                                i = text.index(after: secondIndex)
                                continue
                            }
                        }
                    }
                }
            }

            result.append(char)
            i = text.index(after: i)
        }

        return result
    }

    // MARK: - Multipart Parsing

    /// Extract boundary from Content-Type header
    /// - Parameter contentType: Content-Type header value
    /// - Returns: Boundary string or nil
    private func extractBoundary(from contentType: String) -> String? {
        // Look for boundary="..." or boundary=...
        let pattern = "boundary=\"?([^\"\\s;]+)\"?"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: contentType, range: NSRange(contentType.startIndex..., in: contentType)),
              let boundaryRange = Range(match.range(at: 1), in: contentType) else {
            return nil
        }

        return String(contentType[boundaryRange])
    }

    /// Parse multipart body into parts
    /// - Parameters:
    ///   - body: Multipart body string
    ///   - boundary: Multipart boundary
    /// - Returns: Array of parsed parts
    private func parseMultipart(_ body: String, boundary: String) throws -> [EmailPart] {
        var parts: [EmailPart] = []

        // Split by boundary
        let delimiter = "--\(boundary)"
        let sections = body.components(separatedBy: delimiter)

        for section in sections {
            let trimmed = section.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty sections and end marker
            if trimmed.isEmpty || trimmed == "--" {
                continue
            }

            // Parse part (has headers + body)
            let partComponents = trimmed.components(separatedBy: "\r\n\r\n")
            guard partComponents.count >= 2 else {
                continue
            }

            let partHeaders = try parseHeaders(partComponents[0])
            let partBody = partComponents.dropFirst().joined(separator: "\r\n\r\n")

            let contentType = partHeaders["Content-Type"] ?? "text/plain"
            let parsedBody = try parseBody(partBody, contentType: contentType, headers: partHeaders)

            let part = EmailPart(
                headers: partHeaders,
                contentType: contentType,
                body: parsedBody
            )

            parts.append(part)
        }

        Logger.debug("Parsed \(parts.count) multipart sections", category: logCategory)

        return parts
    }

    // MARK: - Helper Methods

    /// Extract email address from header value (e.g., "John Doe <john@example.com>" → "john@example.com")
    /// - Parameter header: Header value
    /// - Returns: Email address or nil
    private func extractAddress(from header: String?) -> String? {
        guard let header = header else { return nil }

        // Look for <email@domain.com>
        if let startIndex = header.firstIndex(of: "<"),
           let endIndex = header.firstIndex(of: ">") {
            return String(header[header.index(after: startIndex)..<endIndex])
        }

        // No brackets - return trimmed value
        return header.trimmingCharacters(in: .whitespaces)
    }

    /// Extract multiple email addresses from header value
    /// - Parameter header: Header value (comma-separated addresses)
    /// - Returns: Array of email addresses
    private func extractAddresses(from header: String?) -> [String] {
        guard let header = header else { return [] }

        // Split by comma
        let parts = header.components(separatedBy: ",")

        return parts.compactMap { extractAddress(from: $0) }
    }

    /// Decode RFC 2047 encoded header (=?UTF-8?B?...?=)
    /// - Parameter header: Header value
    /// - Returns: Decoded header or original if not encoded
    private func decodeHeader(_ header: String?) -> String? {
        guard let header = header else { return nil }

        // Pattern: =?charset?encoding?encoded-text?=
        let pattern = "=\\?([^?]+)\\?([BQ])\\?([^?]+)\\?="
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return header
        }

        var result = header
        let matches = regex.matches(in: header, range: NSRange(header.startIndex..., in: header))

        for match in matches.reversed() {
            guard let matchRange = Range(match.range, in: header),
                  let encodingRange = Range(match.range(at: 2), in: header),
                  let textRange = Range(match.range(at: 3), in: header) else {
                continue
            }

            let encoding = String(header[encodingRange]).uppercased()
            let encodedText = String(header[textRange])

            var decoded: String?

            if encoding == "B" {
                // Base64
                if let data = Data(base64Encoded: encodedText) {
                    decoded = String(data: data, encoding: .utf8)
                }
            } else if encoding == "Q" {
                // Quoted-printable (with _ for space)
                let qpText = encodedText.replacingOccurrences(of: "_", with: " ")
                decoded = try? decodeQuotedPrintable(qpText)
            }

            if let decoded = decoded {
                result.replaceSubrange(matchRange, with: decoded)
            }
        }

        return result
    }

    /// Parse date from RFC 5322 date format
    /// - Parameter dateString: Date string
    /// - Returns: Parsed Date or nil
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }

        // RFC 5322 date format: "Thu, 21 Dec 2023 16:01:07 +0200"
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        return formatter.date(from: dateString)
    }

    // MARK: - Attachment Extraction

    /// Extract attachments from parsed email
    /// - Parameter email: Parsed email
    /// - Returns: Array of attachments
    func extractAttachments(from email: ParsedEmail) -> [EmailAttachment] {
        var attachments: [EmailAttachment] = []

        // Extract from multipart body
        if case .multipart(let parts) = email.body {
            for part in parts {
                if let attachment = extractAttachment(from: part) {
                    attachments.append(attachment)
                }

                // Recursively extract from nested multipart
                if case .multipart(let nestedParts) = part.body {
                    let nestedEmail = ParsedEmail(
                        headers: [:],
                        from: nil,
                        to: [],
                        cc: [],
                        subject: nil,
                        date: nil,
                        messageId: nil,
                        contentType: part.contentType,
                        body: .multipart(nestedParts)
                    )
                    attachments.append(contentsOf: extractAttachments(from: nestedEmail))
                }
            }
        }

        Logger.debug("Extracted \(attachments.count) attachments", category: logCategory)

        return attachments
    }

    /// Extract attachment from email part
    /// - Parameter part: Email part
    /// - Returns: EmailAttachment or nil if not an attachment
    private func extractAttachment(from part: EmailPart) -> EmailAttachment? {
        let contentDisposition = part.headers["Content-Disposition"]
        let contentType = part.contentType

        // Check if this is an attachment
        let isAttachment = contentDisposition?.lowercased().contains("attachment") ?? false
        let isInline = contentDisposition?.lowercased().contains("inline") ?? false

        // Skip text/html and text/plain parts that are not attachments
        if !isAttachment && !isInline {
            let contentTypeLower = contentType.lowercased()
            if contentTypeLower.contains("text/plain") || contentTypeLower.contains("text/html") {
                return nil
            }
        }

        // Extract filename
        var filename: String?

        // Try from Content-Disposition: attachment; filename="..."
        if let disposition = contentDisposition {
            filename = extractFilename(from: disposition)
        }

        // Try from Content-Type: type/subtype; name="..."
        if filename == nil {
            filename = extractFilename(from: contentType)
        }

        // Fallback filename
        if filename == nil {
            let ext = extractExtension(from: contentType)
            filename = "attachment\(ext)"
        }

        // Extract content
        var data: Data?

        switch part.body {
        case .text(let text):
            // Text attachment (e.g., .txt file)
            data = text.data(using: .utf8)

        case .html(let html):
            // HTML attachment
            data = html.data(using: .utf8)

        case .multipart:
            // Multipart is not an attachment itself
            return nil
        }

        guard let attachmentData = data else {
            Logger.warning("Failed to extract attachment data", category: logCategory)
            return nil
        }

        // Extract Content-ID for inline attachments
        let contentId = part.headers["Content-ID"]?.trimmingCharacters(in: CharacterSet(charactersIn: "<>"))

        return EmailAttachment(
            filename: filename ?? "attachment",
            contentType: contentType,
            data: attachmentData,
            isInline: isInline,
            contentId: contentId,
            size: attachmentData.count
        )
    }

    /// Extract filename from Content-Disposition or Content-Type header
    /// - Parameter header: Header value
    /// - Returns: Filename or nil
    private func extractFilename(from header: String) -> String? {
        // Pattern: filename="..." or filename*=UTF-8''...
        let patterns = [
            "filename\\*?=\"([^\"]+)\"",
            "filename\\*?=([^;\\s]+)",
            "name=\"([^\"]+)\"",
            "name=([^;\\s]+)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: header, range: NSRange(header.startIndex..., in: header)),
               let filenameRange = Range(match.range(at: 1), in: header) {

                var filename = String(header[filenameRange])

                // Decode RFC 2231 encoding (filename*=UTF-8''...)
                if filename.contains("''") {
                    let parts = filename.components(separatedBy: "''")
                    if parts.count >= 2 {
                        filename = parts[1].removingPercentEncoding ?? filename
                    }
                }

                return filename
            }
        }

        return nil
    }

    /// Extract file extension from Content-Type
    /// - Parameter contentType: Content-Type header value
    /// - Returns: File extension with dot (e.g., ".pdf")
    private func extractExtension(from contentType: String) -> String {
        let typeLower = contentType.lowercased()

        // Common mappings
        if typeLower.contains("pdf") { return ".pdf" }
        if typeLower.contains("jpeg") || typeLower.contains("jpg") { return ".jpg" }
        if typeLower.contains("png") { return ".png" }
        if typeLower.contains("gif") { return ".gif" }
        if typeLower.contains("zip") { return ".zip" }
        if typeLower.contains("doc") { return ".doc" }
        if typeLower.contains("xls") { return ".xls" }
        if typeLower.contains("text/plain") { return ".txt" }
        if typeLower.contains("text/html") { return ".html" }

        return ".bin"
    }
}

// MARK: - Parsed Email

/// Represents a parsed email message
struct ParsedEmail {
    /// All headers (raw)
    let headers: [String: String]

    /// From address
    let from: String?

    /// To addresses
    let to: [String]

    /// CC addresses
    let cc: [String]

    /// Subject (decoded)
    let subject: String?

    /// Date
    let date: Date?

    /// Message-ID
    let messageId: String?

    /// Content-Type
    let contentType: String

    /// Parsed body
    let body: EmailBody
}

// MARK: - Email Body

/// Represents email body (can be text, HTML, or multipart)
enum EmailBody {
    case text(String)
    case html(String)
    case multipart([EmailPart])
}

// MARK: - Email Part

/// Represents a MIME part in multipart message
struct EmailPart {
    /// Part headers
    let headers: [String: String]

    /// Content-Type
    let contentType: String

    /// Part body
    let body: EmailBody
}

// MARK: - Email Attachment

/// Represents an email attachment
struct EmailAttachment {
    /// Filename
    let filename: String

    /// Content-Type (MIME type)
    let contentType: String

    /// Attachment data
    let data: Data

    /// Is this an inline attachment (embedded in HTML)
    let isInline: Bool

    /// Content-ID for inline attachments
    let contentId: String?

    /// Size in bytes
    let size: Int
}

// MARK: - Email Parsing Error

/// Errors that can occur during email parsing
enum EmailParsingError: Error, LocalizedError {
    case invalidEncoding
    case invalidFormat
    case missingBoundary
    case base64DecodingFailed
    case quotedPrintableDecodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            return "Failed to decode email data - invalid encoding"
        case .invalidFormat:
            return "Invalid email format - missing headers or body"
        case .missingBoundary:
            return "Multipart message missing boundary"
        case .base64DecodingFailed:
            return "Failed to decode base64 content"
        case .quotedPrintableDecodingFailed:
            return "Failed to decode quoted-printable content"
        }
    }
}
