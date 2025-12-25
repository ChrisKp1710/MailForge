import SwiftUI

// MARK: - Message Row

/// Message row component for list view
struct MessageRow: View {

    // MARK: - Properties

    let message: Message
    let isSelected: Bool

    // MARK: - Body

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Unread indicator
            Circle()
                .fill(message.isRead ? Color.clear : Color.brandPrimary)
                .frame(width: 8, height: 8)

            // Content
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Header: From & Date
                HStack {
                    Text(message.displayFrom)
                        .font(message.isRead ? .bodyMedium : .bodyMediumBold)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    HStack(spacing: Spacing.xs) {
                        // PEC indicator
                        if message.isPEC {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundColor(.semanticSuccess)
                                .help("Email PEC")
                        }

                        // Attachment indicator
                        if message.hasAttachments {
                            Image(systemName: "paperclip")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }

                        // Star
                        if message.isStarred {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }

                        // Date
                        Text(message.formattedDate)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                }

                // Subject
                Text(message.subject)
                    .font(message.isRead ? .bodySmall : .bodySmallBold)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                // Preview
                if !message.preview.isEmpty {
                    Text(message.preview)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            isSelected ?
            Color.brandPrimary.opacity(0.1) :
            (message.isRead ? Color.clear : Color.backgroundSecondary)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Font Extensions

private extension Font {
    static let bodyMediumBold = Font.system(size: 13, weight: .semibold)
    static let bodySmallBold = Font.system(size: 12, weight: .semibold)
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        MessageRow(
            message: Message(
                messageID: "1",
                uid: 1,
                subject: "Important Update",
                from: "sender@example.com",
                fromName: "John Doe",
                to: ["me@example.com"],
                date: Date(),
                preview: "This is a preview of the message content...",
                isRead: false,
                hasAttachments: true
            ),
            isSelected: false
        )

        Divider()

        MessageRow(
            message: Message(
                messageID: "2",
                uid: 2,
                subject: "Meeting Tomorrow",
                from: "colleague@example.com",
                to: ["me@example.com"],
                date: Date().addingTimeInterval(-86400),
                preview: "Don't forget about our meeting tomorrow at 10 AM",
                isRead: true,
                isStarred: true
            ),
            isSelected: true
        )
    }
    .frame(width: 400)
}
