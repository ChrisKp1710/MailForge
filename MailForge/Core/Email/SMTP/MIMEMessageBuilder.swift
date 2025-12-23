import Foundation

// MARK: - MIME Message Builder

/// Builds MIME-compliant email messages with support for HTML, multipart, and attachments
final class MIMEMessageBuilder {

    // MARK: - Properties

    /// Email sender
    private var from: String

    /// Email recipients
    private var to: [String]

    /// Email subject
    private var subject: String

    /// CC recipients
    private var cc: [String] = []

    /// BCC recipients
    private var bcc: [String] = []

    /// Reply-To address
    private var replyTo: String?

    /// Plain text body
    private var textBody: String?

    /// HTML body
    private var htmlBody: String?

    /// Attachments
    private var attachments: [MIMEAttachment] = []

    /// Custom headers
    private var customHeaders: [String: String] = [:]

    // MARK: - Initialization

    /// Initialize MIME message builder
    /// - Parameters:
    ///   - from: Sender email address
    ///   - to: Recipient email addresses
    ///   - subject: Email subject
    init(from: String, to: [String], subject: String) {
        self.from = from
        self.to = to
        self.subject = subject
    }

    // MARK: - Builder Methods

    /// Set CC recipients
    func cc(_ addresses: [String]) -> MIMEMessageBuilder {
        self.cc = addresses
        return self
    }

    /// Set BCC recipients
    func bcc(_ addresses: [String]) -> MIMEMessageBuilder {
        self.bcc = addresses
        return self
    }

    /// Set Reply-To address
    func replyTo(_ address: String) -> MIMEMessageBuilder {
        self.replyTo = address
        return self
    }

    /// Set plain text body
    func textBody(_ text: String) -> MIMEMessageBuilder {
        self.textBody = text
        return self
    }

    /// Set HTML body
    func htmlBody(_ html: String) -> MIMEMessageBuilder {
        self.htmlBody = html
        return self
    }

    /// Add attachment
    func addAttachment(_ attachment: MIMEAttachment) -> MIMEMessageBuilder {
        self.attachments.append(attachment)
        return self
    }

    /// Add custom header
    func addHeader(name: String, value: String) -> MIMEMessageBuilder {
        self.customHeaders[name] = value
        return self
    }

    // MARK: - Accessors

    /// Get sender address
    func getFrom() -> String {
        return from
    }

    /// Get all recipients (to + cc + bcc)
    func getAllRecipients() -> [String] {
        return to + cc + bcc
    }

    // MARK: - Build

    /// Build the complete MIME message
    /// - Returns: MIME-formatted email string
    func build() -> String {
        var message = ""

        // Add standard headers
        message += buildHeaders()

        // Determine content type and build body
        if !attachments.isEmpty {
            // Has attachments - use multipart/mixed
            message += buildMultipartMixed()
        } else if textBody != nil && htmlBody != nil {
            // Both text and HTML - use multipart/alternative
            message += buildMultipartAlternative()
        } else if htmlBody != nil {
            // HTML only
            message += buildHTMLBody()
        } else {
            // Plain text only
            message += buildTextBody()
        }

        return message
    }

    // MARK: - Header Building

    /// Build email headers
    private func buildHeaders() -> String {
        var headers = ""

        // From
        headers += "From: <\(from)>\r\n"

        // To
        headers += "To: \(to.map { "<\($0)>" }.joined(separator: ", "))\r\n"

        // CC
        if !cc.isEmpty {
            headers += "Cc: \(cc.map { "<\($0)>" }.joined(separator: ", "))\r\n"
        }

        // BCC
        if !bcc.isEmpty {
            headers += "Bcc: \(bcc.map { "<\($0)>" }.joined(separator: ", "))\r\n"
        }

        // Reply-To
        if let replyTo = replyTo {
            headers += "Reply-To: <\(replyTo)>\r\n"
        }

        // Subject
        headers += "Subject: \(encodeHeaderValue(subject))\r\n"

        // Date
        headers += "Date: \(formatDate(Date()))\r\n"

        // Message-ID
        headers += "Message-ID: <\(generateMessageID())>\r\n"

        // MIME-Version
        headers += "MIME-Version: 1.0\r\n"

        // Custom headers
        for (name, value) in customHeaders {
            headers += "\(name): \(value)\r\n"
        }

        return headers
    }

    // MARK: - Body Building

    /// Build plain text body
    private func buildTextBody() -> String {
        var body = ""
        body += "Content-Type: text/plain; charset=utf-8\r\n"
        body += "Content-Transfer-Encoding: 8bit\r\n"
        body += "\r\n"
        body += textBody ?? ""
        return body
    }

    /// Build HTML body
    private func buildHTMLBody() -> String {
        var body = ""
        body += "Content-Type: text/html; charset=utf-8\r\n"
        body += "Content-Transfer-Encoding: 8bit\r\n"
        body += "\r\n"
        body += htmlBody ?? ""
        return body
    }

    /// Build multipart/alternative (text + HTML)
    private func buildMultipartAlternative() -> String {
        let boundary = generateBoundary()
        var body = ""

        // Content-Type header
        body += "Content-Type: multipart/alternative; boundary=\"\(boundary)\"\r\n"
        body += "\r\n"

        // Preamble
        body += "This is a multi-part message in MIME format.\r\n"
        body += "\r\n"

        // Plain text part
        if let textBody = textBody {
            body += "--\(boundary)\r\n"
            body += "Content-Type: text/plain; charset=utf-8\r\n"
            body += "Content-Transfer-Encoding: 8bit\r\n"
            body += "\r\n"
            body += textBody
            body += "\r\n"
        }

        // HTML part
        if let htmlBody = htmlBody {
            body += "--\(boundary)\r\n"
            body += "Content-Type: text/html; charset=utf-8\r\n"
            body += "Content-Transfer-Encoding: 8bit\r\n"
            body += "\r\n"
            body += htmlBody
            body += "\r\n"
        }

        // End boundary
        body += "--\(boundary)--\r\n"

        return body
    }

    /// Build multipart/mixed (for attachments)
    private func buildMultipartMixed() -> String {
        let mixedBoundary = generateBoundary()
        var body = ""

        // Content-Type header
        body += "Content-Type: multipart/mixed; boundary=\"\(mixedBoundary)\"\r\n"
        body += "\r\n"

        // Preamble
        body += "This is a multi-part message in MIME format.\r\n"
        body += "\r\n"

        // Content part (either multipart/alternative or single part)
        body += "--\(mixedBoundary)\r\n"

        if textBody != nil && htmlBody != nil {
            // Both text and HTML - nested multipart/alternative
            let altBoundary = generateBoundary()
            body += "Content-Type: multipart/alternative; boundary=\"\(altBoundary)\"\r\n"
            body += "\r\n"

            // Plain text
            if let textBody = textBody {
                body += "--\(altBoundary)\r\n"
                body += "Content-Type: text/plain; charset=utf-8\r\n"
                body += "Content-Transfer-Encoding: 8bit\r\n"
                body += "\r\n"
                body += textBody
                body += "\r\n"
            }

            // HTML
            if let htmlBody = htmlBody {
                body += "--\(altBoundary)\r\n"
                body += "Content-Type: text/html; charset=utf-8\r\n"
                body += "Content-Transfer-Encoding: 8bit\r\n"
                body += "\r\n"
                body += htmlBody
                body += "\r\n"
            }

            body += "--\(altBoundary)--\r\n"

        } else if let htmlBody = htmlBody {
            // HTML only
            body += "Content-Type: text/html; charset=utf-8\r\n"
            body += "Content-Transfer-Encoding: 8bit\r\n"
            body += "\r\n"
            body += htmlBody
            body += "\r\n"

        } else if let textBody = textBody {
            // Plain text only
            body += "Content-Type: text/plain; charset=utf-8\r\n"
            body += "Content-Transfer-Encoding: 8bit\r\n"
            body += "\r\n"
            body += textBody
            body += "\r\n"
        }

        // Attachments
        for attachment in attachments {
            body += "--\(mixedBoundary)\r\n"
            body += attachment.buildMIMEPart()
        }

        // End boundary
        body += "--\(mixedBoundary)--\r\n"

        return body
    }

    // MARK: - Helper Methods

    /// Generate MIME boundary string
    private func generateBoundary() -> String {
        let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return "----=_Part_\(uuid)"
    }

    /// Generate unique Message-ID
    private func generateMessageID() -> String {
        let uuid = UUID().uuidString
        let domain = from.components(separatedBy: "@").last ?? "localhost"
        return "\(uuid)@\(domain)"
    }

    /// Format date for email header (RFC 5322)
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    /// Encode header value (RFC 2047 for non-ASCII)
    private func encodeHeaderValue(_ value: String) -> String {
        // Check if value contains non-ASCII characters
        if value.canBeConverted(to: .ascii) {
            return value
        }

        // Use RFC 2047 encoding for non-ASCII
        guard let data = value.data(using: .utf8) else {
            return value
        }

        let base64 = data.base64EncodedString()
        return "=?UTF-8?B?\(base64)?="
    }
}

// MARK: - MIME Attachment

/// Represents a MIME attachment
struct MIMEAttachment {

    /// Attachment filename
    let filename: String

    /// MIME content type (e.g., "application/pdf", "image/png")
    let contentType: String

    /// Attachment data
    let data: Data

    /// Whether this is an inline attachment (embedded in HTML)
    let isInline: Bool

    /// Content-ID for inline attachments
    let contentID: String?

    /// Initialize attachment
    /// - Parameters:
    ///   - filename: Attachment filename
    ///   - contentType: MIME content type
    ///   - data: Attachment data
    ///   - isInline: Whether attachment is inline (default: false)
    ///   - contentID: Content-ID for inline attachments (optional)
    init(
        filename: String,
        contentType: String,
        data: Data,
        isInline: Bool = false,
        contentID: String? = nil
    ) {
        self.filename = filename
        self.contentType = contentType
        self.data = data
        self.isInline = isInline
        self.contentID = contentID
    }

    /// Initialize attachment from file path
    /// - Parameters:
    ///   - fileURL: File URL to attach
    ///   - isInline: Whether attachment is inline (default: false)
    ///   - contentID: Content-ID for inline attachments (optional)
    /// - Throws: Error if file cannot be read
    init(fileURL: URL, isInline: Bool = false, contentID: String? = nil) throws {
        let data = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent
        let contentType = MIMEAttachment.detectContentType(from: filename)

        self.init(
            filename: filename,
            contentType: contentType,
            data: data,
            isInline: isInline,
            contentID: contentID
        )
    }

    /// Initialize attachment from file path string
    /// - Parameters:
    ///   - filePath: File path to attach
    ///   - isInline: Whether attachment is inline (default: false)
    ///   - contentID: Content-ID for inline attachments (optional)
    /// - Throws: Error if file cannot be read
    init(filePath: String, isInline: Bool = false, contentID: String? = nil) throws {
        try self.init(fileURL: URL(fileURLWithPath: filePath), isInline: isInline, contentID: contentID)
    }

    /// Build MIME part for this attachment
    func buildMIMEPart() -> String {
        var part = ""

        // Content-Type
        part += "Content-Type: \(contentType); name=\"\(filename)\"\r\n"

        // Content-Transfer-Encoding (always base64 for attachments)
        part += "Content-Transfer-Encoding: base64\r\n"

        // Content-Disposition
        if isInline {
            part += "Content-Disposition: inline; filename=\"\(filename)\"\r\n"
            if let contentID = contentID {
                part += "Content-ID: <\(contentID)>\r\n"
            }
        } else {
            part += "Content-Disposition: attachment; filename=\"\(filename)\"\r\n"
        }

        part += "\r\n"

        // Encode data as base64 (split into 76-character lines per RFC 2045)
        let base64 = data.base64EncodedString()
        let lines = splitIntoLines(base64, lineLength: 76)
        part += lines.joined(separator: "\r\n")
        part += "\r\n"

        return part
    }

    /// Split string into fixed-length lines
    private func splitIntoLines(_ string: String, lineLength: Int) -> [String] {
        var lines: [String] = []
        var currentIndex = string.startIndex

        while currentIndex < string.endIndex {
            let endIndex = string.index(
                currentIndex,
                offsetBy: lineLength,
                limitedBy: string.endIndex
            ) ?? string.endIndex

            lines.append(String(string[currentIndex..<endIndex]))
            currentIndex = endIndex
        }

        return lines
    }
}

// MARK: - Content Type Detection

extension MIMEAttachment {

    /// Detect MIME content type from file extension
    /// - Parameter filename: Filename with extension
    /// - Returns: MIME content type
    static func detectContentType(from filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()

        switch ext {
        // Images
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "bmp": return "image/bmp"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"

        // Documents
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt": return "application/vnd.ms-powerpoint"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "txt": return "text/plain"
        case "rtf": return "application/rtf"

        // Archives
        case "zip": return "application/zip"
        case "rar": return "application/x-rar-compressed"
        case "tar": return "application/x-tar"
        case "gz": return "application/gzip"
        case "7z": return "application/x-7z-compressed"

        // Audio
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "ogg": return "audio/ogg"
        case "m4a": return "audio/mp4"

        // Video
        case "mp4": return "video/mp4"
        case "avi": return "video/x-msvideo"
        case "mov": return "video/quicktime"
        case "wmv": return "video/x-ms-wmv"

        // Other
        case "json": return "application/json"
        case "xml": return "application/xml"
        case "html", "htm": return "text/html"
        case "css": return "text/css"
        case "js": return "application/javascript"

        default: return "application/octet-stream"
        }
    }
}
