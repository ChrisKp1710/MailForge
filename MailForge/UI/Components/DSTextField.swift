import SwiftUI

/// Design System Text Field - Reusable input field with consistent styling
struct DSTextField: View {

    // MARK: - Properties

    let placeholder: String
    @Binding var text: String
    let icon: String?
    let style: TextFieldStyle
    let isSecure: Bool

    // MARK: - State

    @FocusState private var isFocused: Bool

    // MARK: - Initialization

    init(
        _ placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        style: TextFieldStyle = .default,
        isSecure: Bool = false
    ) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.style = style
        self.isSecure = isSecure
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: Spacing.inlineSpacing) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(isFocused ? .brandPrimary : .textSecondary)
                    .font(.bodyMedium)
            }

            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.bodyMedium)
                    .focused($isFocused)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.bodyMedium)
                    .focused($isFocused)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(style.backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(
                    isFocused ? style.focusedBorderColor : style.borderColor,
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .cornerRadius(CornerRadius.md)
    }

    // MARK: - Text Field Styles

    enum TextFieldStyle {
        case `default`
        case filled
        case outlined

        var backgroundColor: Color {
            switch self {
            case .default, .filled:
                return .backgroundSecondary
            case .outlined:
                return .clear
            }
        }

        var borderColor: Color {
            switch self {
            case .default:
                return .clear
            case .filled:
                return .clear
            case .outlined:
                return .borderPrimary
            }
        }

        var focusedBorderColor: Color {
            return .brandPrimary
        }
    }
}

// MARK: - Multi-line Text Editor

struct DSTextEditor: View {

    // MARK: - Properties

    let placeholder: String
    @Binding var text: String
    let minHeight: CGFloat

    // MARK: - State

    @FocusState private var isFocused: Bool

    // MARK: - Initialization

    init(
        _ placeholder: String,
        text: Binding<String>,
        minHeight: CGFloat = 100
    ) {
        self.placeholder = placeholder
        self._text = text
        self.minHeight = minHeight
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.textTertiary)
                    .font(.bodyMedium)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
            }

            // Text Editor
            TextEditor(text: $text)
                .font(.bodyMedium)
                .foregroundColor(.textPrimary)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .focused($isFocused)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xxs)
        }
        .frame(minHeight: minHeight)
        .padding(Spacing.xs)
        .background(Color.backgroundSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(
                    isFocused ? Color.brandPrimary : Color.clear,
                    lineWidth: isFocused ? 2 : 0
                )
        )
        .cornerRadius(CornerRadius.md)
    }
}

// MARK: - Search Field

struct DSSearchField: View {

    // MARK: - Properties

    @Binding var searchText: String
    let placeholder: String

    // MARK: - State

    @FocusState private var isFocused: Bool

    // MARK: - Initialization

    init(
        searchText: Binding<String>,
        placeholder: String = "Search"
    ) {
        self._searchText = searchText
        self.placeholder = placeholder
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: Spacing.inlineSpacing) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textSecondary)
                .font(.bodyMedium)

            TextField(placeholder, text: $searchText)
                .textFieldStyle(.plain)
                .font(.bodyMedium)
                .focused($isFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textSecondary)
                        .font(.bodyMedium)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color.backgroundSecondary)
        .cornerRadius(CornerRadius.md)
    }
}

// MARK: - Preview

#if DEBUG
struct DSTextFieldPreview: View {

    @State private var email = ""
    @State private var password = ""
    @State private var searchText = ""
    @State private var messageBody = ""
    @State private var outlinedText = ""

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text("Text Fields").font(.headlineLarge)

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Default Style").font(.headlineSmall).foregroundColor(.textSecondary)

                DSTextField("Email address", text: $email, icon: "envelope")

                DSTextField("Password", text: $password, icon: "lock", isSecure: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Search Field").font(.headlineSmall).foregroundColor(.textSecondary)

                DSSearchField(searchText: $searchText, placeholder: "Search emails...")
            }

            Divider()

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Outlined Style").font(.headlineSmall).foregroundColor(.textSecondary)

                DSTextField("Subject", text: $outlinedText, style: .outlined)
            }

            Divider()

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Text Editor").font(.headlineSmall).foregroundColor(.textSecondary)

                DSTextEditor("Write your message...", text: $messageBody, minHeight: 150)
            }
        }
        .padding(Spacing.xl)
        .frame(width: 500)
    }
}

#Preview {
    DSTextFieldPreview()
}
#endif
