import Foundation
import SwiftData

/// Email folder model (Inbox, Sent, Drafts, Custom folders)
@Model
final class Folder {

    // MARK: - Properties

    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Folder name (e.g., "INBOX", "Sent", "Work")
    var name: String

    /// IMAP folder path (e.g., "INBOX", "Sent Items", "INBOX.Work")
    var path: String

    /// Folder type
    var type: FolderType

    /// Unread message count
    var unreadCount: Int

    /// Total message count
    var totalCount: Int

    /// Folder icon
    var iconName: String

    /// Display order
    var displayOrder: Int

    /// Relationships
    @Relationship(inverse: \Account.folders) var account: Account?
    @Relationship(deleteRule: .cascade) var messages: [Message]

    /// Creation date
    var createdAt: Date

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        type: FolderType,
        iconName: String? = nil,
        displayOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.type = type
        self.unreadCount = 0
        self.totalCount = 0
        self.iconName = iconName ?? type.defaultIconName
        self.displayOrder = displayOrder
        self.messages = []
        self.createdAt = Date()
    }
}

// MARK: - Folder Type

enum FolderType: String, Codable {
    case inbox = "Inbox"
    case sent = "Sent"
    case drafts = "Drafts"
    case trash = "Trash"
    case spam = "Spam"
    case archive = "Archive"
    case starred = "Starred"
    case custom = "Custom"

    var defaultIconName: String {
        switch self {
        case .inbox: return "tray.fill"
        case .sent: return "paperplane.fill"
        case .drafts: return "doc.text.fill"
        case .trash: return "trash.fill"
        case .spam: return "exclamationmark.octagon.fill"
        case .archive: return "archivebox.fill"
        case .starred: return "star.fill"
        case .custom: return "folder.fill"
        }
    }

    var displayName: String {
        return rawValue
    }
}

// MARK: - Standard Folders

extension Folder {

    /// Create inbox folder
    static func createInbox(for account: Account) -> Folder {
        let folder = Folder(
            name: "Inbox",
            path: "INBOX",
            type: .inbox,
            displayOrder: 0
        )
        folder.account = account
        return folder
    }

    /// Create sent folder
    static func createSent(for account: Account) -> Folder {
        let folder = Folder(
            name: "Sent",
            path: "Sent",
            type: .sent,
            displayOrder: 1
        )
        folder.account = account
        return folder
    }

    /// Create drafts folder
    static func createDrafts(for account: Account) -> Folder {
        let folder = Folder(
            name: "Drafts",
            path: "Drafts",
            type: .drafts,
            displayOrder: 2
        )
        folder.account = account
        return folder
    }

    /// Create trash folder
    static func createTrash(for account: Account) -> Folder {
        let folder = Folder(
            name: "Trash",
            path: "Trash",
            type: .trash,
            displayOrder: 3
        )
        folder.account = account
        return folder
    }

    /// Create starred folder (virtual)
    static func createStarred(for account: Account) -> Folder {
        let folder = Folder(
            name: "Starred",
            path: "", // Virtual folder, no IMAP path
            type: .starred,
            displayOrder: 4
        )
        folder.account = account
        return folder
    }
}
