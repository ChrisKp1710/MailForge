import Foundation
import SwiftData

// MARK: - Email Storage

/// Manages email storage using SwiftData and file system
final class EmailStorage {

    // MARK: - Properties

    /// SwiftData model context
    private let modelContext: ModelContext

    /// File manager
    private let fileManager = FileManager.default

    /// Logger category
    private let logCategory: Logger.Category = .database

    // MARK: - Initialization

    /// Initialize email storage
    /// - Parameter modelContext: SwiftData model context
    init(modelContext: ModelContext) {
        self.modelContext = modelContext

        // Ensure attachments directory exists
        try? createAttachmentsDirectory()

        Logger.debug("Email storage initialized", category: logCategory)
    }

    // MARK: - Save Email

    /// Save parsed email to SwiftData
    /// - Parameters:
    ///   - parsedEmail: Parsed email from EmailParser
    ///   - account: Account that received this email
    ///   - folder: Folder where email belongs
    ///   - uid: IMAP UID
    /// - Returns: Saved Message model
    @discardableResult
    func save(
        parsedEmail: ParsedEmail,
        account: Account,
        folder: Folder,
        uid: Int,
        flags: Set<String> = []
    ) async throws -> Message {
        Logger.debug("Saving email to database...", category: logCategory)

        // Extract body text and HTML
        let (bodyText, bodyHTML) = extractBodies(from: parsedEmail.body)

        // Create Message model
        let message = Message(
            uid: uid,
            messageId: parsedEmail.messageId ?? UUID().uuidString,
            subject: parsedEmail.subject ?? "(No Subject)",
            from: parsedEmail.from ?? "unknown@unknown.com",
            to: parsedEmail.to,
            cc: parsedEmail.cc,
            date: parsedEmail.date ?? Date(),
            bodyText: bodyText,
            bodyHTML: bodyHTML,
            isRead: flags.contains("\\Seen"),
            isFlagged: flags.contains("\\Flagged"),
            isDeleted: flags.contains("\\Deleted"),
            folder: folder
        )

        // Save attachments
        let parser = EmailParser()
        let attachments = parser.extractAttachments(from: parsedEmail)

        for emailAttachment in attachments {
            let attachment = try await saveAttachment(emailAttachment, for: message)
            message.addAttachment(attachment)
        }

        // Insert into SwiftData
        modelContext.insert(message)

        // Save context
        try modelContext.save()

        Logger.info("Email saved successfully (UID: \(uid), \(attachments.count) attachments)", category: logCategory)

        return message
    }

    // MARK: - Save Attachment

    /// Save attachment to file system
    /// - Parameters:
    ///   - emailAttachment: EmailAttachment from parser
    ///   - message: Parent message
    /// - Returns: Attachment model
    private func saveAttachment(
        _ emailAttachment: EmailAttachment,
        for message: Message
    ) async throws -> Attachment {
        Logger.debug("Saving attachment: \(emailAttachment.filename) (\(emailAttachment.size) bytes)", category: logCategory)

        // Generate unique filename
        let uniqueFilename = "\(UUID().uuidString)_\(emailAttachment.filename)"

        // Get attachments directory
        let attachmentsDir = try getAttachmentsDirectory()

        // Full path
        let filePath = attachmentsDir.appendingPathComponent(uniqueFilename)

        // Write data to file
        try emailAttachment.data.write(to: filePath)

        // Create Attachment model
        let attachment = Attachment(
            filename: emailAttachment.filename,
            mimeType: emailAttachment.contentType,
            size: emailAttachment.size,
            localPath: filePath.path
        )

        Logger.debug("Attachment saved to: \(filePath.path)", category: logCategory)

        return attachment
    }

    // MARK: - Body Extraction

    /// Extract text and HTML bodies from parsed email body
    /// - Parameter body: EmailBody
    /// - Returns: Tuple of (text, html)
    private func extractBodies(from body: EmailBody) -> (text: String?, html: String?) {
        switch body {
        case .text(let text):
            return (text, nil)

        case .html(let html):
            return (nil, html)

        case .multipart(let parts):
            var textBody: String?
            var htmlBody: String?

            for part in parts {
                let (text, html) = extractBodies(from: part.body)

                // Prefer first occurrence
                if textBody == nil, let text = text {
                    textBody = text
                }

                if htmlBody == nil, let html = html {
                    htmlBody = html
                }
            }

            return (textBody, htmlBody)
        }
    }

    // MARK: - Fetch Messages

    /// Fetch all messages for a folder
    /// - Parameter folder: Folder to fetch messages from
    /// - Returns: Array of messages
    func fetchMessages(for folder: Folder) throws -> [Message] {
        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate { $0.folder == folder },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        return try modelContext.fetch(descriptor)
    }

    /// Fetch messages matching search criteria
    /// - Parameter searchText: Search query
    /// - Returns: Array of matching messages
    func search(text searchText: String) throws -> [Message] {
        let lowercased = searchText.lowercased()

        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate { message in
                message.subject.lowercased().contains(lowercased) ||
                message.from.lowercased().contains(lowercased) ||
                (message.bodyText?.lowercased().contains(lowercased) ?? false)
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        return try modelContext.fetch(descriptor)
    }

    /// Fetch unread messages count
    /// - Parameter folder: Optional folder filter
    /// - Returns: Count of unread messages
    func unreadCount(for folder: Folder? = nil) throws -> Int {
        let descriptor: FetchDescriptor<Message>

        if let folder = folder {
            descriptor = FetchDescriptor<Message>(
                predicate: #Predicate { $0.folder == folder && !$0.isRead }
            )
        } else {
            descriptor = FetchDescriptor<Message>(
                predicate: #Predicate { !$0.isRead }
            )
        }

        return try modelContext.fetchCount(descriptor)
    }

    // MARK: - Update Message

    /// Mark message as read
    /// - Parameter message: Message to update
    func markAsRead(_ message: Message) throws {
        message.isRead = true
        try modelContext.save()

        Logger.debug("Message marked as read: \(message.messageId)", category: logCategory)
    }

    /// Mark message as unread
    /// - Parameter message: Message to update
    func markAsUnread(_ message: Message) throws {
        message.isRead = false
        try modelContext.save()

        Logger.debug("Message marked as unread: \(message.messageId)", category: logCategory)
    }

    /// Toggle flagged status
    /// - Parameter message: Message to update
    func toggleFlagged(_ message: Message) throws {
        message.isFlagged.toggle()
        try modelContext.save()

        Logger.debug("Message flagged status: \(message.isFlagged)", category: logCategory)
    }

    /// Delete message
    /// - Parameter message: Message to delete
    func delete(_ message: Message) throws {
        // Delete attachments from file system
        for attachment in message.attachments {
            if let localPath = attachment.localPath {
                try? fileManager.removeItem(atPath: localPath)
            }
        }

        // Delete from SwiftData
        modelContext.delete(message)
        try modelContext.save()

        Logger.info("Message deleted: \(message.messageId)", category: logCategory)
    }

    // MARK: - File System

    /// Get attachments directory URL
    /// - Returns: Attachments directory URL
    private func getAttachmentsDirectory() throws -> URL {
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let mailForgeDir = appSupport.appendingPathComponent("MailForge", isDirectory: true)
        let attachmentsDir = mailForgeDir.appendingPathComponent("Attachments", isDirectory: true)

        return attachmentsDir
    }

    /// Create attachments directory if it doesn't exist
    private func createAttachmentsDirectory() throws {
        let attachmentsDir = try getAttachmentsDirectory()

        if !fileManager.fileExists(atPath: attachmentsDir.path) {
            try fileManager.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)
            Logger.info("Created attachments directory: \(attachmentsDir.path)", category: logCategory)
        }
    }

    // MARK: - Cleanup

    /// Delete all emails and attachments for an account
    /// - Parameter account: Account to clean up
    func deleteAllEmails(for account: Account) throws {
        Logger.info("Deleting all emails for account: \(account.email)", category: logCategory)

        // Fetch all messages for this account's folders
        let folders = account.folders
        var totalDeleted = 0

        for folder in folders {
            let messages = try fetchMessages(for: folder)

            for message in messages {
                try delete(message)
                totalDeleted += 1
            }
        }

        Logger.info("Deleted \(totalDeleted) emails", category: logCategory)
    }

    /// Calculate total storage used by attachments
    /// - Returns: Size in bytes
    func calculateStorageUsed() throws -> Int {
        let attachmentsDir = try getAttachmentsDirectory()

        guard let enumerator = fileManager.enumerator(at: attachmentsDir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var totalSize = 0

        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            totalSize += resourceValues.fileSize ?? 0
        }

        Logger.debug("Total storage used: \(totalSize) bytes", category: logCategory)

        return totalSize
    }
}

// MARK: - Storage Errors

/// Errors that can occur during email storage operations
enum EmailStorageError: Error, LocalizedError {
    case fileSystemError(String)
    case databaseError(String)

    var errorDescription: String? {
        switch self {
        case .fileSystemError(let message):
            return "File system error: \(message)"
        case .databaseError(let message):
            return "Database error: \(message)"
        }
    }
}
