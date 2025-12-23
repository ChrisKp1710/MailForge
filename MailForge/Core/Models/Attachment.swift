import Foundation
import SwiftData
import UniformTypeIdentifiers

/// Email attachment model
@Model
final class Attachment {

    // MARK: - Properties

    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Filename
    var filename: String

    /// MIME type
    var mimeType: String

    /// File size (bytes)
    var size: Int64

    /// Path to attachment file on disk
    var filePath: String

    /// Content ID (for inline images)
    var contentID: String?

    /// Is inline attachment (e.g., embedded image)
    var isInline: Bool

    /// Download status
    var isDownloaded: Bool

    /// Relationships
    @Relationship(inverse: \Message.attachments) var message: Message?

    /// Creation date
    var createdAt: Date

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        filename: String,
        mimeType: String,
        size: Int64,
        filePath: String,
        contentID: String? = nil,
        isInline: Bool = false,
        isDownloaded: Bool = false
    ) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.size = size
        self.filePath = filePath
        self.contentID = contentID
        self.isInline = isInline
        self.isDownloaded = isDownloaded
        self.createdAt = Date()
    }
}

// MARK: - Computed Properties

extension Attachment {

    /// File extension
    var fileExtension: String {
        return (filename as NSString).pathExtension.lowercased()
    }

    /// Formatted size string
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    /// UTType for the file
    var utType: UTType? {
        if let type = UTType(mimeType: mimeType) {
            return type
        }
        // Fallback to extension
        return UTType(filenameExtension: fileExtension)
    }

    /// Icon name for SF Symbols
    var iconName: String {
        guard let utType = utType else {
            return "doc.fill"
        }

        if utType.conforms(to: .image) {
            return "photo.fill"
        } else if utType.conforms(to: .pdf) {
            return "doc.richtext.fill"
        } else if utType.conforms(to: .text) {
            return "doc.text.fill"
        } else if utType.conforms(to: .movie) || utType.conforms(to: .video) {
            return "film.fill"
        } else if utType.conforms(to: .audio) {
            return "music.note"
        } else if utType.conforms(to: .archive) {
            return "doc.zipper"
        } else if utType.conforms(to: .spreadsheet) {
            return "tablecells.fill"
        } else if utType.conforms(to: .presentation) {
            return "rectangle.stack.fill"
        } else {
            return "doc.fill"
        }
    }

    /// Is image attachment
    var isImage: Bool {
        return utType?.conforms(to: .image) ?? false
    }

    /// Is PDF attachment
    var isPDF: Bool {
        return utType?.conforms(to: .pdf) ?? false
    }

    /// Is document attachment
    var isDocument: Bool {
        guard let utType = utType else { return false }
        return utType.conforms(to: .text) ||
               utType.conforms(to: .pdf) ||
               utType.conforms(to: .spreadsheet) ||
               utType.conforms(to: .presentation)
    }
}

// MARK: - File Operations

extension Attachment {

    /// Get file URL
    var fileURL: URL {
        return URL(fileURLWithPath: filePath)
    }

    /// Check if file exists on disk
    var fileExists: Bool {
        return FileManager.default.fileExists(atPath: filePath)
    }

    /// Delete attachment file from disk
    func deleteFile() throws {
        guard fileExists else { return }
        try FileManager.default.removeItem(atPath: filePath)
    }

    /// Get file data
    func getData() throws -> Data {
        guard fileExists else {
            throw AttachmentError.fileNotFound
        }
        return try Data(contentsOf: fileURL)
    }
}

// MARK: - Attachment Error

enum AttachmentError: Error, LocalizedError {
    case fileNotFound
    case downloadFailed
    case invalidMIMEType

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Attachment file not found on disk"
        case .downloadFailed:
            return "Failed to download attachment"
        case .invalidMIMEType:
            return "Invalid or unsupported MIME type"
        }
    }
}
