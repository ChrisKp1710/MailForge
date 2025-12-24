import SwiftUI

// MARK: - Account Setup View

/// View for adding a new email account
struct AccountSetupView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @State private var selectedPreset: AccountPreset = .gmail
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var displayName: String = ""

    @State private var isTestingConnection: Bool = false
    @State private var connectionTestPassed: Bool = false
    @State private var testError: String?

    @State private var isSaving: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    // MARK: - Account Manager

    private var accountManager: AccountManager {
        AccountManager(modelContext: modelContext)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Provider selection
                    providerSection

                    Divider()

                    // Account credentials
                    credentialsSection

                    // Test connection
                    if !email.isEmpty && !password.isEmpty {
                        testConnectionSection
                    }

                    // Notes
                    if let notes = selectedPreset.notes {
                        notesSection(notes)
                    }
                }
                .padding(Spacing.xl)
            }

            Divider()

            // Footer buttons
            footer
        }
        .frame(width: 600, height: 700)
        .background(Color.backgroundPrimary)
        .alert("Errore", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Aggiungi Account")
                .font(.headlineLarge)
                .foregroundColor(.textPrimary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.lg)
    }

    // MARK: - Provider Section

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Provider Email")
                .font(.headlineSmall)
                .foregroundColor(.textPrimary)

            // Provider grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Spacing.sm) {
                ForEach(AccountPreset.allPresets, id: \.name) { preset in
                    providerButton(preset)
                }
            }
        }
    }

    private func providerButton(_ preset: AccountPreset) -> some View {
        Button {
            selectedPreset = preset
            // Auto-detect if email already entered
            if !email.isEmpty {
                let detected = AccountPreset.detectPreset(from: email)
                selectedPreset = detected
            }
        } label: {
            VStack(spacing: Spacing.xs) {
                Image(systemName: preset.icon)
                    .font(.title)
                    .foregroundColor(selectedPreset.name == preset.name ? .brandPrimary : .textSecondary)

                Text(preset.name)
                    .font(.caption)
                    .foregroundColor(.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.md)
            .background(
                selectedPreset.name == preset.name
                    ? Color.brandPrimary.opacity(0.1)
                    : Color.backgroundSecondary
            )
            .cornerRadius(CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(
                        selectedPreset.name == preset.name ? Color.brandPrimary : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Credentials Section

    private var credentialsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Credenziali")
                .font(.headlineSmall)
                .foregroundColor(.textPrimary)

            // Email
            DSTextField("Email", text: $email, icon: "envelope")
                .onChange(of: email) { _, newValue in
                    // Auto-detect provider
                    if !newValue.isEmpty {
                        selectedPreset = AccountPreset.detectPreset(from: newValue)
                    }

                    // Reset test status
                    connectionTestPassed = false
                    testError = nil
                }

            // Password
            DSTextField("Password", text: $password, icon: "lock", isSecure: true)
                .onChange(of: password) { _, _ in
                    // Reset test status
                    connectionTestPassed = false
                    testError = nil
                }

            // Display name (optional)
            DSTextField("Nome visualizzato (opzionale)", text: $displayName, icon: "person")
        }
    }

    // MARK: - Test Connection Section

    private var testConnectionSection: some View {
        VStack(spacing: Spacing.md) {
            if connectionTestPassed {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.semanticSuccess)
                    Text("Connessione verificata!")
                        .foregroundColor(.semanticSuccess)
                        .font(.bodyMedium)
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity)
                .background(Color.semanticSuccess.opacity(0.1))
                .cornerRadius(CornerRadius.md)
            } else if let error = testError {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.semanticError)
                    Text(error)
                        .foregroundColor(.semanticError)
                        .font(.bodySmall)
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity)
                .background(Color.semanticError.opacity(0.1))
                .cornerRadius(CornerRadius.md)
            }

            DSButton(
                isTestingConnection ? "Test in corso..." : "Testa Connessione",
                icon: "antenna.radiowaves.left.and.right",
                style: .secondary
            ) {
                testConnection()
            }
            .disabled(isTestingConnection || email.isEmpty || password.isEmpty)
        }
    }

    // MARK: - Notes Section

    private func notesSection(_ notes: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.semanticInfo)
                .font(.bodyMedium)

            Text(notes)
                .font(.bodySmall)
                .foregroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.semanticInfo.opacity(0.1))
        .cornerRadius(CornerRadius.md)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: Spacing.md) {
            DSButton("Annulla", style: .ghost) {
                dismiss()
            }

            Spacer()

            DSButton(
                isSaving ? "Salvataggio..." : "Aggiungi Account",
                icon: "plus.circle.fill",
                style: .primary
            ) {
                saveAccount()
            }
            .disabled(
                email.isEmpty ||
                password.isEmpty ||
                isSaving ||
                !connectionTestPassed
            )
        }
        .padding(Spacing.lg)
    }

    // MARK: - Actions

    private func testConnection() {
        isTestingConnection = true
        testError = nil

        Task {
            do {
                // Create temporary account for testing
                let tempAccount = Account(
                    email: email,
                    displayName: displayName.isEmpty ? email : displayName,
                    type: selectedPreset.type,
                    imapServer: selectedPreset.imapHost,
                    imapPort: selectedPreset.imapPort,
                    imapUseTLS: selectedPreset.imapUseTLS,
                    smtpServer: selectedPreset.smtpHost,
                    smtpPort: selectedPreset.smtpPort,
                    smtpUseTLS: selectedPreset.smtpUseTLS
                )

                // Save password temporarily
                try tempAccount.savePassword(password, using: KeychainManager())

                // Test IMAP
                _ = try await accountManager.testIMAPConnection(for: tempAccount)

                // Test SMTP
                _ = try await accountManager.testSMTPConnection(for: tempAccount)

                // Cleanup temp password
                try? tempAccount.deletePassword(using: KeychainManager())

                // Success
                await MainActor.run {
                    connectionTestPassed = true
                    isTestingConnection = false
                }

            } catch {
                await MainActor.run {
                    connectionTestPassed = false
                    testError = "Connessione fallita: \(error.localizedDescription)"
                    isTestingConnection = false
                }
            }
        }
    }

    private func saveAccount() {
        isSaving = true

        Task {
            do {
                _ = try await accountManager.addAccount(
                    email: email,
                    password: password,
                    preset: selectedPreset,
                    displayName: displayName.isEmpty ? nil : displayName
                )

                await MainActor.run {
                    dismiss()
                }

            } catch {
                await MainActor.run {
                    errorMessage = "Errore durante il salvataggio: \(error.localizedDescription)"
                    showError = true
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AccountSetupView()
        .modelContainer(for: [Account.self, Folder.self, Message.self, Attachment.self])
}
