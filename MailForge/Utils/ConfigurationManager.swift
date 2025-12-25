import Foundation

/// Configuration manager using UserDefaults for app settings
final class ConfigurationManager: @unchecked Sendable {

    // MARK: - Singleton

    nonisolated(unsafe) static let shared = ConfigurationManager()

    private init() {}

    // MARK: - UserDefaults Keys

    private enum Keys: String {
        // General Settings
        case isDarkModeEnabled
        case defaultEmailSignature
        case autoSaveIntervalSeconds

        // Email Settings
        case checkEmailIntervalMinutes
        case autoDownloadAttachments
        case maxAttachmentSizeMB
        case deleteEmailsOnServer
        case showEmailPreview
        case previewLineCount

        // Notification Settings
        case enableNotifications
        case notifyOnAllEmails
        case notifyOnlyImportant
        case playSoundOnNewEmail

        // Sync Settings
        case syncOnLaunch
        case syncInBackground
        case syncIntervalMinutes
        case maxSyncDays

        // PEC Settings
        case autoDetectPEC
        case showPECBadges
        case autoDownloadPECCertificates

        // Privacy Settings
        case blockRemoteImages
        case enableReadReceipts
        case enableTypingIndicators

        // Advanced Settings
        case enableDebugLogging
        case cacheEmailsOffline
        case maxCacheSizeMB

        // UI Settings
        case messageListDensity
        case showUnreadBadge
        case compactMode
        case sidebarWidth
    }

    // MARK: - General Settings

    var isDarkModeEnabled: Bool {
        get { getValue(for: .isDarkModeEnabled) ?? false }
        set { setValue(newValue, for: .isDarkModeEnabled) }
    }

    var defaultEmailSignature: String {
        get { getValue(for: .defaultEmailSignature) ?? "" }
        set { setValue(newValue, for: .defaultEmailSignature) }
    }

    var autoSaveIntervalSeconds: Int {
        get { getValue(for: .autoSaveIntervalSeconds) ?? 30 }
        set { setValue(newValue, for: .autoSaveIntervalSeconds) }
    }

    // MARK: - Email Settings

    var checkEmailIntervalMinutes: Int {
        get { getValue(for: .checkEmailIntervalMinutes) ?? 5 }
        set { setValue(newValue, for: .checkEmailIntervalMinutes) }
    }

    var autoDownloadAttachments: Bool {
        get { getValue(for: .autoDownloadAttachments) ?? false }
        set { setValue(newValue, for: .autoDownloadAttachments) }
    }

    var maxAttachmentSizeMB: Int {
        get { getValue(for: .maxAttachmentSizeMB) ?? 25 }
        set { setValue(newValue, for: .maxAttachmentSizeMB) }
    }

    var deleteEmailsOnServer: Bool {
        get { getValue(for: .deleteEmailsOnServer) ?? false }
        set { setValue(newValue, for: .deleteEmailsOnServer) }
    }

    var showEmailPreview: Bool {
        get { getValue(for: .showEmailPreview) ?? true }
        set { setValue(newValue, for: .showEmailPreview) }
    }

    var previewLineCount: Int {
        get { getValue(for: .previewLineCount) ?? 2 }
        set { setValue(newValue, for: .previewLineCount) }
    }

    // MARK: - Notification Settings

    var enableNotifications: Bool {
        get { getValue(for: .enableNotifications) ?? true }
        set { setValue(newValue, for: .enableNotifications) }
    }

    var notifyOnAllEmails: Bool {
        get { getValue(for: .notifyOnAllEmails) ?? true }
        set { setValue(newValue, for: .notifyOnAllEmails) }
    }

    var notifyOnlyImportant: Bool {
        get { getValue(for: .notifyOnlyImportant) ?? false }
        set { setValue(newValue, for: .notifyOnlyImportant) }
    }

    var playSoundOnNewEmail: Bool {
        get { getValue(for: .playSoundOnNewEmail) ?? true }
        set { setValue(newValue, for: .playSoundOnNewEmail) }
    }

    // MARK: - Sync Settings

    var syncOnLaunch: Bool {
        get { getValue(for: .syncOnLaunch) ?? true }
        set { setValue(newValue, for: .syncOnLaunch) }
    }

    var syncInBackground: Bool {
        get { getValue(for: .syncInBackground) ?? true }
        set { setValue(newValue, for: .syncInBackground) }
    }

    var syncIntervalMinutes: Int {
        get { getValue(for: .syncIntervalMinutes) ?? 15 }
        set { setValue(newValue, for: .syncIntervalMinutes) }
    }

    var maxSyncDays: Int {
        get { getValue(for: .maxSyncDays) ?? 30 }
        set { setValue(newValue, for: .maxSyncDays) }
    }

    // MARK: - PEC Settings

    var autoDetectPEC: Bool {
        get { getValue(for: .autoDetectPEC) ?? true }
        set { setValue(newValue, for: .autoDetectPEC) }
    }

    var showPECBadges: Bool {
        get { getValue(for: .showPECBadges) ?? true }
        set { setValue(newValue, for: .showPECBadges) }
    }

    var autoDownloadPECCertificates: Bool {
        get { getValue(for: .autoDownloadPECCertificates) ?? true }
        set { setValue(newValue, for: .autoDownloadPECCertificates) }
    }

    // MARK: - Privacy Settings

    var blockRemoteImages: Bool {
        get { getValue(for: .blockRemoteImages) ?? true }
        set { setValue(newValue, for: .blockRemoteImages) }
    }

    var enableReadReceipts: Bool {
        get { getValue(for: .enableReadReceipts) ?? false }
        set { setValue(newValue, for: .enableReadReceipts) }
    }

    var enableTypingIndicators: Bool {
        get { getValue(for: .enableTypingIndicators) ?? false }
        set { setValue(newValue, for: .enableTypingIndicators) }
    }

    // MARK: - Advanced Settings

    var enableDebugLogging: Bool {
        get { getValue(for: .enableDebugLogging) ?? false }
        set { setValue(newValue, for: .enableDebugLogging) }
    }

    var cacheEmailsOffline: Bool {
        get { getValue(for: .cacheEmailsOffline) ?? true }
        set { setValue(newValue, for: .cacheEmailsOffline) }
    }

    var maxCacheSizeMB: Int {
        get { getValue(for: .maxCacheSizeMB) ?? 500 }
        set { setValue(newValue, for: .maxCacheSizeMB) }
    }

    // MARK: - UI Settings

    var messageListDensity: MessageListDensity {
        get {
            if let rawValue: String = getValue(for: .messageListDensity),
               let density = MessageListDensity(rawValue: rawValue) {
                return density
            }
            return .comfortable
        }
        set { setValue(newValue.rawValue, for: .messageListDensity) }
    }

    var showUnreadBadge: Bool {
        get { getValue(for: .showUnreadBadge) ?? true }
        set { setValue(newValue, for: .showUnreadBadge) }
    }

    var compactMode: Bool {
        get { getValue(for: .compactMode) ?? false }
        set { setValue(newValue, for: .compactMode) }
    }

    var sidebarWidth: Double {
        get { getValue(for: .sidebarWidth) ?? 240.0 }
        set { setValue(newValue, for: .sidebarWidth) }
    }

    // MARK: - Generic Getters/Setters

    private func getValue<T>(for key: Keys) -> T? {
        return UserDefaults.standard.value(forKey: key.rawValue) as? T
    }

    private func setValue<T>(_ value: T, for key: Keys) {
        UserDefaults.standard.setValue(value, forKey: key.rawValue)
        Logger.debug("Configuration updated: \(key.rawValue) = \(value)", category: .app)
    }

    // MARK: - Reset Settings

    /// Reset all settings to defaults
    func resetToDefaults() {
        let domain = Bundle.main.bundleIdentifier ?? "com.mailforge.app"
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        Logger.info("Configuration reset to defaults", category: .app)
    }

    /// Reset specific category of settings
    func resetCategory(_ category: SettingsCategory) {
        switch category {
        case .general:
            isDarkModeEnabled = false
            defaultEmailSignature = ""
            autoSaveIntervalSeconds = 30

        case .email:
            checkEmailIntervalMinutes = 5
            autoDownloadAttachments = false
            maxAttachmentSizeMB = 25
            deleteEmailsOnServer = false
            showEmailPreview = true
            previewLineCount = 2

        case .notifications:
            enableNotifications = true
            notifyOnAllEmails = true
            notifyOnlyImportant = false
            playSoundOnNewEmail = true

        case .sync:
            syncOnLaunch = true
            syncInBackground = true
            syncIntervalMinutes = 15
            maxSyncDays = 30

        case .pec:
            autoDetectPEC = true
            showPECBadges = true
            autoDownloadPECCertificates = true

        case .privacy:
            blockRemoteImages = true
            enableReadReceipts = false
            enableTypingIndicators = false

        case .advanced:
            enableDebugLogging = false
            cacheEmailsOffline = true
            maxCacheSizeMB = 500

        case .ui:
            messageListDensity = .comfortable
            showUnreadBadge = true
            compactMode = false
            sidebarWidth = 240.0
        }

        Logger.info("Reset \(category.rawValue) settings to defaults", category: .app)
    }
}

// MARK: - Settings Categories

enum SettingsCategory: String {
    case general = "General"
    case email = "Email"
    case notifications = "Notifications"
    case sync = "Sync"
    case pec = "PEC"
    case privacy = "Privacy"
    case advanced = "Advanced"
    case ui = "UI"
}

// MARK: - Message List Density

enum MessageListDensity: String, Codable {
    case compact = "Compact"
    case comfortable = "Comfortable"
    case spacious = "Spacious"

    var rowHeight: Double {
        switch self {
        case .compact: return 48
        case .comfortable: return 64
        case .spacious: return 80
        }
    }
}

// MARK: - Usage Examples

/*
 // Get settings
 let config = ConfigurationManager.shared
 let interval = config.checkEmailIntervalMinutes
 let isDark = config.isDarkModeEnabled

 // Update settings
 config.enableNotifications = true
 config.maxAttachmentSizeMB = 50
 config.messageListDensity = .compact

 // Reset all settings
 config.resetToDefaults()

 // Reset specific category
 config.resetCategory(.email)
 */
