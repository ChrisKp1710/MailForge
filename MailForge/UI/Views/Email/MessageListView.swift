import SwiftUI
import SwiftData

// MARK: - Message List View

/// Modern message list with search and filters
struct MessageListView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - Properties

    let folder: Folder?

    @Binding var selectedMessage: Message?

    // MARK: - State

    @State private var searchText = ""
    @State private var isLoading = false
    @State private var showUnreadOnly = false

    // MARK: - Queries

    @Query private var allMessages: [Message]

    // MARK: - Filtered Messages

    private var messages: [Message] {
        guard let folder = folder else { return [] }

        return allMessages
            .filter { $0.folder?.id == folder.id }
            .filter { message in
                if showUnreadOnly && message.isRead { return false }
                if !searchText.isEmpty {
                    return message.subject.localizedCaseInsensitiveContains(searchText) ||
                           message.from.localizedCaseInsensitiveContains(searchText)
                }
                return true
            }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Toolbar
            toolbar

            Divider()

            // Messages
            if folder == nil {
                noFolderSelected
            } else if messages.isEmpty {
                emptyState
            } else {
                messageList
            }
        }
        .background(Material.regular)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(folder?.name ?? "Nessuna cartella")
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let folder = folder {
                    Text("\(messages.count) messaggi")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.body)

                TextField("Cerca messaggi...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.body)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            // Filters
            Button(action: { showUnreadOnly.toggle() }) {
                Image(systemName: showUnreadOnly ? "envelope.badge.fill" : "envelope.badge")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(showUnreadOnly ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .help("Solo non letti")

            // Refresh
            Button(action: refreshMessages) {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Aggiorna")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - No Folder Selected

    private var noFolderSelected: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text("Seleziona una cartella")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Scegli una cartella dalla sidebar\nper visualizzare i messaggi")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: searchText.isEmpty ? "tray" : "magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "Nessun messaggio" : "Nessun risultato")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(searchText.isEmpty ?
                    "Questa cartella è vuota" :
                    "Nessun messaggio corrisponde a '\(searchText)'"
                )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    // MARK: - Message List

    private var messageList: some View {
        List(messages, selection: $selectedMessage) { message in
            MessageRow(message: message)
                .tag(message)
                .listRowSeparator(.visible, edges: .bottom)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .onTapGesture {
                    selectedMessage = message
                    markAsReadIfNeeded(message)
                }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Actions

    private func refreshMessages() {
        isLoading = true

        Task {
            // TODO: Implement sync with IMAP server
            try? await Task.sleep(for: .seconds(1))

            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func markAsReadIfNeeded(_ message: Message) {
        guard !message.isRead else { return }

        Task {
            try? await Task.sleep(for: .seconds(0.5))

            await MainActor.run {
                message.isRead = true
                try? modelContext.save()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MessageListView(
        folder: nil,
        selectedMessage: .constant(nil)
    )
    .modelContainer(for: [Message.self, Folder.self, Account.self, Attachment.self])
    .frame(width: 400, height: 600)
}
