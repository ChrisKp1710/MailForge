import Foundation
import SwiftData

/// Email account model - Supports IMAP, PEC, Gmail, Outlook
@Model
final class Account {

    // MARK: - Properties

    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Account display name (e.g., "Work", "Personal")
    var name: String

    /// Email address
    var emailAddress: String

    /// Account type
    var type: AccountType

    /// IMAP configuration
    var imapHost: String
    var imapPort: Int
    var imapUseTLS: Bool

    /// SMTP configuration
    var smtpHost: String
    var smtpPort: Int
    var smtpUseTLS: Bool

    /// Credentials stored in Keychain (referenced by account ID)
    /// We don't store passwords in SwiftData for security
    var keychainIdentifier: String

    /// Account settings
    var isActive: Bool
    var syncEnabled: Bool
    var lastSyncDate: Date?

    /// Relationships
    @Relationship(deleteRule: .cascade) var folders: [Folder]

    /// Creation date
    var createdAt: Date

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        emailAddress: String,
        type: AccountType,
        imapHost: String,
        imapPort: Int = 993,
        imapUseTLS: Bool = true,
        smtpHost: String,
        smtpPort: Int = 587,
        smtpUseTLS: Bool = true,
        isActive: Bool = true,
        syncEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.emailAddress = emailAddress
        self.type = type
        self.imapHost = imapHost
        self.imapPort = imapPort
        self.imapUseTLS = imapUseTLS
        self.smtpHost = smtpHost
        self.smtpPort = smtpPort
        self.smtpUseTLS = smtpUseTLS
        self.keychainIdentifier = "mailforge.account.\(id.uuidString)"
        self.isActive = isActive
        self.syncEnabled = syncEnabled
        self.lastSyncDate = nil
        self.folders = []
        self.createdAt = Date()
    }
}

// MARK: - Account Type

enum AccountType: String, Codable {
    case imap = "IMAP"
    case pec = "PEC"
    case gmail = "Gmail"
    case outlook = "Outlook"
    case exchange = "Exchange"

    var displayName: String {
        switch self {
        case .imap: return "IMAP/SMTP"
        case .pec: return "PEC (Certificata)"
        case .gmail: return "Gmail"
        case .outlook: return "Outlook"
        case .exchange: return "Exchange"
        }
    }
}

// MARK: - Presets

extension Account {

    /// Create PEC IONOS account preset
    static func createPECIONOS(name: String, emailAddress: String) -> Account {
        return Account(
            name: name,
            emailAddress: emailAddress,
            type: .pec,
            imapHost: "imap.ionos.it",
            imapPort: 993,
            imapUseTLS: true,
            smtpHost: "smtp.ionos.it",
            smtpPort: 465,
            smtpUseTLS: true
        )
    }

    /// Create Gmail account preset
    static func createGmail(name: String, emailAddress: String) -> Account {
        return Account(
            name: name,
            emailAddress: emailAddress,
            type: .gmail,
            imapHost: "imap.gmail.com",
            imapPort: 993,
            imapUseTLS: true,
            smtpHost: "smtp.gmail.com",
            smtpPort: 587,
            smtpUseTLS: true
        )
    }

    /// Create Outlook account preset
    static func createOutlook(name: String, emailAddress: String) -> Account {
        return Account(
            name: name,
            emailAddress: emailAddress,
            type: .outlook,
            imapHost: "outlook.office365.com",
            imapPort: 993,
            imapUseTLS: true,
            smtpHost: "smtp.office365.com",
            smtpPort: 587,
            smtpUseTLS: true
        )
    }
}
