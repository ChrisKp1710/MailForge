import SwiftUI
import SwiftData

// MARK: - Sidebar View

/// Sidebar with accounts and folders tree
struct SidebarView: View {

    // MARK: - Properties

    let accounts: [Account]

    @Binding var selectedAccount: Account?
    @Binding var selectedFolder: Folder?

    let onAddAccount: () -> Void

    // MARK: - State

    @State private var expandedAccounts: Set<Account.ID> = []

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Accounts & Folders
            if accounts.isEmpty {
                emptyState
            } else {
                accountsList
            }
        }
        .background(Color.backgroundPrimary)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Cartelle")
                .font(.headlineSmall)
                .foregroundColor(.textPrimary)

            Spacer()

            Button {
                onAddAccount()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(.brandPrimary)
            }
            .buttonStyle(.plain)
            .help("Aggiungi account")
        }
        .padding(Spacing.md)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "Nessun account",
            systemImage: "envelope.badge.shield.half.filled",
            description: Text("Aggiungi un account email per iniziare")
        )
    }

    // MARK: - Accounts List

    private var accountsList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.xs, pinnedViews: [.sectionHeaders]) {
                ForEach(accounts) { account in
                    accountSection(account)
                }
            }
            .padding(.vertical, Spacing.sm)
        }
    }

    // MARK: - Account Section

    private func accountSection(_ account: Account) -> some View {
        VStack(spacing: Spacing.xxs) {
            // Account header
            Button {
                withAnimation {
                    if expandedAccounts.contains(account.id) {
                        expandedAccounts.remove(account.id)
                    } else {
                        expandedAccounts.insert(account.id)
                        selectedAccount = account
                    }
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: account.type.icon)
                        .foregroundColor(.brandPrimary)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.name)
                            .font(.bodyMedium)
                            .foregroundColor(.textPrimary)

                        Text(account.emailAddress)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }

                    Spacer()

                    Image(systemName: expandedAccounts.contains(account.id) ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    selectedAccount?.id == account.id ?
                    Color.brandPrimary.opacity(0.1) : Color.clear
                )
                .cornerRadius(CornerRadius.sm)
            }
            .buttonStyle(.plain)

            // Folders (when expanded)
            if expandedAccounts.contains(account.id) {
                VStack(spacing: 2) {
                    ForEach(account.folders.sorted(by: { $0.name < $1.name })) { folder in
                        folderRow(folder)
                    }
                }
                .padding(.leading, Spacing.lg)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .onAppear {
            // Auto-expand first account
            if expandedAccounts.isEmpty, let firstAccount = accounts.first {
                expandedAccounts.insert(firstAccount.id)
            }
        }
    }

    // MARK: - Folder Row

    private func folderRow(_ folder: Folder) -> some View {
        Button {
            selectedFolder = folder
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: folderIcon(for: folder))
                    .foregroundColor(folderColor(for: folder))
                    .frame(width: 16)

                Text(folder.displayName)
                    .font(.bodySmall)
                    .foregroundColor(.textPrimary)

                Spacer()

                if folder.unreadCount > 0 {
                    Text("\(folder.unreadCount)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.brandPrimary)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                selectedFolder?.id == folder.id ?
                Color.brandPrimary.opacity(0.15) : Color.clear
            )
            .cornerRadius(CornerRadius.sm)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func folderIcon(for folder: Folder) -> String {
        switch folder.name.uppercased() {
        case "INBOX": return "tray.fill"
        case "SENT": return "paperplane.fill"
        case "DRAFTS": return "doc.text.fill"
        case "TRASH", "DELETED": return "trash.fill"
        case "SPAM", "JUNK": return "exclamationmark.octagon.fill"
        case "ARCHIVE": return "archivebox.fill"
        default: return "folder.fill"
        }
    }

    private func folderColor(for folder: Folder) -> Color {
        switch folder.name.uppercased() {
        case "INBOX": return .brandPrimary
        case "SENT": return .blue
        case "DRAFTS": return .orange
        case "TRASH", "DELETED": return .red
        case "SPAM", "JUNK": return .red
        case "ARCHIVE": return .gray
        default: return .textSecondary
        }
    }
}

// MARK: - Preview

#Preview {
    SidebarView(
        accounts: [],
        selectedAccount: .constant(nil),
        selectedFolder: .constant(nil),
        onAddAccount: {}
    )
    .frame(width: 250)
}
