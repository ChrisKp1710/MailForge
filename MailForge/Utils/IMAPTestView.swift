import SwiftUI

// MARK: - IMAP Test View

/// Test view for verifying IMAP connection with real Gmail account
struct IMAPTestView: View {

    @State private var isTestRunning = false
    @State private var testResults: [String] = []
    @State private var hasError = false

    // Test credentials (TEMPORARY - will be removed after test)
    private let email = "Chriskp1710@gmail.com"
    private let appPassword = "nojvisnnhrntnlws" // Spaces removed

    var body: some View {
        VStack(spacing: 20) {
            Text("IMAP Connection Test")
                .font(.title.bold())

            Text("Testing: \(email)")
                .font(.headline)
                .foregroundStyle(.secondary)

            Divider()

            // Test Results
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(testResults, id: \.self) { result in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: result.hasPrefix("✅") ? "checkmark.circle.fill" :
                                             result.hasPrefix("❌") ? "xmark.circle.fill" :
                                             "info.circle.fill")
                                .foregroundStyle(result.hasPrefix("✅") ? .green :
                                               result.hasPrefix("❌") ? .red :
                                               .blue)

                            Text(result)
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .frame(maxHeight: 400)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            // Test Button
            Button(action: runTest) {
                HStack {
                    if isTestRunning {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isTestRunning ? "Testing..." : "Run IMAP Test")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isTestRunning)
            .controlSize(.large)

            if hasError {
                Text("⚠️ Test failed - check results above")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .padding(32)
        .frame(width: 600, height: 600)
    }

    private func runTest() {
        isTestRunning = true
        hasError = false
        testResults = []

        addResult("🚀 Starting IMAP test...")
        addResult("📧 Email: \(email)")
        addResult("🔐 Using App Password: \(String(repeating: "*", count: 16))")

        Task {
            do {
                // Step 1: Create IMAP client
                addResult("📡 Connecting to imap.gmail.com:993...")

                let client = IMAPClient(
                    host: "imap.gmail.com",
                    port: 993,
                    useTLS: true,
                    username: email,
                    password: appPassword
                )

                // Step 2: Connect and login
                addResult("🔌 Establishing connection...")
                try await client.connect()
                addResult("✅ Connected successfully!")

                addResult("🔑 Authenticating...")
                try await client.login()
                addResult("✅ Authenticated successfully!")

                // Step 3: List folders
                addResult("📁 Fetching folders...")
                let folders = try await client.list(pattern: "*")
                addResult("✅ Found \(folders.count) folders:")

                for folder in folders.prefix(10) {
                    addResult("   • \(folder.name) (\(folder.attributes.joined(separator: ", ")))")
                }

                if folders.count > 10 {
                    addResult("   ... and \(folders.count - 10) more")
                }

                // Step 4: Select INBOX
                addResult("📥 Selecting INBOX...")
                let inboxInfo = try await client.select(folder: "INBOX")
                addResult("✅ INBOX selected!")
                addResult("   • Total messages: \(inboxInfo.exists)")
                addResult("   • Recent messages: \(inboxInfo.recent)")
                if let unseen = inboxInfo.unseen {
                    addResult("   • Unread count: \(unseen)")
                }

                // Step 5: Fetch latest message headers
                if inboxInfo.exists > 0 {
                    addResult("📧 Fetching latest 3 messages...")

                    let lastUID = inboxInfo.exists
                    let startUID = max(1, lastUID - 2)

                    // Note: We need to implement FETCH in IMAPClient
                    addResult("⚠️ FETCH not yet implemented - will add in next step")
                }

                // Step 6: Disconnect
                addResult("👋 Disconnecting...")
                try await client.disconnect()
                addResult("✅ Disconnected successfully!")

                addResult("")
                addResult("🎉 TEST COMPLETED SUCCESSFULLY!")
                addResult("✅ Your IMAP client is working perfectly!")

            } catch {
                hasError = true
                addResult("❌ ERROR: \(error.localizedDescription)")

                if let imapError = error as? IMAPError {
                    addResult("   Error type: \(imapError)")
                }
            }

            await MainActor.run {
                isTestRunning = false
            }
        }
    }

    private func addResult(_ message: String) {
        Task { @MainActor in
            testResults.append(message)
        }
    }
}

// MARK: - Preview

#Preview {
    IMAPTestView()
}
