import SwiftUI

/// Design System Button - Reusable button component with consistent styling
struct DSButton: View {

    // MARK: - Properties

    let title: String
    let icon: String?
    let style: ButtonStyle
    let size: ButtonSize
    let action: () -> Void

    // MARK: - Initialization

    init(
        _ title: String,
        icon: String? = nil,
        style: ButtonStyle = .primary,
        size: ButtonSize = .medium,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.action = action
    }

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.inlineSpacing) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(size.iconFont)
                }

                Text(title)
                    .font(size.font)
            }
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(maxWidth: size.fullWidth ? .infinity : nil)
            .background(style.backgroundColor)
            .foregroundColor(style.foregroundColor)
            .cornerRadius(CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(style.borderColor, lineWidth: style.borderWidth)
            )
        }
        .buttonStyle(.plain) // Remove default button styling
    }

    // MARK: - Button Styles

    enum ButtonStyle {
        case primary
        case secondary
        case tertiary
        case destructive
        case ghost

        var backgroundColor: Color {
            switch self {
            case .primary:
                return .brandPrimary
            case .secondary:
                return .backgroundSecondary
            case .tertiary:
                return .backgroundTertiary
            case .destructive:
                return .semanticError
            case .ghost:
                return .clear
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary, .destructive:
                return .white
            case .secondary, .tertiary, .ghost:
                return .textPrimary
            }
        }

        var borderColor: Color {
            switch self {
            case .ghost:
                return .borderPrimary
            default:
                return .clear
            }
        }

        var borderWidth: CGFloat {
            switch self {
            case .ghost:
                return 1
            default:
                return 0
            }
        }
    }

    // MARK: - Button Sizes

    enum ButtonSize {
        case small
        case medium
        case large

        var font: Font {
            switch self {
            case .small:
                return .labelMedium
            case .medium:
                return .bodyMedium
            case .large:
                return .bodyLarge
            }
        }

        var iconFont: Font {
            switch self {
            case .small:
                return .system(size: 12)
            case .medium:
                return .system(size: 14)
            case .large:
                return .system(size: 16)
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small:
                return Spacing.sm
            case .medium:
                return Spacing.md
            case .large:
                return Spacing.lg
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small:
                return Spacing.xs
            case .medium:
                return Spacing.sm
            case .large:
                return Spacing.md
            }
        }

        var fullWidth: Bool {
            false // Can be customized per instance if needed
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: Spacing.lg) {
        Text("Button Styles").font(.headlineLarge)

        VStack(spacing: Spacing.md) {
            Text("Primary").font(.headlineSmall).foregroundColor(.textSecondary)

            DSButton("Primary Button", icon: "paperplane.fill", style: .primary) {
                print("Primary tapped")
            }

            DSButton("Primary Large", style: .primary, size: .large) {
                print("Primary large tapped")
            }

            DSButton("Primary Small", style: .primary, size: .small) {
                print("Primary small tapped")
            }
        }

        Divider()

        VStack(spacing: Spacing.md) {
            Text("Secondary & Tertiary").font(.headlineSmall).foregroundColor(.textSecondary)

            DSButton("Secondary Button", icon: "star.fill", style: .secondary) {
                print("Secondary tapped")
            }

            DSButton("Tertiary Button", style: .tertiary) {
                print("Tertiary tapped")
            }
        }

        Divider()

        VStack(spacing: Spacing.md) {
            Text("Destructive & Ghost").font(.headlineSmall).foregroundColor(.textSecondary)

            DSButton("Delete", icon: "trash", style: .destructive) {
                print("Delete tapped")
            }

            DSButton("Ghost Button", icon: "ellipsis.circle", style: .ghost) {
                print("Ghost tapped")
            }
        }
    }
    .padding(Spacing.xl)
    .frame(width: 400)
}
#endif
