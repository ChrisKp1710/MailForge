import SwiftUI
import SwiftData

// MARK: - Message List View

/// Message list view with search and filters
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
        .background(Color.backgroundPrimary)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(folder?.displayName ?? "Nessuna cartella")
                    .font(.headlineSmall)
                    .foregroundColor(.textPrimary)

                if let folder = folder {
                    Text("\(messages.count) messaggi")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(Spacing.md)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: Spacing.md) {
            // Search
            HStack(spacing: Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.textSecondary)
                    .font(.bodySmall)

                TextField("Cerca messaggi...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.bodySmall)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(Color.backgroundSecondary)
            .cornerRadius(CornerRadius.sm)

            // Filters
            Button {
                showUnreadOnly.toggle()
            } label: {
                Image(systemName: showUnreadOnly ? "envelope.badge.fill" : "envelope.badge")
                    .foregroundColor(showUnreadOnly ? .brandPrimary : .textSecondary)
            }
            .buttonStyle(.plain)
            .help("Solo non letti")

            // Refresh
            Button {
                refreshMessages()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Aggiorna")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - No Folder Selected

    private var noFolderSelected: some View {
        ContentUnavailableView(
            "Seleziona una cartella",
            systemImage: "folder",
            description: Text("Scegli una cartella dalla sidebar per visualizzare i messaggi")
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            searchText.isEmpty ? "Nessun messaggio" : "Nessun risultato",
            systemImage: searchText.isEmpty ? "tray" : "magnifyingglass",
            description: Text(searchText.isEmpty ?
                "Questa cartella è vuota" :
                "Nessun messaggio corrisponde alla ricerca '\(searchText)'"
            )
        )
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(messages) { message in
                    MessageRow(
                        message: message,
                        isSelected: selectedMessage?.id == message.id
                    )
                    .onTapGesture {
                        selectedMessage = message
                        markAsReadIfNeeded(message)
                    }

                    Divider()
                }
            }
        }
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
    .frame(width: 400)
}
