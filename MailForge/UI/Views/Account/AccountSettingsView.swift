import SwiftUI
import SwiftData

// MARK: - Account Settings View

/// View for managing account settings (edit, delete)
struct AccountSettingsView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Properties

    let account: Account

    // MARK: - State

    @State private var displayName: String
    @State private var password: String = ""
    @State private var showPasswordField: Bool = false

    @State private var showDeleteConfirmation: Bool = false
    @State private var isDeleting: Bool = false

    @State private var isSaving: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    // MARK: - Account Manager

    private var accountManager: AccountManager {
        AccountManager(modelContext: modelContext)
    }

    // MARK: - Initialization

    init(account: Account) {
        self.account = account
        _displayName = State(initialValue: account.name)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Account info
                    accountInfoSection

                    Divider()

                    // Settings
                    settingsSection

                    Divider()

                    // Server info (read-only)
                    serverInfoSection

                    Divider()

                    // Danger zone
                    dangerZoneSection
                }
                .padding(Spacing.xl)
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 600, height: 700)
        .background(Color.backgroundPrimary)
        .alert("Errore", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Elimina Account", isPresented: $showDeleteConfirmation) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Sei sicuro di voler eliminare l'account '\(account.emailAddress)'? Tutte le email e i dati associati verranno eliminati permanentemente.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Impostazioni Account")
                    .font(.headlineLarge)
                    .foregroundColor(.textPrimary)

                Text(account.emailAddress)
                    .font(.bodySmall)
                    .foregroundColor(.textSecondary)
            }

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

    // MARK: - Account Info Section

    private var accountInfoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Informazioni Account")
                .font(.headlineSmall)
                .foregroundColor(.textPrimary)

            // Account type
            HStack {
                Image(systemName: account.type.icon)
                    .foregroundColor(.brandPrimary)

                Text(account.type.displayName)
                    .font(.bodyMedium)
                    .foregroundColor(.textPrimary)

                Spacer()

                DSBadge(account.type.rawValue.uppercased(), style: .primary)
            }
            .padding(Spacing.md)
            .background(Color.backgroundSecondary)
            .cornerRadius(CornerRadius.md)

            // Email (read-only)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Email")
                    .font(.labelMedium)
                    .foregroundColor(.textSecondary)

                Text(account.emailAddress)
                    .font(.bodyMedium)
                    .foregroundColor(.textPrimary)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.backgroundSecondary)
            .cornerRadius(CornerRadius.md)
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Impostazioni")
                .font(.headlineSmall)
                .foregroundColor(.textPrimary)

            // Display name
            DSTextField("Nome visualizzato", text: $displayName, icon: "person")

            // Change password
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Button {
                    showPasswordField.toggle()
                } label: {
                    HStack {
                        Image(systemName: "key.fill")
                        Text(showPasswordField ? "Nascondi password" : "Cambia password")
                        Spacer()
                        Image(systemName: showPasswordField ? "chevron.up" : "chevron.down")
                    }
                    .font(.bodyMedium)
                    .foregroundColor(.textPrimary)
                    .padding(Spacing.md)
                    .background(Color.backgroundSecondary)
                    .cornerRadius(CornerRadius.md)
                }
                .buttonStyle(.plain)

                if showPasswordField {
                    DSTextField("Nuova password", text: $password, icon: "lock", isSecure: true)
                }
            }
        }
    }

    // MARK: - Server Info Section

    private var serverInfoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Configurazione Server")
                .font(.headlineSmall)
                .foregroundColor(.textPrimary)

            // IMAP
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text("IMAP")
                        .font(.labelLarge)
                        .foregroundColor(.textSecondary)

                    Spacer()

                    if account.imapUseTLS {
                        DSBadge("TLS", style: .success)
                    }
                }

                Text("\(account.imapHost):\(account.imapPort)")
                    .font(.code)
                    .foregroundColor(.textPrimary)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.backgroundSecondary)
            .cornerRadius(CornerRadius.md)

            // SMTP
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text("SMTP")
                        .font(.labelLarge)
                        .foregroundColor(.textSecondary)

                    Spacer()

                    if account.smtpUseTLS {
                        DSBadge("TLS", style: .success)
                    }
                }

                Text("\(account.smtpHost):\(account.smtpPort)")
                    .font(.code)
                    .foregroundColor(.textPrimary)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.backgroundSecondary)
            .cornerRadius(CornerRadius.md)
        }
    }

    // MARK: - Danger Zone Section

    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Zona Pericolo")
                .font(.headlineSmall)
                .foregroundColor(.semanticError)

            DSButton(
                "Elimina Account",
                icon: "trash.fill",
                style: .destructive
            ) {
                showDeleteConfirmation = true
            }
            .disabled(isDeleting)

            Text("L'eliminazione dell'account è permanente e rimuoverà tutte le email e i dati associati.")
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: Spacing.md) {
            DSButton("Annulla", style: .ghost) {
                dismiss()
            }

            Spacer()

            DSButton(
                isSaving ? "Salvataggio..." : "Salva Modifiche",
                icon: "checkmark.circle.fill",
                style: .primary
            ) {
                saveChanges()
            }
            .disabled(isSaving || !hasChanges)
        }
        .padding(Spacing.lg)
    }

    // MARK: - Computed Properties

    private var hasChanges: Bool {
        return displayName != account.name || !password.isEmpty
    }

    // MARK: - Actions

    private func saveChanges() {
        isSaving = true

        Task {
            do {
                try accountManager.updateAccount(
                    account,
                    displayName: displayName,
                    password: password.isEmpty ? nil : password
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

    private func deleteAccount() {
        isDeleting = true

        Task {
            do {
                try accountManager.deleteAccount(account)

                await MainActor.run {
                    dismiss()
                }

            } catch {
                await MainActor.run {
                    errorMessage = "Errore durante l'eliminazione: \(error.localizedDescription)"
                    showError = true
                    isDeleting = false
                }
            }
        }
    }
}

// MARK: - Preview
/*
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Account.self, Folder.self, Message.self, Attachment.self,
        configurations: config
    )

    let account = Account(
        name: "Test Account",
        emailAddress: "test@example.com",
        type: .imap,
        imapHost: "imap.example.com",
        imapPort: 993,
        imapUseTLS: true,
        smtpHost: "smtp.example.com",
        smtpPort: 587,
        smtpUseTLS: true
    )

    container.mainContext.insert(account)

    AccountSettingsView(account: account)
        .modelContainer(container)
}
*/
