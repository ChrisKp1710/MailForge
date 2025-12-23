import SwiftUI
import AppKit

/// MailForge Design System - Typography
/// Consistent font styles using SF Pro (system font)
extension Font {

    // MARK: - Display Fonts (Large headlines)

    /// Display Large - 48pt Bold
    static let displayLarge = Font.system(size: 48, weight: .bold)

    /// Display Medium - 36pt Bold
    static let displayMedium = Font.system(size: 36, weight: .bold)

    /// Display Small - 28pt Bold
    static let displaySmall = Font.system(size: 28, weight: .bold)

    // MARK: - Headline Fonts

    /// Headline Large - 24pt Semibold
    static let headlineLarge = Font.system(size: 24, weight: .semibold)

    /// Headline Medium - 20pt Semibold
    static let headlineMedium = Font.system(size: 20, weight: .semibold)

    /// Headline Small - 18pt Semibold
    static let headlineSmall = Font.system(size: 18, weight: .semibold)

    // MARK: - Body Fonts (Main content)

    /// Body Large - 17pt Regular
    static let bodyLarge = Font.system(size: 17, weight: .regular)

    /// Body Medium - 15pt Regular (Most common)
    static let bodyMedium = Font.system(size: 15, weight: .regular)

    /// Body Small - 13pt Regular
    static let bodySmall = Font.system(size: 13, weight: .regular)

    /// Body Emphasis - 15pt Semibold
    static let bodyEmphasis = Font.system(size: 15, weight: .semibold)

    // MARK: - Label Fonts (UI elements)

    /// Label Large - 14pt Medium
    static let labelLarge = Font.system(size: 14, weight: .medium)

    /// Label Medium - 12pt Medium
    static let labelMedium = Font.system(size: 12, weight: .medium)

    /// Label Small - 11pt Medium
    static let labelSmall = Font.system(size: 11, weight: .medium)

    // MARK: - Caption Fonts (Small text)

    /// Caption - 12pt Regular
    static let caption = Font.system(size: 12, weight: .regular)

    /// Caption Emphasis - 12pt Medium
    static let captionEmphasis = Font.system(size: 12, weight: .medium)

    // MARK: - Monospace Fonts (Code, technical)

    /// Code - 13pt Monospaced
    static let code = Font.system(size: 13, weight: .regular, design: .monospaced)
}

// MARK: - Text Styles with Line Height

/// Predefined text styles with proper line heights and letter spacing
struct TextStyle {

    // MARK: - Email Specific Styles

    /// Email subject line - 15pt Semibold
    static let emailSubject = TextStyle(
        font: .system(size: 15, weight: .semibold),
        lineHeight: 20,
        tracking: 0
    )

    /// Email sender - 13pt Medium
    static let emailSender = TextStyle(
        font: .system(size: 13, weight: .medium),
        lineHeight: 18,
        tracking: 0
    )

    /// Email preview - 13pt Regular
    static let emailPreview = TextStyle(
        font: .system(size: 13, weight: .regular),
        lineHeight: 18,
        tracking: 0
    )

    /// Email timestamp - 11pt Regular
    static let emailTimestamp = TextStyle(
        font: .system(size: 11, weight: .regular),
        lineHeight: 14,
        tracking: 0
    )

    /// Email body - 15pt Regular
    static let emailBody = TextStyle(
        font: .system(size: 15, weight: .regular),
        lineHeight: 22,
        tracking: 0
    )

    // MARK: - Properties

    let font: Font
    let lineHeight: CGFloat
    let tracking: CGFloat // Letter spacing

    // MARK: - View Modifier

    func apply() -> some ViewModifier {
        TextStyleModifier(style: self)
    }
}

// MARK: - Text Style Modifier

struct TextStyleModifier: ViewModifier {
    let style: TextStyle

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .lineSpacing(style.lineHeight - NSFont.systemFontSize)
            .tracking(style.tracking)
    }
}

// MARK: - View Extension for Easy Usage

extension View {
    /// Apply a text style to a view
    func textStyle(_ style: TextStyle) -> some View {
        self.modifier(style.apply())
    }
}

// MARK: - Preview Helper

#if DEBUG
struct TypographyPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Group {
                    Text("Display Fonts").font(.headlineSmall).foregroundColor(.textSecondary)
                    Text("Display Large").font(.displayLarge)
                    Text("Display Medium").font(.displayMedium)
                    Text("Display Small").font(.displaySmall)
                }

                Divider()

                Group {
                    Text("Headlines").font(.headlineSmall).foregroundColor(.textSecondary)
                    Text("Headline Large").font(.headlineLarge)
                    Text("Headline Medium").font(.headlineMedium)
                    Text("Headline Small").font(.headlineSmall)
                }

                Divider()

                Group {
                    Text("Body Text").font(.headlineSmall).foregroundColor(.textSecondary)
                    Text("Body Large - The quick brown fox jumps over the lazy dog").font(.bodyLarge)
                    Text("Body Medium - The quick brown fox jumps over the lazy dog").font(.bodyMedium)
                    Text("Body Small - The quick brown fox jumps over the lazy dog").font(.bodySmall)
                    Text("Body Emphasis - The quick brown fox jumps over the lazy dog").font(.bodyEmphasis)
                }

                Divider()

                Group {
                    Text("Labels").font(.headlineSmall).foregroundColor(.textSecondary)
                    Text("Label Large").font(.labelLarge)
                    Text("Label Medium").font(.labelMedium)
                    Text("Label Small").font(.labelSmall)
                }

                Divider()

                Group {
                    Text("Email Styles").font(.headlineSmall).foregroundColor(.textSecondary)
                    Text("Important Email Subject").textStyle(.emailSubject)
                    Text("sender@example.com").textStyle(.emailSender)
                    Text("This is a preview of the email content...").textStyle(.emailPreview)
                    Text("2 min ago").textStyle(.emailTimestamp)
                }
            }
            .padding()
        }
        .frame(width: 600, height: 800)
    }
}

#Preview {
    TypographyPreview()
}
#endif
