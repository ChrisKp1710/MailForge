import SwiftUI
import WebKit

// MARK: - Message Detail View

/// Detailed message view with full content
struct MessageDetailView: View {

    // MARK: - Properties

    let message: Message

    // MARK: - State

    @State private var showFullHeaders = false
    @State private var isLoadingBody = false
    @State private var bodyLoadError: Error?

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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
            .padding(24)
        }
        .background(Material.regular)
    }

    // MARK: - Message Header

    private var messageHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Subject
            HStack {
                Text(message.subject)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                if message.isStarred {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }
            }

            // From
            HStack(spacing: 6) {
                Text("Da:")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(message.displayFrom)
                    .font(.body)
                    .foregroundStyle(.primary)
            }

            // To
            if !message.to.isEmpty {
                HStack(spacing: 6) {
                    Text("A:")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(message.displayTo)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }

            // CC
            if !message.cc.isEmpty {
                HStack(spacing: 6) {
                    Text("CC:")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(message.cc.joined(separator: ", "))
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }

            // Date
            HStack(spacing: 6) {
                Text("Data:")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(message.date, style: .date)
                    .font(.body)
                    .foregroundStyle(.primary)

                Text("alle")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Text(message.date, style: .time)
                    .font(.body)
                    .foregroundStyle(.primary)
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
            // Show HTML body if available
            if let htmlBody = message.bodyHTML, !htmlBody.isEmpty {
                HTMLEmailView(htmlContent: htmlBody)
                    .frame(minHeight: 400)

            // Show plain text body if available
            } else if let textBody = message.bodyText, !textBody.isEmpty {
                PlainTextEmailView(textContent: textBody)
                    .frame(minHeight: 400)

            // Show loading indicator while fetching
            } else if isLoadingBody {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Caricamento contenuto email...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)

            // Show error if body load failed
            } else if let error = bodyLoadError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)

                    Text("Impossibile caricare il contenuto dell'email")
                        .font(.body.weight(.medium))

                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Riprova") {
                        Task {
                            await loadMessageBody()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, minHeight: 200)

            // Show preview/snippet if body not loaded yet
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if let bodySnippet = message.bodySnippet, !bodySnippet.isEmpty {
                        Text(bodySnippet)
                            .font(.bodyMedium)
                            .foregroundColor(.textSecondary)
                            .textSelection(.enabled)
                    } else {
                        Text(message.preview)
                            .font(.bodyMedium)
                            .foregroundColor(.textSecondary)
                            .textSelection(.enabled)
                    }

                    Text("Tocca per caricare il contenuto completo")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 8)
                }
                .onTapGesture {
                    Task {
                        await loadMessageBody()
                    }
                }
            }
        }
        .task {
            // Auto-load body when view appears
            if message.bodyHTML == nil && message.bodyText == nil && !isLoadingBody {
                await loadMessageBody()
            }
        }
    }

    // MARK: - Load Message Body

    /// Load full message body from server
    private func loadMessageBody() async {
        isLoadingBody = true
        bodyLoadError = nil

        do {
            let accountManager = AccountManager(modelContext: modelContext)
            try await accountManager.fetchMessageBody(for: message)

            Logger.info("Message body loaded successfully", category: .email)
        } catch {
            Logger.error("Failed to load message body", error: error, category: .email)
            bodyLoadError = error
        }

        isLoadingBody = false
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

// MARK: - HTML Email View

/// WebView for rendering HTML email content
private struct HTMLEmailView: NSViewRepresentable {

    let htmlContent: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator

        // Disable user interaction features for security
        webView.configuration.preferences.javaScriptEnabled = false
        webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Wrap HTML content with basic styling for better display
        let wrappedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    font-size: 14px;
                    line-height: 1.6;
                    color: #333;
                    margin: 0;
                    padding: 16px;
                    word-wrap: break-word;
                }
                img {
                    max-width: 100%;
                    height: auto;
                }
                a {
                    color: #007AFF;
                    text-decoration: none;
                }
                a:hover {
                    text-decoration: underline;
                }
                pre {
                    background-color: #f5f5f5;
                    padding: 12px;
                    border-radius: 4px;
                    overflow-x: auto;
                }
                code {
                    background-color: #f5f5f5;
                    padding: 2px 6px;
                    border-radius: 3px;
                    font-family: 'SF Mono', Monaco, Consolas, monospace;
                }
                blockquote {
                    border-left: 4px solid #ddd;
                    margin-left: 0;
                    padding-left: 16px;
                    color: #666;
                }
            </style>
        </head>
        <body>
        \(htmlContent)
        </body>
        </html>
        """

        webView.loadHTMLString(wrappedHTML, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        // Intercept link clicks to open in default browser instead of in webview
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    NSWorkspace.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}

/// Plain text email view (for non-HTML emails)
private struct PlainTextEmailView: View {
    let textContent: String

    var body: some View {
        ScrollView {
            Text(textContent)
                .font(.system(.body, design: .default))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
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
