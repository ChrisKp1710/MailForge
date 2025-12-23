import SwiftUI

/// Design System Card - Reusable card/panel component
struct DSCard<Content: View>: View {

    // MARK: - Properties

    let content: Content
    let style: CardStyle
    let padding: CGFloat

    // MARK: - Initialization

    init(
        style: CardStyle = .default,
        padding: CGFloat = Spacing.cardPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.content = content()
    }

    // MARK: - Body

    var body: some View {
        content
            .padding(padding)
            .background(style.backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(style.borderColor, lineWidth: style.borderWidth)
            )
            .cornerRadius(CornerRadius.md)
            .shadow(
                color: style.shadowColor,
                radius: style.shadowRadius,
                x: 0,
                y: style.shadowY
            )
    }

    // MARK: - Card Styles

    enum CardStyle {
        case `default`
        case elevated
        case outlined
        case flat

        var backgroundColor: Color {
            switch self {
            case .default, .elevated, .outlined:
                return .backgroundSecondary
            case .flat:
                return .backgroundPrimary
            }
        }

        var borderColor: Color {
            switch self {
            case .outlined:
                return .borderPrimary
            default:
                return .clear
            }
        }

        var borderWidth: CGFloat {
            switch self {
            case .outlined:
                return 1
            default:
                return 0
            }
        }

        var shadowColor: Color {
            switch self {
            case .elevated:
                return .black.opacity(0.1)
            default:
                return .clear
            }
        }

        var shadowRadius: CGFloat {
            switch self {
            case .elevated:
                return 8
            default:
                return 0
            }
        }

        var shadowY: CGFloat {
            switch self {
            case .elevated:
                return 2
            default:
                return 0
            }
        }
    }
}

// MARK: - List Item Card

struct DSListItem<Content: View>: View {

    // MARK: - Properties

    let content: Content
    let isSelected: Bool
    let action: () -> Void

    // MARK: - Initialization

    init(
        isSelected: Bool = false,
        action: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.action = action
        self.content = content()
    }

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            content
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isSelected ? Color.brandPrimary.opacity(0.1) : Color.clear)
                .cornerRadius(CornerRadius.sm)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Badge

struct DSBadge: View {

    // MARK: - Properties

    let text: String
    let style: BadgeStyle

    // MARK: - Initialization

    init(_ text: String, style: BadgeStyle = .default) {
        self.text = text
        self.style = style
    }

    // MARK: - Body

    var body: some View {
        Text(text)
            .font(.labelSmall)
            .foregroundColor(style.foregroundColor)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .background(style.backgroundColor)
            .cornerRadius(CornerRadius.sm)
    }

    // MARK: - Badge Styles

    enum BadgeStyle {
        case `default`
        case primary
        case success
        case warning
        case error
        case unread

        var backgroundColor: Color {
            switch self {
            case .default:
                return .backgroundTertiary
            case .primary:
                return .brandPrimary
            case .success:
                return .semanticSuccess
            case .warning:
                return .semanticWarning
            case .error:
                return .semanticError
            case .unread:
                return .emailUnread
            }
        }

        var foregroundColor: Color {
            switch self {
            case .default:
                return .textPrimary
            case .primary, .success, .warning, .error, .unread:
                return .white
            }
        }
    }
}

// MARK: - Divider

struct DSDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.borderPrimary)
            .frame(height: 1)
    }
}

// MARK: - Preview

#if DEBUG
struct DSCardPreview: View {
    @State private var selectedItem = 0

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Text("Card Components").font(.headlineLarge)

                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Card Styles").font(.headlineSmall).foregroundColor(.textSecondary)

                    DSCard(style: .default) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Default Card").font(.bodyEmphasis)
                            Text("Standard card with background").font(.bodySmall).foregroundColor(.textSecondary)
                        }
                    }

                    DSCard(style: .elevated) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Elevated Card").font(.bodyEmphasis)
                            Text("Card with shadow for depth").font(.bodySmall).foregroundColor(.textSecondary)
                        }
                    }

                    DSCard(style: .outlined) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Outlined Card").font(.bodyEmphasis)
                            Text("Card with border").font(.bodySmall).foregroundColor(.textSecondary)
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Badges").font(.headlineSmall).foregroundColor(.textSecondary)

                    HStack(spacing: Spacing.xs) {
                        DSBadge("Default", style: .default)
                        DSBadge("Primary", style: .primary)
                        DSBadge("Success", style: .success)
                        DSBadge("Warning", style: .warning)
                        DSBadge("Error", style: .error)
                        DSBadge("42", style: .unread)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("List Items").font(.headlineSmall).foregroundColor(.textSecondary)

                    VStack(spacing: Spacing.xxs) {
                        ForEach(0..<3, id: \.self) { index in
                            DSListItem(isSelected: selectedItem == index) {
                                selectedItem = index
                            } content: {
                                HStack {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(.brandPrimary)
                                    Text("List item \(index + 1)")
                                    Spacer()
                                    if index == 0 {
                                        DSBadge("New", style: .unread)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(Spacing.xl)
        }
        .frame(width: 500, height: 800)
    }
}

#Preview {
    DSCardPreview()
}
#endif
