import SwiftUI
import SwiftData

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

    // OAuth2 state
    @State private var isAuthenticatingOAuth: Bool = false
    @State private var showManualConfig: Bool = false

    // MARK: - Account Manager (removed - created locally to avoid Sendable issues)

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // OAuth2 Quick Sign In
                    if !showManualConfig {
                        oauth2Section

                        // "OR" divider
                        HStack {
                            Rectangle()
                                .fill(Color.borderPrimary)
                                .frame(height: 1)

                            Text("OPPURE")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                                .padding(.horizontal, Spacing.sm)

                            Rectangle()
                                .fill(Color.borderPrimary)
                                .frame(height: 1)
                        }
                        .padding(.vertical, Spacing.md)

                        // Manual config button
                        DSButton(
                            "Configurazione Manuale",
                            icon: "gearshape",
                            style: .ghost
                        ) {
                            withAnimation {
                                showManualConfig = true
                            }
                        }
                    }

                    // Manual configuration (shown when requested)
                    if showManualConfig {
                        // Back button
                        HStack {
                            Button {
                                withAnimation {
                                    showManualConfig = false
                                }
                            } label: {
                                HStack(spacing: Spacing.xs) {
                                    Image(systemName: "chevron.left")
                                    Text("Torna indietro")
                                }
                                .font(.bodyMedium)
                                .foregroundColor(.brandPrimary)
                            }
                            .buttonStyle(.plain)

                            Spacer()
                        }

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

    // MARK: - OAuth2 Section

    private var oauth2Section: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Title
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Accesso Rapido")
                    .font(.headlineSmall)
                    .foregroundColor(.textPrimary)

                Text("Connetti il tuo account in 3 semplici click")
                    .font(.bodySmall)
                    .foregroundColor(.textSecondary)
            }

            // OAuth2 Buttons
            VStack(spacing: Spacing.md) {
                // Google Sign In Button
                oauth2Button(
                    provider: .google,
                    title: "Continua con Google",
                    icon: "g.circle.fill",
                    backgroundColor: Color.white,
                    foregroundColor: Color.black
                )

                // Microsoft Sign In Button
                oauth2Button(
                    provider: .microsoft,
                    title: "Continua con Microsoft",
                    icon: "m.square.fill",
                    backgroundColor: Color(red: 0.0, green: 0.46, blue: 0.82),
                    foregroundColor: Color.white
                )
            }

            // Info box
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.semanticInfo)
                    .font(.bodyMedium)

                Text("Utilizziamo OAuth2 per garantire la massima sicurezza. Non memorizziamo mai la tua password.")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.semanticInfo.opacity(0.1))
            .cornerRadius(CornerRadius.md)
        }
    }

    private func oauth2Button(
        provider: OAuth2Provider,
        title: String,
        icon: String,
        backgroundColor: Color,
        foregroundColor: Color
    ) -> some View {
        Button {
            signInWithOAuth2(provider: provider)
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(foregroundColor)

                Text(title)
                    .font(.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(foregroundColor)

                Spacer()

                if isAuthenticatingOAuth {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(foregroundColor)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .cornerRadius(CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(Color.borderPrimary, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .disabled(isAuthenticatingOAuth)
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

    @MainActor
    private func signInWithOAuth2(provider: OAuth2Provider) {
        isAuthenticatingOAuth = true

        Task { @MainActor in
            do {
                // Create OAuth2 manager
                let oauth2Manager = OAuth2Manager(provider: provider)

                // Start authorization flow
                Logger.info("Starting OAuth2 authorization for \(provider.name)", category: .email)
                let tokens = try await oauth2Manager.authorize()

                // Get user email from Google UserInfo API
                let userEmail = try await fetchUserEmail(accessToken: tokens.accessToken, provider: provider)

                // Create account with OAuth2
                Logger.info("Creating account for \(userEmail)", category: .email)

                let account = Account(
                    name: userEmail,
                    emailAddress: userEmail,
                    type: provider == .google ? .gmail : .outlook,
                    authType: .oauth2,
                    oauthProvider: provider.name,
                    imapHost: provider.imapConfig.host,
                    imapPort: provider.imapConfig.port,
                    imapUseTLS: true,
                    smtpHost: provider.smtpConfig.host,
                    smtpPort: provider.smtpConfig.port,
                    smtpUseTLS: true
                )

                // Set token expiration
                account.oauthTokenExpiration = tokens.expirationDate

                // Save tokens to keychain
                try KeychainManager.shared.saveOAuth2AccessToken(tokens.accessToken, for: account.keychainIdentifier)
                if let refreshToken = tokens.refreshToken {
                    try KeychainManager.shared.saveOAuth2RefreshToken(refreshToken, for: account.keychainIdentifier)
                }

                // Save account to SwiftData (must be on MainActor)
                modelContext.insert(account)
                try modelContext.save()

                Logger.info("Account created successfully with OAuth2", category: .email)

                // Sync IMAP folders
                Logger.info("Syncing IMAP folders...", category: .email)
                let accountManager = AccountManager(modelContext: modelContext)
                try await accountManager.syncFolders(for: account)

                Logger.info("Folder sync completed", category: .email)

                // Close the view
                isAuthenticatingOAuth = false
                dismiss()

            } catch {
                Logger.error("OAuth2 authentication failed: \(error)", category: .email)

                isAuthenticatingOAuth = false
                errorMessage = "Autenticazione fallita: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    /// Fetch user email from provider's UserInfo API
    private func fetchUserEmail(accessToken: String, provider: OAuth2Provider) async throws -> String {
        let userInfoURL: String
        switch provider {
        case .google:
            userInfoURL = "https://www.googleapis.com/oauth2/v2/userinfo"
        case .microsoft:
            userInfoURL = "https://graph.microsoft.com/v1.0/me"
        case .apple:
            userInfoURL = "https://appleid.apple.com/auth/userinfo"
        }

        var request = URLRequest(url: URL(string: userInfoURL)!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)

        // Decode response
        struct GoogleUserInfo: Codable {
            let email: String
        }

        struct MicrosoftUserInfo: Codable {
            let userPrincipalName: String
        }

        switch provider {
        case .google, .apple:
            let userInfo = try JSONDecoder().decode(GoogleUserInfo.self, from: data)
            return userInfo.email
        case .microsoft:
            let userInfo = try JSONDecoder().decode(MicrosoftUserInfo.self, from: data)
            return userInfo.userPrincipalName
        }
    }

    @MainActor
    private func testConnection() {
        isTestingConnection = true
        testError = nil

        Task {
            // Create account manager locally to avoid Sendable issues
            let accountManager = AccountManager(modelContext: modelContext)

            do {
                // Create temporary account for testing
                let tempAccount = Account(
                    name: displayName.isEmpty ? email : displayName,
                    emailAddress: email,
                    type: selectedPreset.type,
                    imapHost: selectedPreset.imapHost,
                    imapPort: selectedPreset.imapPort,
                    imapUseTLS: selectedPreset.imapUseTLS,
                    smtpHost: selectedPreset.smtpHost,
                    smtpPort: selectedPreset.smtpPort,
                    smtpUseTLS: selectedPreset.smtpUseTLS
                )

                // Save password temporarily
                try tempAccount.savePassword(password)

                // Test IMAP
                _ = try await accountManager.testIMAPConnection(for: tempAccount)

                // Test SMTP
                _ = try await accountManager.testSMTPConnection(for: tempAccount)

                // Cleanup temp password
                try? tempAccount.deletePassword()

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

    @MainActor
    private func saveAccount() {
        isSaving = true

        Task {
            // Create account manager locally to avoid Sendable issues
            let accountManager = AccountManager(modelContext: modelContext)

            do {
                let account = try await accountManager.addAccount(
                    email: email,
                    password: password,
                    preset: selectedPreset,
                    displayName: displayName.isEmpty ? nil : displayName
                )

                // Sync IMAP folders
                Logger.info("Syncing IMAP folders...", category: .email)
                try await accountManager.syncFolders(for: account)
                Logger.info("Folder sync completed", category: .email)

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
