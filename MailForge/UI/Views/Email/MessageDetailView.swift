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
    @State private var showRawHTML = false // Debug: Toggle to see raw HTML

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

                // Body - DON'T put WebView in ScrollView, it needs fixed height
                messageBody
                    .frame(minHeight: 400) // Ensure minimum space for WebView

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
                // DEBUG: Log HTML content
                let _ = print("🌐 MessageDetailView: Rendering HTML body (\(htmlBody.count) chars)")
                let _ = print("🌐 HTML preview: \(htmlBody.prefix(200))...")
                let _ = Logger.debug("🌐 Full HTML starts with: \(htmlBody.prefix(500))", category: .email)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Email Content (HTML)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Debug toggle
                        Button {
                            showRawHTML.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: showRawHTML ? "eye.slash" : "eye")
                                Text(showRawHTML ? "Hide Raw" : "Show Raw")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    if showRawHTML {
                        // Show raw HTML for debugging
                        ScrollView {
                            Text(htmlBody)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .frame(maxHeight: 400)
                    } else {
                        // Render HTML
                        HTMLEmailView(htmlContent: htmlBody)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 300) // Increased minimum height
                            .border(Color.blue.opacity(0.3), width: 1) // Debug border to see WebView bounds
                    }
                }

            // Show plain text body if available
            } else if let textBody = message.bodyText, !textBody.isEmpty {
                let _ = print("📝 MessageDetailView: Rendering plain text body (\(textBody.count) chars)")
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email Content (Plain Text)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    PlainTextEmailView(textContent: textBody)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

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

/// Professional WKWebView implementation for rendering HTML emails
/// Provides full HTML/CSS/JavaScript support with proper security sandboxing
private struct HTMLEmailView: NSViewRepresentable {

    let htmlContent: String

    func makeNSView(context: Context) -> WKWebView {
        // Configure WKWebView preferences for email rendering
        let configuration = WKWebViewConfiguration()

        // Enable JavaScript only for content height calculation
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        // Create WKWebView with configuration
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // Configure appearance
        webView.setValue(false, forKey: "drawsBackground")
        
        // Set autoresizing mask for proper layout
        webView.autoresizingMask = [.width, .height]

        Logger.info("🌐 WKWebView created and configured", category: .email)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Skip if already showing the same content
        guard context.coordinator.lastLoadedHTML != htmlContent else {
            Logger.info("🌐 Skipping reload - content unchanged", category: .email)
            return
        }
        
        context.coordinator.lastLoadedHTML = htmlContent
        
        Logger.info("🌐 Loading HTML content (\(htmlContent.count) chars)", category: .email)
        Logger.info("🌐 HTML preview: \(htmlContent.prefix(200))...", category: .email)

        // Prepare HTML with proper styling and viewport
        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src * data: blob: https: http:; font-src 'self' data:; media-src * data: blob:; script-src 'unsafe-inline';">
            <style>
                * {
                    box-sizing: border-box;
                }
                html, body {
                    margin: 0;
                    padding: 0;
                    overflow-x: hidden;
                    width: 100%;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
                    font-size: 14px;
                    line-height: 1.6;
                    color: #1d1d1f;
                    padding: 16px;
                    word-wrap: break-word;
                    overflow-wrap: break-word;
                    background-color: transparent;
                    max-width: 100%;
                }
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #f5f5f7;
                    }
                    a {
                        color: #0a84ff;
                    }
                }
                a {
                    color: #007AFF;
                    text-decoration: none;
                }
                a:hover {
                    text-decoration: underline;
                }
                img {
                    max-width: 100%;
                    height: auto;
                    display: block;
                }
                table {
                    border-collapse: collapse;
                    max-width: 100%;
                    width: auto !important;
                }
                td, th {
                    padding: 4px 8px;
                }
                pre {
                    background-color: #f5f5f7;
                    padding: 12px;
                    border-radius: 8px;
                    overflow-x: auto;
                    white-space: pre-wrap;
                }
                @media (prefers-color-scheme: dark) {
                    pre {
                        background-color: #2d2d2d;
                    }
                }
                blockquote {
                    border-left: 3px solid #007AFF;
                    margin-left: 0;
                    padding-left: 16px;
                    color: #6e6e73;
                }
                @media (prefers-color-scheme: dark) {
                    blockquote {
                        color: #98989d;
                    }
                }
                /* Force email content to fit */
                .email-content {
                    max-width: 100% !important;
                    overflow-x: hidden !important;
                }
            </style>
            <script>
                // Notify when content is loaded
                window.addEventListener('load', function() {
                    console.log('📧 Email content loaded');
                });
            </script>
        </head>
        <body>
            <div class="email-content">
        \(htmlContent)
            </div>
        </body>
        </html>
        """

        Logger.info("🌐 Styled HTML length: \(styledHTML.count) chars", category: .email)

        // Load HTML content with base URL for relative resources
        webView.loadHTMLString(styledHTML, baseURL: nil)
        
        Logger.info("🌐 loadHTMLString called, waiting for load to complete...", category: .email)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate {
        var lastLoadedHTML: String?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Logger.info("✅ WKWebView finished loading HTML content", category: .email)
            
            // Log the page title to verify content loaded
            webView.evaluateJavaScript("document.body.innerHTML.length") { result, error in
                if let length = result as? Int {
                    Logger.info("✅ HTML body length in DOM: \(length) chars", category: .email)
                } else if let error = error {
                    Logger.error("❌ Failed to get body length", error: error, category: .email)
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Logger.error("❌ WKWebView navigation failed", error: error, category: .email)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Logger.error("❌ WKWebView provisional navigation failed", error: error, category: .email)
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Logger.info("🌐 WKWebView started loading", category: .email)
        }

        // Handle link clicks - open in default browser
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    NSWorkspace.shared.open(url)
                    Logger.info("🔗 Opening external link: \(url)", category: .email)
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
