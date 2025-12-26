import SwiftUI
import SwiftData

// MARK: - Sidebar View

/// Modern macOS-style sidebar with native List
struct SidebarView: View {

    // MARK: - Properties

    let accounts: [Account]

    @Binding var selectedAccount: Account?
    @Binding var selectedFolder: Folder?

    let onAddAccount: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            sidebarHeader

            Divider()

            // Content
            if accounts.isEmpty {
                emptyState
            } else {
                accountsList
            }
        }
        .background(Material.thin)
    }

    // MARK: - Header

    private var sidebarHeader: some View {
        HStack {
            Text("Cartelle")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            Button(action: onAddAccount) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .help("Aggiungi account")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text("Nessun account")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Aggiungi un account email\nper iniziare")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onAddAccount) {
                Label("Aggiungi Account", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    // MARK: - Accounts List

    private var accountsList: some View {
        List(selection: $selectedFolder) {
            ForEach(accounts) { account in
                Section {
                    ForEach(account.folders.sorted(by: { $0.name < $1.name })) { folder in
                        FolderRow(folder: folder)
                            .tag(folder)
                    }
                } header: {
                    AccountHeader(account: account, isSelected: selectedAccount?.id == account.id)
                        .onTapGesture {
                            withAnimation(.snappy(duration: 0.2)) {
                                selectedAccount = account
                                if selectedFolder == nil || selectedFolder?.account?.id != account.id {
                                    selectedFolder = account.folders.first(where: { $0.name == "INBOX" })
                                        ?? account.folders.first
                                }
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Account Header

private struct AccountHeader: View {
    let account: Account
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: account.type.icon)
                .foregroundStyle(.blue)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Text(account.emailAddress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Folder Row

private struct FolderRow: View {
    let folder: Folder

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: folderIcon)
                .foregroundStyle(folderColor)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18)

            Text(folder.name)
                .font(.body)

            Spacer()

            if folder.unreadCount > 0 {
                Text("\(folder.unreadCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue, in: Capsule())
            }
        }
        .contentShape(Rectangle())
    }

    private var folderIcon: String {
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

    private var folderColor: Color {
        switch folder.name.uppercased() {
        case "INBOX": return .blue
        case "SENT": return .blue
        case "DRAFTS": return .orange
        case "TRASH", "DELETED": return .red
        case "SPAM", "JUNK": return .red
        case "ARCHIVE": return .gray
        default: return .secondary
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
    .frame(width: 250, height: 600)
}
