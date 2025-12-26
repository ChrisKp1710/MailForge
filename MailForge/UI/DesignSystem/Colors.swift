import SwiftUI
import AppKit

/// MailForge Design System - Modern macOS Color Palette
/// Professional colors with vibrant materials that adapt to Light/Dark mode
extension Color {

    // MARK: - Brand Colors

    /// Primary brand color - macOS Blue
    static let brandPrimary = Color(light: Color(hex: "#007AFF"), dark: Color(hex: "#0A84FF"))

    /// Secondary brand color - Purple
    static let brandSecondary = Color(light: Color(hex: "#5856D6"), dark: Color(hex: "#5E5CE6"))

    /// Accent color - Orange
    static let brandAccent = Color(light: Color(hex: "#FF9500"), dark: Color(hex: "#FF9F0A"))

    // MARK: - Background Colors (Use Materials instead for modern look)

    /// Primary background - Transparent for materials
    static let backgroundPrimary = Color.clear

    /// Secondary background - Subtle gray
    static let backgroundSecondary = Color(light: Color(hex: "#F5F5F7"), dark: Color(hex: "#1E1E1E"))

    /// Tertiary background - Hover states
    static let backgroundTertiary = Color(light: Color(hex: "#E8E8ED"), dark: Color(hex: "#2A2A2A"))

    // MARK: - Text Colors

    /// Primary text - Main content
    static let textPrimary = Color.primary

    /// Secondary text - Supporting content
    static let textSecondary = Color.secondary

    /// Tertiary text - Disabled, placeholder
    static let textTertiary = Color(light: Color(hex: "#8E8E93"), dark: Color(hex: "#636366"))

    // MARK: - Border Colors

    /// Primary border - Dividers, separators
    static let borderPrimary = Color(light: Color.black.opacity(0.1), dark: Color.white.opacity(0.1))

    /// Secondary border - Subtle borders
    static let borderSecondary = Color(light: Color.black.opacity(0.05), dark: Color.white.opacity(0.05))

    // MARK: - Semantic Colors

    /// Success - Positive actions, confirmations
    static let semanticSuccess = Color(light: Color(hex: "#34C759"), dark: Color(hex: "#30D158"))

    /// Warning - Caution, important notices
    static let semanticWarning = Color(light: Color(hex: "#FF9500"), dark: Color(hex: "#FF9F0A"))

    /// Error - Errors, destructive actions
    static let semanticError = Color(light: Color(hex: "#FF3B30"), dark: Color(hex: "#FF453A"))

    /// Info - Informational messages
    static let semanticInfo = Color.brandPrimary

    // MARK: - Email Specific Colors

    /// Unread indicator - Badge for unread emails
    static let emailUnread = Color.brandPrimary

    /// Starred - Highlighted/favorited emails
    static let emailStarred = Color(light: Color(hex: "#FF9500"), dark: Color(hex: "#FF9F0A"))

    /// Read email - Dimmed text for read emails
    static let emailRead = Color.textSecondary
}

// MARK: - Color Helpers

extension Color {
    /// Initialize Color from hex string
    init(hex: String, alpha: Double = 1.0) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: alpha
        )
    }

    /// Create color that adapts to color scheme (macOS)
    init(light: Color, dark: Color) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS version using AppKit
        self.init(NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(dark)
            } else {
                return NSColor(light)
            }
        })
        #else
        // Fallback for other platforms
        self = light
        #endif
    }
}
