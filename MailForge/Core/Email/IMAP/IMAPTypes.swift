import Foundation

// MARK: - IMAP Folder

/// Represents an IMAP folder/mailbox
struct IMAPFolder {
    /// Folder name
    let name: String

    /// Full path of the folder
    let path: String

    /// Hierarchy delimiter (e.g., "/" or ".")
    let delimiter: String?

    /// Folder attributes/flags
    let attributes: [String]

    /// Computed: Is this folder selectable?
    var isSelectable: Bool {
        !attributes.contains("\\Noselect")
    }

    /// Computed: Is this the INBOX?
    var isInbox: Bool {
        name.uppercased() == "INBOX"
    }

    /// Computed: Is this a special folder?
    var specialType: FolderType? {
        if isInbox {
            return .inbox
        }

        // Check for special-use attributes (RFC 6154)
        if attributes.contains("\\Sent") {
            return .sent
        } else if attributes.contains("\\Drafts") {
            return .drafts
        } else if attributes.contains("\\Trash") {
            return .trash
        } else if attributes.contains("\\Junk") || attributes.contains("\\Spam") {
            return .spam
        } else if attributes.contains("\\Archive") {
            return .archive
        } else if attributes.contains("\\Flagged") {
            return .starred
        }

        return nil
    }
}

// MARK: - IMAP Folder Info

/// Information about a selected IMAP folder
struct IMAPFolderInfo {
    /// Folder name
    var name: String

    /// Number of messages in folder
    let exists: Int

    /// Number of recent messages
    let recent: Int

    /// UID of first unseen message (optional)
    let unseen: Int?

    /// Available flags
    let flags: [String]

    /// Permanent flags (can be stored)
    let permanentFlags: [String]

    /// UIDVALIDITY (changes when folder is recreated)
    var uidValidity: UInt32?

    /// UIDNEXT (next UID to be assigned)
    var uidNext: UInt32?

    /// Is folder read-only?
    var isReadOnly: Bool = false
}

// MARK: - IMAP Message Flags

/// Standard IMAP message flags
enum IMAPMessageFlag: String {
    case seen = "\\Seen"
    case answered = "\\Answered"
    case flagged = "\\Flagged"
    case deleted = "\\Deleted"
    case draft = "\\Draft"
    case recent = "\\Recent"

    /// Custom flag (not standard)
    case custom(String)

    var rawValue: String {
        switch self {
        case .seen: return "\\Seen"
        case .answered: return "\\Answered"
        case .flagged: return "\\Flagged"
        case .deleted: return "\\Deleted"
        case .draft: return "\\Draft"
        case .recent: return "\\Recent"
        case .custom(let value): return value
        }
    }
}

// MARK: - IMAP Message Data

/// Data fetched for an IMAP message
struct IMAPMessageData {
    /// Message UID
    let uid: Int64

    /// Message sequence number
    let sequenceNumber: Int?

    /// Message flags
    var flags: [String] = []

    /// Message size in bytes
    var size: Int64?

    /// Message envelope (headers summary)
    var envelope: IMAPEnvelope?

    /// Message body structure
    var bodyStructure: IMAPBodyStructure?

    /// Raw RFC822 message data
    var rfc822: Data?

    /// Internal date (when message was received by server)
    var internalDate: Date?
}

// MARK: - IMAP Envelope

/// Envelope information (summary of headers)
struct IMAPEnvelope {
    let date: Date?
    let subject: String?
    let from: [IMAPAddress]
    let sender: [IMAPAddress]
    let replyTo: [IMAPAddress]
    let to: [IMAPAddress]
    let cc: [IMAPAddress]
    let bcc: [IMAPAddress]
    let inReplyTo: String?
    let messageId: String?
}

// MARK: - IMAP Address

/// Email address information
struct IMAPAddress {
    let name: String?
    let mailbox: String  // Local part (before @)
    let host: String     // Domain part (after @)

    /// Full email address
    var email: String {
        "\(mailbox)@\(host)"
    }

    /// Display name or email
    var displayName: String {
        name ?? email
    }
}

// MARK: - IMAP Body Structure

/// Message body structure (for multipart messages)
indirect enum IMAPBodyStructure {
    /// Single part (text/plain, text/html, etc.)
    case singlePart(
        type: String,
        subtype: String,
        parameters: [String: String],
        contentId: String?,
        description: String?,
        encoding: String,
        size: Int
    )

    /// Multipart (multipart/mixed, multipart/alternative, etc.)
    case multiPart(
        parts: [IMAPBodyStructure],
        subtype: String,
        parameters: [String: String]
    )

    /// Is this a text part?
    var isText: Bool {
        if case .singlePart(let type, _, _, _, _, _, _) = self {
            return type.lowercased() == "text"
        }
        return false
    }

    /// Is this an attachment?
    var isAttachment: Bool {
        if case .singlePart(let type, _, let params, _, _, _, _) = self {
            // Check if it has a filename in parameters
            return params["name"] != nil || params["filename"] != nil || type.lowercased() == "application"
        }
        return false
    }
}

// MARK: - IMAP Search Criteria

/// Search criteria for IMAP SEARCH command
enum IMAPSearchCriteria {
    case all
    case answered
    case deleted
    case draft
    case flagged
    case new
    case old
    case recent
    case seen
    case unanswered
    case undeleted
    case undraft
    case unflagged
    case unseen

    // Date-based
    case before(Date)
    case on(Date)
    case since(Date)
    case sentBefore(Date)
    case sentOn(Date)
    case sentSince(Date)

    // Size-based
    case larger(Int)
    case smaller(Int)

    // Header-based
    case from(String)
    case to(String)
    case cc(String)
    case bcc(String)
    case subject(String)
    case body(String)
    case text(String)
    case header(String, String)

    // UID-based
    case uid(String) // Can be a range like "1:100" or "1,3,5"

    // Logical operators
    case and([IMAPSearchCriteria])
    case or([IMAPSearchCriteria])
    case not(IMAPSearchCriteria)

    /// Convert to IMAP search string
    func toIMAPString() -> String {
        switch self {
        case .all: return "ALL"
        case .answered: return "ANSWERED"
        case .deleted: return "DELETED"
        case .draft: return "DRAFT"
        case .flagged: return "FLAGGED"
        case .new: return "NEW"
        case .old: return "OLD"
        case .recent: return "RECENT"
        case .seen: return "SEEN"
        case .unanswered: return "UNANSWERED"
        case .undeleted: return "UNDELETED"
        case .undraft: return "UNDRAFT"
        case .unflagged: return "UNFLAGGED"
        case .unseen: return "UNSEEN"

        case .before(let date): return "BEFORE \(formatDate(date))"
        case .on(let date): return "ON \(formatDate(date))"
        case .since(let date): return "SINCE \(formatDate(date))"
        case .sentBefore(let date): return "SENTBEFORE \(formatDate(date))"
        case .sentOn(let date): return "SENTON \(formatDate(date))"
        case .sentSince(let date): return "SENTSINCE \(formatDate(date))"

        case .larger(let size): return "LARGER \(size)"
        case .smaller(let size): return "SMALLER \(size)"

        case .from(let value): return "FROM \"\(value)\""
        case .to(let value): return "TO \"\(value)\""
        case .cc(let value): return "CC \"\(value)\""
        case .bcc(let value): return "BCC \"\(value)\""
        case .subject(let value): return "SUBJECT \"\(value)\""
        case .body(let value): return "BODY \"\(value)\""
        case .text(let value): return "TEXT \"\(value)\""
        case .header(let field, let value): return "HEADER \(field) \"\(value)\""

        case .uid(let range): return "UID \(range)"

        case .and(let criteria):
            return criteria.map { $0.toIMAPString() }.joined(separator: " ")
        case .or(let criteria):
            return "OR " + criteria.map { $0.toIMAPString() }.joined(separator: " ")
        case .not(let criterion):
            return "NOT \(criterion.toIMAPString())"
        }
    }

    /// Format date for IMAP (DD-MMM-YYYY)
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
