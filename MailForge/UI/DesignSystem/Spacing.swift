import SwiftUI

/// MailForge Design System - Spacing System
/// 4pt grid system for consistent spacing throughout the app
enum Spacing {

    // MARK: - Base Spacing (4pt grid)

    /// 4pt - Minimal spacing (tight layouts)
    static let xxs: CGFloat = 4

    /// 8pt - Small spacing (compact elements)
    static let xs: CGFloat = 8

    /// 12pt - Medium-small spacing
    static let sm: CGFloat = 12

    /// 16pt - Medium spacing (default for most elements)
    static let md: CGFloat = 16

    /// 24pt - Large spacing (sections)
    static let lg: CGFloat = 24

    /// 32pt - Extra large spacing (major sections)
    static let xl: CGFloat = 32

    /// 48pt - 2X large spacing (page sections)
    static let xxl: CGFloat = 48

    /// 64pt - 3X large spacing (major page divisions)
    static let xxxl: CGFloat = 64

    // MARK: - Semantic Spacing

    /// Padding for cards and panels
    static let cardPadding: CGFloat = md // 16pt

    /// Spacing between list items
    static let listItemSpacing: CGFloat = xs // 8pt

    /// Spacing between sections
    static let sectionSpacing: CGFloat = xl // 32pt

    /// Inline spacing (between icons and text)
    static let inlineSpacing: CGFloat = xs // 8pt

    /// Button padding (horizontal)
    static let buttonPaddingHorizontal: CGFloat = md // 16pt

    /// Button padding (vertical)
    static let buttonPaddingVertical: CGFloat = sm // 12pt

    // MARK: - Email Specific Spacing

    /// Spacing in email list rows
    static let emailRowPadding: CGFloat = sm // 12pt

    /// Spacing between email header and body
    static let emailHeaderBodySpacing: CGFloat = lg // 24pt

    /// Spacing in email detail view
    static let emailDetailPadding: CGFloat = xl // 32pt
}

// MARK: - Corner Radius

enum CornerRadius {

    /// Small radius - 4pt (tight elements, badges)
    static let sm: CGFloat = 4

    /// Medium radius - 8pt (buttons, cards)
    static let md: CGFloat = 8

    /// Large radius - 12pt (panels, dialogs)
    static let lg: CGFloat = 12

    /// Extra large radius - 16pt (major UI elements)
    static let xl: CGFloat = 16

    /// Full rounded - 999pt (pills, avatars)
    static let full: CGFloat = 999
}

// MARK: - View Extensions for Easy Usage

extension View {

    // MARK: - Padding Shortcuts

    /// Apply standard card padding (16pt all sides)
    func cardPadding() -> some View {
        self.padding(Spacing.cardPadding)
    }

    /// Apply email row padding (12pt vertical, 16pt horizontal)
    func emailRowPadding() -> some View {
        self.padding(.vertical, Spacing.emailRowPadding)
            .padding(.horizontal, Spacing.md)
    }

    /// Apply email detail padding (32pt)
    func emailDetailPadding() -> some View {
        self.padding(Spacing.emailDetailPadding)
    }

    // MARK: - Corner Radius Shortcuts

    /// Apply medium corner radius (8pt)
    func cornerRadius() -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    /// Apply custom corner radius from design system
    func cornerRadius(_ radius: CGFloat) -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

// MARK: - Edge Insets Helpers

extension EdgeInsets {

    /// Standard card insets (16pt all sides)
    static let card = EdgeInsets(
        top: Spacing.cardPadding,
        leading: Spacing.cardPadding,
        bottom: Spacing.cardPadding,
        trailing: Spacing.cardPadding
    )

    /// Email row insets (12pt vertical, 16pt horizontal)
    static let emailRow = EdgeInsets(
        top: Spacing.emailRowPadding,
        leading: Spacing.md,
        bottom: Spacing.emailRowPadding,
        trailing: Spacing.md
    )

    /// Email detail insets (32pt)
    static let emailDetail = EdgeInsets(
        top: Spacing.emailDetailPadding,
        leading: Spacing.emailDetailPadding,
        bottom: Spacing.emailDetailPadding,
        trailing: Spacing.emailDetailPadding
    )

    /// Section insets (32pt top, 16pt sides)
    static let section = EdgeInsets(
        top: Spacing.sectionSpacing,
        leading: Spacing.md,
        bottom: Spacing.sectionSpacing,
        trailing: Spacing.md
    )
}

// MARK: - Preview Helper

#if DEBUG
struct SpacingPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Spacing System - 4pt Grid").font(.headlineLarge)

                Group {
                    Text("Base Spacing").font(.headlineSmall).foregroundColor(.textSecondary)

                    HStack(spacing: Spacing.xs) {
                        spacingBox(Spacing.xxs, "XXS\n4pt")
                        spacingBox(Spacing.xs, "XS\n8pt")
                        spacingBox(Spacing.sm, "SM\n12pt")
                        spacingBox(Spacing.md, "MD\n16pt")
                    }

                    HStack(spacing: Spacing.xs) {
                        spacingBox(Spacing.lg, "LG\n24pt")
                        spacingBox(Spacing.xl, "XL\n32pt")
                        spacingBox(Spacing.xxl, "XXL\n48pt")
                    }
                }

                Divider()

                Group {
                    Text("Corner Radius").font(.headlineSmall).foregroundColor(.textSecondary)

                    HStack(spacing: Spacing.md) {
                        cornerRadiusBox(CornerRadius.sm, "SM\n4pt")
                        cornerRadiusBox(CornerRadius.md, "MD\n8pt")
                        cornerRadiusBox(CornerRadius.lg, "LG\n12pt")
                        cornerRadiusBox(CornerRadius.xl, "XL\n16pt")
                    }
                }

                Divider()

                Group {
                    Text("Semantic Usage").font(.headlineSmall).foregroundColor(.textSecondary)

                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Card Padding Example")
                            .cardPadding()
                            .background(Color.backgroundSecondary)
                            .cornerRadius(CornerRadius.md)

                        Text("Email Row Padding Example")
                            .emailRowPadding()
                            .background(Color.backgroundSecondary)
                            .cornerRadius(CornerRadius.sm)
                    }
                }
            }
            .padding(Spacing.xl)
        }
        .frame(width: 700, height: 800)
    }

    private func spacingBox(_ size: CGFloat, _ label: String) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.brandPrimary.opacity(0.2))
                .frame(width: size, height: size)
                .overlay(
                    Rectangle()
                        .stroke(Color.brandPrimary, lineWidth: 1)
                )

            Text(label)
                .font(.caption)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
                .frame(width: 50)
                .offset(y: size / 2 + 20)
        }
    }

    private func cornerRadiusBox(_ radius: CGFloat, _ label: String) -> some View {
        VStack(spacing: Spacing.xs) {
            RoundedRectangle(cornerRadius: radius)
                .fill(Color.brandPrimary.opacity(0.2))
                .frame(width: 80, height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(Color.brandPrimary, lineWidth: 2)
                )

            Text(label)
                .font(.caption)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    SpacingPreview()
}
#endif
