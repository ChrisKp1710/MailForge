import SwiftUI

// MARK: - Message Detail View

/// Detailed message view with full content
struct MessageDetailView: View {

    // MARK: - Properties

    let message: Message

    // MARK: - State

    @State private var showFullHeaders = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Header
                messageHeader

                Divider()

                // Actions
                actionsToolbar

                Divider()

                // Body
                messageBody

                // Attachments
                if message.hasAttachments && !message.attachments.isEmpty {
                    Divider()
                    attachmentsList
                }

                // PEC Info
                if message.isPEC {
                    Divider()
                    pecInfo
                }
            }
            .padding(Spacing.xl)
        }
        .background(Color.backgroundPrimary)
    }

    // MARK: - Message Header

    private var messageHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Subject
            HStack {
                Text(message.subject)
                    .font(.headlineLarge)
                    .foregroundColor(.textPrimary)

                Spacer()

                if message.isStarred {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
            }

            // From
            HStack(spacing: Spacing.xs) {
                Text("Da:")
                    .font(.labelMedium)
                    .foregroundColor(.textSecondary)

                Text(message.displayFrom)
                    .font(.bodyMedium)
                    .foregroundColor(.textPrimary)
            }

            // To
            if !message.to.isEmpty {
                HStack(spacing: Spacing.xs) {
                    Text("A:")
                        .font(.labelMedium)
                        .foregroundColor(.textSecondary)

                    Text(message.displayTo)
                        .font(.bodyMedium)
                        .foregroundColor(.textPrimary)
                }
            }

            // CC
            if !message.cc.isEmpty {
                HStack(spacing: Spacing.xs) {
                    Text("CC:")
                        .font(.labelMedium)
                        .foregroundColor(.textSecondary)

                    Text(message.cc.joined(separator: ", "))
                        .font(.bodyMedium)
                        .foregroundColor(.textPrimary)
                }
            }

            // Date
            HStack(spacing: Spacing.xs) {
                Text("Data:")
                    .font(.labelMedium)
                    .foregroundColor(.textSecondary)

                Text(message.date, style: .date)
                    .font(.bodyMedium)
                    .foregroundColor(.textPrimary)

                Text("alle")
                    .font(.bodyMedium)
                    .foregroundColor(.textSecondary)

                Text(message.date, style: .time)
                    .font(.bodyMedium)
                    .foregroundColor(.textPrimary)
            }
        }
    }

    // MARK: - Actions Toolbar

    private var actionsToolbar: some View {
        HStack(spacing: Spacing.md) {
            DSButton("Rispondi", icon: "arrowshape.turn.up.left", style: .secondary) {
                // TODO: Implement reply
            }

            DSButton("Rispondi a tutti", icon: "arrowshape.turn.up.left.2", style: .secondary) {
                // TODO: Implement reply all
            }

            DSButton("Inoltra", icon: "arrowshape.turn.up.right", style: .secondary) {
                // TODO: Implement forward
            }

            Spacer()

            Button {
                // TODO: Toggle star
            } label: {
                Image(systemName: message.isStarred ? "star.fill" : "star")
                    .foregroundColor(message.isStarred ? .yellow : .textSecondary)
            }
            .buttonStyle(.plain)

            Button {
                // TODO: Delete message
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.semanticError)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Message Body

    private var messageBody: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let bodySnippet = message.bodySnippet, !bodySnippet.isEmpty {
                Text(bodySnippet)
                    .font(.bodyMedium)
                    .foregroundColor(.textPrimary)
                    .textSelection(.enabled)
            } else {
                Text(message.preview)
                    .font(.bodyMedium)
                    .foregroundColor(.textPrimary)
                    .textSelection(.enabled)
            }

            // TODO: Render HTML body if available
            // TODO: Load full body from file if needed
        }
    }

    // MARK: - Attachments List

    private var attachmentsList: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Allegati (\(message.attachments.count))")
                .font(.labelLarge)
                .foregroundColor(.textSecondary)

            ForEach(message.attachments) { attachment in
                attachmentRow(attachment)
            }
        }
    }

    private func attachmentRow(_ attachment: Attachment) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: attachment.iconName)
                .foregroundColor(.brandPrimary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.filename)
                    .font(.bodySmall)
                    .foregroundColor(.textPrimary)

                Text(attachment.formattedSize)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            Button {
                // TODO: Download/open attachment
            } label: {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.brandPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.sm)
        .background(Color.backgroundSecondary)
        .cornerRadius(CornerRadius.md)
    }

    // MARK: - PEC Info

    private var pecInfo: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.semanticSuccess)

                Text("Email PEC Certificata")
                    .font(.labelLarge)
                    .foregroundColor(.textPrimary)
            }

            if let pecType = message.pecType {
                Text("Tipo: \(pecType.displayName)")
                    .font(.bodySmall)
                    .foregroundColor(.textSecondary)
            }

            // TODO: Show daticert.xml info
            // TODO: Add button to view certificate details
        }
        .padding(Spacing.md)
        .background(Color.semanticSuccess.opacity(0.1))
        .cornerRadius(CornerRadius.md)
    }
}

// MARK: - Preview

#Preview {
    MessageDetailView(
        message: Message(
            messageID: "1",
            uid: 1,
            subject: "Important Update",
            from: "sender@example.com",
            fromName: "John Doe",
            to: ["me@example.com"],
            cc: ["colleague@example.com"],
            date: Date(),
            preview: "This is a preview of the message content that will be displayed in the detail view.",
            isRead: true,
            hasAttachments: true,
            isPEC: true
        )
    )
    .frame(width: 600)
}
