import Foundation

/// SMTP Client Test Suite
/// Demonstrates all capabilities of the SMTP client implementation
final class SMTPClientTest {

    // MARK: - Test Configuration

    private struct TestConfig {
        let host: String
        let port: Int
        let username: String
        let password: String
        let useTLS: Bool
    }

    /// Test configuration - UPDATE THESE WITH REAL CREDENTIALS TO TEST
    private static let testConfig = TestConfig(
        host: "smtp.gmail.com",           // or "smtp.ionos.it" for PEC
        port: 587,                        // 587 for STARTTLS, 465 for TLS
        username: "your-email@gmail.com", // ← INSERISCI QUI
        password: "your-app-password",    // ← INSERISCI QUI (App Password for Gmail)
        useTLS: true
    )

    // MARK: - Main Test Entry Point

    /// Run all SMTP tests
    static func runTest() async {
        Logger.info("🧪 INIZIO TEST SMTP CLIENT", category: .smtp)
        Logger.info("==================================================", category: .smtp)

        do {
            try await testConnection()
            try await testAuthentication()
            try await testSimpleTextEmail()
            try await testHTMLEmail()
            try await testMultipartEmail()
            try await testEmailWithAttachments()

            Logger.info("==================================================", category: .smtp)
            Logger.info("✅ TUTTI I TEST SMTP PASSATI!", category: .smtp)

        } catch {
            Logger.error("❌ TEST SMTP FALLITO", error: error, category: .smtp)
        }
    }

    // MARK: - Test 1: Connection

    /// Test SMTP server connection
    private static func testConnection() async throws {
        Logger.info("📡 Test 1: Connessione al server SMTP...", category: .smtp)

        let client = SMTPClient(
            host: testConfig.host,
            port: testConfig.port,
            useTLS: testConfig.useTLS,
            username: testConfig.username,
            password: testConfig.password
        )

        try await client.connect()
        Logger.info("✅ Connessione riuscita!", category: .smtp)

        try await client.disconnect()
        Logger.info("✅ Disconnessione riuscita!", category: .smtp)
    }

    // MARK: - Test 2: Authentication

    /// Test SMTP authentication
    private static func testAuthentication() async throws {
        Logger.info("🔐 Test 2: Autenticazione SMTP...", category: .smtp)

        let client = SMTPClient(
            host: testConfig.host,
            port: testConfig.port,
            useTLS: testConfig.useTLS,
            username: testConfig.username,
            password: testConfig.password
        )

        try await client.connect()
        try await client.authenticate()
        Logger.info("✅ Autenticazione riuscita!", category: .smtp)

        try await client.disconnect()
    }

    // MARK: - Test 3: Simple Text Email

    /// Test sending simple plain text email
    private static func testSimpleTextEmail() async throws {
        Logger.info("📧 Test 3: Invio email di testo semplice...", category: .smtp)

        let client = SMTPClient(
            host: testConfig.host,
            port: testConfig.port,
            useTLS: testConfig.useTLS,
            username: testConfig.username,
            password: testConfig.password
        )

        try await client.connect()
        try await client.authenticate()

        // Simple text email
        try await client.sendEmail(
            from: testConfig.username,
            to: [testConfig.username], // Send to self for testing
            subject: "Test MailForge - Plain Text",
            body: "Questo è un test di invio email in testo semplice dal client SMTP di MailForge."
        )

        Logger.info("✅ Email di testo inviata con successo!", category: .smtp)

        try await client.disconnect()
    }

    // MARK: - Test 4: HTML Email

    /// Test sending HTML email
    private static func testHTMLEmail() async throws {
        Logger.info("🎨 Test 4: Invio email HTML...", category: .smtp)

        let client = SMTPClient(
            host: testConfig.host,
            port: testConfig.port,
            useTLS: testConfig.useTLS,
            username: testConfig.username,
            password: testConfig.password
        )

        try await client.connect()
        try await client.authenticate()

        // HTML email
        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
                .header { background-color: #007AFF; color: white; padding: 20px; }
                .content { padding: 20px; }
                .footer { background-color: #f5f5f5; padding: 10px; text-align: center; font-size: 12px; }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>🚀 MailForge Test</h1>
            </div>
            <div class="content">
                <h2>Email HTML Test</h2>
                <p>Questo è un test di invio email HTML dal client SMTP di MailForge.</p>
                <p><strong>Features:</strong></p>
                <ul>
                    <li>✅ SwiftNIO per networking asincrono</li>
                    <li>✅ TLS/SSL encryption</li>
                    <li>✅ MIME multipart support</li>
                    <li>✅ HTML email support</li>
                </ul>
            </div>
            <div class="footer">
                Sent from MailForge - Native macOS Email Client
            </div>
        </body>
        </html>
        """

        let message = MIMEMessageBuilder(
            from: testConfig.username,
            to: [testConfig.username],
            subject: "Test MailForge - HTML Email"
        )
        .htmlBody(htmlContent)

        try await client.sendEmail(message: message)

        Logger.info("✅ Email HTML inviata con successo!", category: .smtp)

        try await client.disconnect()
    }

    // MARK: - Test 5: Multipart Email (Text + HTML)

    /// Test sending multipart/alternative email (both text and HTML versions)
    private static func testMultipartEmail() async throws {
        Logger.info("📄 Test 5: Invio email multipart (Text + HTML)...", category: .smtp)

        let client = SMTPClient(
            host: testConfig.host,
            port: testConfig.port,
            useTLS: testConfig.useTLS,
            username: testConfig.username,
            password: testConfig.password
        )

        try await client.connect()
        try await client.authenticate()

        let textContent = """
        Test MailForge - Multipart Email

        Questa email contiene sia una versione di testo che una versione HTML.
        Il client email sceglierà automaticamente quale visualizzare.

        Features:
        - SwiftNIO per networking asincrono
        - TLS/SSL encryption
        - MIME multipart/alternative support
        """

        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <body style="font-family: -apple-system, sans-serif;">
            <h1 style="color: #007AFF;">🚀 Test MailForge - Multipart Email</h1>
            <p>Questa email contiene <strong>sia una versione di testo che una versione HTML</strong>.</p>
            <p>Il client email sceglierà automaticamente quale visualizzare.</p>
            <h2>Features:</h2>
            <ul>
                <li>✅ SwiftNIO per networking asincrono</li>
                <li>✅ TLS/SSL encryption</li>
                <li>✅ MIME multipart/alternative support</li>
            </ul>
        </body>
        </html>
        """

        let message = MIMEMessageBuilder(
            from: testConfig.username,
            to: [testConfig.username],
            subject: "Test MailForge - Multipart (Text + HTML)"
        )
        .textBody(textContent)
        .htmlBody(htmlContent)
        .cc(["test@example.com"]) // Example CC (won't actually send if not authenticated)
        .replyTo(testConfig.username)

        try await client.sendEmail(message: message)

        Logger.info("✅ Email multipart inviata con successo!", category: .smtp)

        try await client.disconnect()
    }

    // MARK: - Test 6: Email with Attachments

    /// Test sending email with attachments
    private static func testEmailWithAttachments() async throws {
        Logger.info("📎 Test 6: Invio email con allegati...", category: .smtp)

        let client = SMTPClient(
            host: testConfig.host,
            port: testConfig.port,
            useTLS: testConfig.useTLS,
            username: testConfig.username,
            password: testConfig.password
        )

        try await client.connect()
        try await client.authenticate()

        // Create a test text file attachment
        let testFileContent = """
        Questo è un file di test allegato all'email.

        MailForge SMTP Client
        - SwiftNIO networking
        - MIME multipart/mixed
        - Base64 encoding
        - Attachment support
        """

        let testData = testFileContent.data(using: .utf8)!

        let attachment = MIMEAttachment(
            filename: "test-mailforge.txt",
            contentType: "text/plain",
            data: testData,
            isInline: false
        )

        let message = MIMEMessageBuilder(
            from: testConfig.username,
            to: [testConfig.username],
            subject: "Test MailForge - Email con Allegati"
        )
        .textBody("Questa email contiene un allegato di testo.\n\nVerifica che l'allegato sia correttamente ricevuto.")
        .htmlBody("<h2>Email con Allegati</h2><p>Questa email contiene un allegato di testo.</p><p>Verifica che l'allegato sia correttamente ricevuto.</p>")
        .addAttachment(attachment)

        try await client.sendEmail(message: message)

        Logger.info("✅ Email con allegati inviata con successo!", category: .smtp)

        try await client.disconnect()
    }

    // MARK: - Example: Email with Image Attachment

    /// Example: Send email with image attachment (inline and regular)
    static func exampleEmailWithImage(imagePath: String) async throws {
        let client = SMTPClient(
            host: testConfig.host,
            port: testConfig.port,
            useTLS: testConfig.useTLS,
            username: testConfig.username,
            password: testConfig.password
        )

        try await client.connect()
        try await client.authenticate()

        // Load image from file
        let imageAttachment = try MIMEAttachment(
            filePath: imagePath,
            isInline: true,
            contentID: "image1"
        )

        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <body>
            <h1>Email con Immagine Inline</h1>
            <p>Ecco l'immagine allegata:</p>
            <img src="cid:image1" alt="Allegato" style="max-width: 600px;">
        </body>
        </html>
        """

        let message = MIMEMessageBuilder(
            from: testConfig.username,
            to: [testConfig.username],
            subject: "Test MailForge - Immagine Inline"
        )
        .textBody("Questa email contiene un'immagine inline.")
        .htmlBody(htmlContent)
        .addAttachment(imageAttachment)

        try await client.sendEmail(message: message)

        try await client.disconnect()
    }
}

// MARK: - Usage Examples

extension SMTPClientTest {

    /// Example 1: Simple text email
    static func example1_SimpleText() async throws {
        let client = SMTPClient(
            host: "smtp.gmail.com",
            port: 587,
            useTLS: true,
            username: "your-email@gmail.com",
            password: "your-app-password"
        )

        try await client.connect()
        try await client.authenticate()

        try await client.sendEmail(
            from: "your-email@gmail.com",
            to: ["recipient@example.com"],
            subject: "Hello from MailForge",
            body: "This is a simple text email."
        )

        try await client.disconnect()
    }

    /// Example 2: HTML email with builder
    static func example2_HTMLEmail() async throws {
        let client = SMTPClient(
            host: "smtp.gmail.com",
            port: 587,
            useTLS: true,
            username: "your-email@gmail.com",
            password: "your-app-password"
        )

        try await client.connect()
        try await client.authenticate()

        let message = MIMEMessageBuilder(
            from: "your-email@gmail.com",
            to: ["recipient@example.com"],
            subject: "HTML Email from MailForge"
        )
        .htmlBody("<h1>Hello!</h1><p>This is an <strong>HTML</strong> email.</p>")
        .cc(["cc@example.com"])
        .replyTo("reply-to@example.com")

        try await client.sendEmail(message: message)

        try await client.disconnect()
    }

    /// Example 3: Email with PDF attachment
    static func example3_WithAttachment() async throws {
        let client = SMTPClient(
            host: "smtp.gmail.com",
            port: 587,
            useTLS: true,
            username: "your-email@gmail.com",
            password: "your-app-password"
        )

        try await client.connect()
        try await client.authenticate()

        let attachment = try MIMEAttachment(filePath: "/path/to/document.pdf")

        let message = MIMEMessageBuilder(
            from: "your-email@gmail.com",
            to: ["recipient@example.com"],
            subject: "Document Attached"
        )
        .textBody("Please find the document attached.")
        .addAttachment(attachment)

        try await client.sendEmail(message: message)

        try await client.disconnect()
    }
}
