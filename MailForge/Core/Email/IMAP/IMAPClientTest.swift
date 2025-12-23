import Foundation

/// Test suite for IMAP Client
///
/// COME USARE:
/// 1. Modifica le credenziali qui sotto con il tuo account email
/// 2. Apri ContentView.swift
/// 3. Aggiungi un Button che chiama IMAPClientTest.runTest()
/// 4. Premi il button per testare
///
final class IMAPClientTest {

    // MARK: - Configurazione Test

    /// MODIFICA QUESTI VALORI CON LE TUE CREDENZIALI
    private static let testConfig = TestConfig(
        // Gmail example:
        host: "imap.gmail.com",
        port: 993,
        username: "tua-email@gmail.com",  // ← INSERISCI LA TUA EMAIL
        password: "tua-password-app",     // ← INSERISCI LA TUA PASSWORD
        useTLS: true

        // PEC IONOS example:
        // host: "imap.ionos.it",
        // port: 993,
        // username: "tua-email@pec.it",
        // password: "tua-password",
        // useTLS: true
    )

    // MARK: - Run Test

    /// Esegui test completo del client IMAP
    static func runTest() async {
        Logger.info("🧪 INIZIO TEST IMAP CLIENT", category: .imap)
        Logger.info("=" * 50, category: .imap)

        do {
            // Test 1: Connessione
            try await testConnection()

            // Test 2: Login
            try await testLogin()

            // Test 3: Lista cartelle
            try await testListFolders()

            // Test 4: Seleziona INBOX
            try await testSelectInbox()

            // Test 5: Cerca messaggi
            try await testSearchMessages()

            Logger.info("=" * 50, category: .imap)
            Logger.info("✅ TUTTI I TEST PASSATI!", category: .imap)

        } catch {
            Logger.error("❌ TEST FALLITO", error: error, category: .imap)
        }
    }

    // MARK: - Test Methods

    /// Test 1: Connessione al server
    private static func testConnection() async throws {
        Logger.info("📡 Test 1: Connessione al server...", category: .imap)

        let client = createClient()

        try await client.connect()
        Logger.info("✅ Connessione riuscita!", category: .imap)

        try await client.disconnect()
        Logger.info("✅ Disconnessione riuscita!", category: .imap)
    }

    /// Test 2: Login
    private static func testLogin() async throws {
        Logger.info("🔐 Test 2: Login...", category: .imap)

        let client = createClient()

        try await client.connect()
        try await client.login()
        Logger.info("✅ Login riuscito!", category: .imap)

        try await client.disconnect()
    }

    /// Test 3: Lista cartelle
    private static func testListFolders() async throws {
        Logger.info("📁 Test 3: Lista cartelle...", category: .imap)

        let client = createClient()

        try await client.connect()
        try await client.login()

        let folders = try await client.list()
        Logger.info("✅ Trovate \(folders.count) cartelle:", category: .imap)

        for folder in folders.prefix(10) {
            Logger.info("  - \(folder.name) (\(folder.path))", category: .imap)
        }

        try await client.disconnect()
    }

    /// Test 4: Seleziona INBOX
    private static func testSelectInbox() async throws {
        Logger.info("📥 Test 4: Seleziona INBOX...", category: .imap)

        let client = createClient()

        try await client.connect()
        try await client.login()

        let folderInfo = try await client.select(folder: "INBOX")
        Logger.info("✅ INBOX selezionata!", category: .imap)
        Logger.info("  - Messaggi totali: \(folderInfo.exists)", category: .imap)
        Logger.info("  - Messaggi recenti: \(folderInfo.recent)", category: .imap)
        Logger.info("  - Flags: \(folderInfo.flags.joined(separator: ", "))", category: .imap)

        try await client.disconnect()
    }

    /// Test 5: Cerca messaggi
    private static func testSearchMessages() async throws {
        Logger.info("🔍 Test 5: Cerca messaggi non letti...", category: .imap)

        let client = createClient()

        try await client.connect()
        try await client.login()
        try await client.select(folder: "INBOX")

        // Cerca messaggi non letti
        let unseenUIDs = try await client.uidSearch(criteria: .unseen)
        Logger.info("✅ Trovati \(unseenUIDs.count) messaggi non letti", category: .imap)

        if !unseenUIDs.isEmpty {
            Logger.info("  - UIDs: \(unseenUIDs.prefix(10).map(String.init).joined(separator: ", "))", category: .imap)
        }

        try await client.disconnect()
    }

    // MARK: - Helper

    /// Crea client IMAP con configurazione test
    private static func createClient() -> IMAPClient {
        return IMAPClient(
            host: testConfig.host,
            port: testConfig.port,
            useTLS: testConfig.useTLS,
            username: testConfig.username,
            password: testConfig.password
        )
    }
}

// MARK: - Test Configuration

private struct TestConfig {
    let host: String
    let port: Int
    let username: String
    let password: String
    let useTLS: Bool
}

// MARK: - String Repeat Helper

private extension String {
    static func * (string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
}
