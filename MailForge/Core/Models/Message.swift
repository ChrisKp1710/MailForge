import Foundation
import SwiftData

/// Email message model
@Model
final class Message {

    // MARK: - Properties

    /// Unique identifier (local)
    @Attribute(.unique) var id: UUID

    /// IMAP message ID (server-side unique ID)
    var messageID: String

    /// IMAP UID (unique per folder)
    var uid: Int64

    /// Email subject
    var subject: String

    /// Sender email address
    var from: String

    /// Sender display name (optional)
    var fromName: String?

    /// Recipients (To)
    var to: [String]

    /// CC recipients
    var cc: [String]

    /// BCC recipients (usually not available in IMAP)
    var bcc: [String]

    /// Email date
    var date: Date

    /// Message preview (first 150 chars of body)
    var preview: String

    /// Path to email body file (.eml)
    var bodyPath: String?

    /// Email body snippet (for search/preview without reading file)
    var bodySnippet: String?

    /// Flags
    var isRead: Bool
    var isStarred: Bool
    var isFlagged: Bool
    var isDraft: Bool

    /// Has attachments
    var hasAttachments: Bool

    /// Email size (bytes)
    var size: Int64

    /// Is PEC email
    var isPEC: Bool

    /// PEC metadata (if applicable)
    var pecType: PECType?
    var pecCertPath: String? // Path to daticert.xml

    /// Relationships
    @Relationship(inverse: \Folder.messages) var folder: Folder?
    @Relationship(deleteRule: .cascade) var attachments: [Attachment]

    /// Creation date (when fetched)
    var createdAt: Date

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        messageID: String,
        uid: Int64,
        subject: String,
        from: String,
        fromName: String? = nil,
        to: [String],
        cc: [String] = [],
        bcc: [String] = [],
        date: Date,
        preview: String = "",
        isRead: Bool = false,
        isStarred: Bool = false,
        isFlagged: Bool = false,
        isDraft: Bool = false,
        hasAttachments: Bool = false,
        size: Int64 = 0,
        isPEC: Bool = false
    ) {
        self.id = id
        self.messageID = messageID
        self.uid = uid
        self.subject = subject
        self.from = from
        self.fromName = fromName
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.date = date
        self.preview = preview
        self.bodyPath = nil
        self.bodySnippet = nil
        self.isRead = isRead
        self.isStarred = isStarred
        self.isFlagged = isFlagged
        self.isDraft = isDraft
        self.hasAttachments = hasAttachments
        self.size = size
        self.isPEC = isPEC
        self.pecType = nil
        self.pecCertPath = nil
        self.attachments = []
        self.createdAt = Date()
    }
}

// MARK: - PEC Type

enum PECType: String, Codable {
    case standard = "Standard"
    case receipt = "Ricevuta di Accettazione"
    case delivery = "Ricevuta di Consegna"
    case error = "Errore di Consegna"
    case anomaly = "Anomalia"

    var displayName: String {
        return rawValue
    }
}

// MARK: - Computed Properties

extension Message {

    /// Display name for sender
    var displayFrom: String {
        return fromName ?? from
    }

    /// Display recipients
    var displayTo: String {
        return to.joined(separator: ", ")
    }

    /// Is message recent (today or yesterday)
    var isRecent: Bool {
        let calendar = Calendar.current
        let now = Date()
        return calendar.isDateInToday(date) || calendar.isDateInYesterday(date)
    }

    /// Formatted date string
    var formattedDate: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Day name
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }

    /// Formatted size string
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Actions

extension Message {

    /// Mark as read
    func markAsRead() {
        isRead = true
    }

    /// Mark as unread
    func markAsUnread() {
        isRead = false
    }

    /// Toggle starred
    func toggleStarred() {
        isStarred.toggle()
    }

    /// Toggle flagged
    func toggleFlagged() {
        isFlagged.toggle()
    }
}
