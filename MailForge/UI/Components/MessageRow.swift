import SwiftUI

// MARK: - Message Row

/// Modern message row component for list
struct MessageRow: View {

    // MARK: - Properties

    let message: Message

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Unread indicator
            Circle()
                .fill(message.isRead ? .clear : .blue)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Header: From + Date + Badges
                HStack(alignment: .center, spacing: 8) {
                    Text(message.displayFrom)
                        .font(.body.weight(message.isRead ? .regular : .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    // Badges
                    HStack(spacing: 6) {
                        if message.isPEC {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .symbolRenderingMode(.hierarchical)
                                .help("Email PEC")
                        }

                        if message.hasAttachments {
                            Image(systemName: "paperclip")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if message.isStarred {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }

                    Text(message.formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                // Subject
                Text(message.subject)
                    .font(.body.weight(message.isRead ? .regular : .medium))
                    .foregroundStyle(message.isRead ? .secondary : .primary)
                    .lineLimit(1)

                // Preview
                if !message.preview.isEmpty {
                    Text(message.preview)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(message.isRead ? .clear : Color.blue.opacity(0.03))
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        MessageRow(
            message: Message(
                messageID: "1",
                uid: 1,
                subject: "Important Meeting Tomorrow",
                from: "john.doe@example.com",
                fromName: "John Doe",
                to: ["me@example.com"],
                cc: [],
                date: Date(),
                preview: "Hi, just a reminder about our meeting tomorrow at 10 AM. Please bring the project documents.",
                isRead: false,
                hasAttachments: true,
                isPEC: false
            )
        )

        Divider()

        MessageRow(
            message: Message(
                messageID: "2",
                uid: 2,
                subject: "PEC: Documento ufficiale",
                from: "admin@pec.it",
                fromName: "Amministrazione",
                to: ["me@example.com"],
                cc: [],
                date: Date().addingTimeInterval(-86400),
                preview: "Questo è un messaggio certificato PEC con allegati importanti.",
                isRead: true,
                hasAttachments: true,
                isPEC: true
            )
        )

        Divider()

        MessageRow(
            message: Message(
                messageID: "3",
                uid: 3,
                subject: "Weekly Newsletter",
                from: "newsletter@company.com",
                fromName: "Company News",
                to: ["me@example.com"],
                cc: [],
                date: Date().addingTimeInterval(-172800),
                preview: "Check out this week's highlights and updates from the team.",
                isRead: true,
                isStarred: true,
                hasAttachments: false
            )
        )
    }
    .frame(width: 400)
}
