import Foundation
import SwiftData

/// Test data generator for development and testing
struct TestDataGenerator {

    /// Populate the database with sample data
    static func populateTestData(context: ModelContext) {
        // Check if data already exists
        let descriptor = FetchDescriptor<Account>()
        if let count = try? context.fetchCount(descriptor), count > 0 {
            print("⚠️ Test data already exists, skipping...")
            return
        }

        print("📧 Generating test data...")

        // Create test account
        let account = Account(
            name: "Test Account",
            emailAddress: "test@example.com",
            type: .imap,
            imapHost: "imap.example.com",
            imapPort: 993,
            smtpHost: "smtp.example.com",
            smtpPort: 465
        )
        context.insert(account)

        // Create folders
        let inbox = Folder(
            name: "INBOX",
            path: "INBOX",
            type: .inbox
        )
        inbox.unreadCount = 3

        let sent = Folder(
            name: "SENT",
            path: "Sent",
            type: .sent
        )

        let drafts = Folder(
            name: "DRAFTS",
            path: "Drafts",
            type: .drafts
        )
        drafts.unreadCount = 1

        let trash = Folder(
            name: "TRASH",
            path: "Trash",
            type: .trash
        )

        context.insert(inbox)
        context.insert(sent)
        context.insert(drafts)
        context.insert(trash)

        account.folders = [inbox, sent, drafts, trash]

        // Create sample messages in INBOX
        let messages = [
            Message(
                messageID: "msg-1",
                uid: 1,
                subject: "Benvenuto in MailForge!",
                from: "team@mailforge.app",
                fromName: "MailForge Team",
                to: ["test@example.com"],
                cc: [],
                date: Date(),
                preview: "Grazie per aver provato MailForge! Questa è un'email di test per mostrarti come appare l'interfaccia moderna.",
                isRead: false,
                hasAttachments: false,
                isPEC: false
            ),
            Message(
                messageID: "msg-2",
                uid: 2,
                subject: "Documento importante - PEC",
                from: "admin@pec.example.com",
                fromName: "Amministrazione",
                to: ["test@example.com"],
                cc: ["manager@example.com"],
                date: Date().addingTimeInterval(-3600),
                preview: "In allegato troverai il documento richiesto. Questa è una comunicazione certificata via PEC.",
                isRead: false,
                hasAttachments: true,
                isPEC: true
            ),
            Message(
                messageID: "msg-3",
                uid: 3,
                subject: "Riunione di progetto - Venerdì 10:00",
                from: "colleague@example.com",
                fromName: "Mario Rossi",
                to: ["test@example.com", "team@example.com"],
                cc: [],
                date: Date().addingTimeInterval(-7200),
                preview: "Ciao a tutti, vi ricordo la riunione di venerdì alle 10:00 per discutere lo stato del progetto.",
                isRead: false,
                isStarred: true,
                hasAttachments: false,
                isPEC: false
            ),
            Message(
                messageID: "msg-4",
                uid: 4,
                subject: "Weekly Newsletter - Dicembre 2024",
                from: "newsletter@company.com",
                fromName: "Company News",
                to: ["test@example.com"],
                cc: [],
                date: Date().addingTimeInterval(-86400),
                preview: "Ecco le novità di questa settimana: nuovi progetti, aggiornamenti del team e tanto altro.",
                isRead: true,
                hasAttachments: false,
                isPEC: false
            ),
            Message(
                messageID: "msg-5",
                uid: 5,
                subject: "Conferma ordine #12345",
                from: "orders@shop.example.com",
                fromName: "Shop Online",
                to: ["test@example.com"],
                cc: [],
                date: Date().addingTimeInterval(-172800),
                preview: "Il tuo ordine #12345 è stato confermato e verrà spedito entro 2 giorni lavorativi.",
                isRead: true,
                hasAttachments: true,
                isPEC: false
            )
        ]

        // Add messages to inbox
        for message in messages {
            message.folder = inbox
            context.insert(message)
        }

        // Create a draft message
        let draft = Message(
            messageID: "draft-1",
            uid: 6,
            subject: "Risposta: Documento importante",
            from: "test@example.com",
            fromName: "Test Account",
            to: ["admin@pec.example.com"],
            cc: [],
            date: Date(),
            preview: "Gentile Amministrazione, ho ricevuto il documento e provvederò...",
            isRead: true,
            hasAttachments: false,
            isPEC: false
        )
        draft.folder = drafts
        context.insert(draft)

        // Save all changes
        do {
            try context.save()
            print("✅ Test data created successfully!")
            print("   - 1 Account: \(account.emailAddress)")
            print("   - 4 Folders: INBOX, SENT, DRAFTS, TRASH")
            print("   - \(messages.count + 1) Messages")
        } catch {
            print("❌ Error saving test data: \(error)")
        }
    }

    /// Clear all test data from the database
    static func clearTestData(context: ModelContext) {
        print("🗑️ Clearing test data...")

        do {
            // Fetch and delete all messages first (they depend on folders)
            let messageDescriptor = FetchDescriptor<Message>()
            let messages = try context.fetch(messageDescriptor)
            for message in messages {
                context.delete(message)
            }

            // Fetch and delete all attachments
            let attachmentDescriptor = FetchDescriptor<Attachment>()
            let attachments = try context.fetch(attachmentDescriptor)
            for attachment in attachments {
                context.delete(attachment)
            }

            // Fetch and delete all folders (they depend on accounts)
            let folderDescriptor = FetchDescriptor<Folder>()
            let folders = try context.fetch(folderDescriptor)
            for folder in folders {
                context.delete(folder)
            }

            // Finally, delete all accounts
            let accountDescriptor = FetchDescriptor<Account>()
            let accounts = try context.fetch(accountDescriptor)
            for account in accounts {
                context.delete(account)
            }

            try context.save()
            print("✅ Test data cleared successfully!")
            print("   - Deleted \(messages.count) messages")
            print("   - Deleted \(attachments.count) attachments")
            print("   - Deleted \(folders.count) folders")
            print("   - Deleted \(accounts.count) accounts")
        } catch {
            print("❌ Error clearing test data: \(error)")
        }
    }
}
