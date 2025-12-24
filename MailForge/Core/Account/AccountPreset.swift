import Foundation

// MARK: - Account Preset

/// Predefined account configurations for common email providers
struct AccountPreset {

    // MARK: - Properties

    /// Provider name
    let name: String

    /// Provider logo/icon (SF Symbol)
    let icon: String

    /// IMAP server configuration
    let imapHost: String
    let imapPort: Int
    let imapUseTLS: Bool

    /// SMTP server configuration
    let smtpHost: String
    let smtpPort: Int
    let smtpUseTLS: Bool

    /// Type of account
    let type: AccountType

    /// Username format (e.g., "email" or "username")
    let usernameFormat: UsernameFormat

    /// Additional notes for setup
    let notes: String?

    // MARK: - Common Presets

    /// Gmail / Google Workspace
    static let gmail = AccountPreset(
        name: "Gmail",
        icon: "envelope.fill",
        imapHost: "imap.gmail.com",
        imapPort: 993,
        imapUseTLS: true,
        smtpHost: "smtp.gmail.com",
        smtpPort: 587,
        smtpUseTLS: true,
        type: .imap,
        usernameFormat: .email,
        notes: "Per Gmail, devi usare una 'App Password' invece della password normale. Vai su Google Account → Security → 2-Step Verification → App passwords."
    )

    /// IONOS PEC (Posta Elettronica Certificata Italiana)
    static let ionosPEC = AccountPreset(
        name: "IONOS PEC",
        icon: "checkmark.seal.fill",
        imapHost: "imap.ionos.it",
        imapPort: 993,
        imapUseTLS: true,
        smtpHost: "smtp.ionos.it",
        smtpPort: 465,
        smtpUseTLS: true,
        type: .pec,
        usernameFormat: .email,
        notes: "Per PEC IONOS, usa l'indirizzo email completo come username."
    )

    /// Outlook / Microsoft 365
    static let outlook = AccountPreset(
        name: "Outlook",
        icon: "envelope.badge.fill",
        imapHost: "outlook.office365.com",
        imapPort: 993,
        imapUseTLS: true,
        smtpHost: "smtp.office365.com",
        smtpPort: 587,
        smtpUseTLS: true,
        type: .imap,
        usernameFormat: .email,
        notes: "Per Outlook, usa l'indirizzo email completo come username."
    )

    /// iCloud Mail
    static let icloud = AccountPreset(
        name: "iCloud Mail",
        icon: "cloud.fill",
        imapHost: "imap.mail.me.com",
        imapPort: 993,
        imapUseTLS: true,
        smtpHost: "smtp.mail.me.com",
        smtpPort: 587,
        smtpUseTLS: true,
        type: .imap,
        usernameFormat: .email,
        notes: "Per iCloud Mail, devi generare una 'App-Specific Password' su appleid.apple.com."
    )

    /// Yahoo Mail
    static let yahoo = AccountPreset(
        name: "Yahoo Mail",
        icon: "envelope.fill",
        imapHost: "imap.mail.yahoo.com",
        imapPort: 993,
        imapUseTLS: true,
        smtpHost: "smtp.mail.yahoo.com",
        smtpPort: 465,
        smtpUseTLS: true,
        type: .imap,
        usernameFormat: .email,
        notes: "Per Yahoo, devi generare una 'App Password' nelle impostazioni account."
    )

    /// ProtonMail Bridge
    static let protonmail = AccountPreset(
        name: "ProtonMail Bridge",
        icon: "lock.shield.fill",
        imapHost: "127.0.0.1",
        imapPort: 1143,
        imapUseTLS: false,
        smtpHost: "127.0.0.1",
        smtpPort: 1025,
        smtpUseTLS: false,
        type: .imap,
        usernameFormat: .email,
        notes: "ProtonMail richiede il ProtonMail Bridge installato e in esecuzione. Usa le credenziali fornite dal Bridge."
    )

    /// Generic IMAP/SMTP (manual configuration)
    static let generic = AccountPreset(
        name: "Altro Provider",
        icon: "gearshape.fill",
        imapHost: "",
        imapPort: 993,
        imapUseTLS: true,
        smtpHost: "",
        smtpPort: 587,
        smtpUseTLS: true,
        type: .imap,
        usernameFormat: .email,
        notes: "Configura manualmente i server IMAP e SMTP. Contatta il tuo provider per i dettagli."
    )

    // MARK: - All Presets

    /// All available presets
    static let allPresets: [AccountPreset] = [
        .gmail,
        .ionosPEC,
        .outlook,
        .icloud,
        .yahoo,
        .protonmail,
        .generic
    ]

    // MARK: - Helpers

    /// Get preset by name
    /// - Parameter name: Preset name
    /// - Returns: Preset or nil
    static func preset(named name: String) -> AccountPreset? {
        return allPresets.first { $0.name.lowercased() == name.lowercased() }
    }

    /// Detect preset from email domain
    /// - Parameter email: Email address
    /// - Returns: Best matching preset or generic
    static func detectPreset(from email: String) -> AccountPreset {
        let domain = email.components(separatedBy: "@").last?.lowercased() ?? ""

        switch domain {
        case "gmail.com", "googlemail.com":
            return .gmail

        case let d where d.hasSuffix(".pec.it") || d.contains("pec"):
            // Check if it's IONOS PEC
            if d.contains("ionos") {
                return .ionosPEC
            }
            // Generic PEC - use IONOS preset as template
            return .ionosPEC

        case "outlook.com", "hotmail.com", "live.com":
            return .outlook

        case "icloud.com", "me.com", "mac.com":
            return .icloud

        case "yahoo.com", "ymail.com":
            return .yahoo

        case "protonmail.com", "pm.me":
            return .protonmail

        default:
            return .generic
        }
    }
}

// MARK: - Username Format

/// Username format for authentication
enum UsernameFormat {
    /// Full email address (e.g., "user@domain.com")
    case email

    /// Just username part (e.g., "user")
    case username

    var description: String {
        switch self {
        case .email:
            return "Indirizzo email completo"
        case .username:
            return "Solo username (senza @domain)"
        }
    }
}

// MARK: - Account Type Extension

extension AccountType {
    /// Icon for account type
    var icon: String {
        switch self {
        case .imap:
            return "envelope.fill"
        case .pec:
            return "checkmark.seal.fill"
        case .gmail:
            return "envelope.badge.fill"
        case .outlook:
            return "envelope.badge.fill"
        }
    }

    /// Display name for account type
    var displayName: String {
        switch self {
        case .imap:
            return "IMAP"
        case .pec:
            return "PEC"
        case .gmail:
            return "Gmail"
        case .outlook:
            return "Outlook"
        }
    }
}
