import SwiftUI
import AppKit

/// MailForge Design System - Color Palette
/// Semantic colors that adapt to Light/Dark mode automatically
extension Color {

    // MARK: - Brand Colors

    /// Primary brand color - Used for main actions and highlights
    static let brandPrimary = Color("BrandPrimary", bundle: .main)
        .fallback(light: Color(hex: "#007AFF"), dark: Color(hex: "#0A84FF"))

    /// Secondary brand color - Used for secondary actions
    static let brandSecondary = Color("BrandSecondary", bundle: .main)
        .fallback(light: Color(hex: "#5856D6"), dark: Color(hex: "#5E5CE6"))

    /// Accent color - Used for important UI elements
    static let brandAccent = Color("BrandAccent", bundle: .main)
        .fallback(light: Color(hex: "#FF9500"), dark: Color(hex: "#FF9F0A"))

    // MARK: - Background Colors

    /// Primary background - Main app background
    static let backgroundPrimary = Color("BackgroundPrimary", bundle: .main)
        .fallback(light: Color(hex: "#FFFFFF"), dark: Color(hex: "#1C1C1E"))

    /// Secondary background - Cards, panels
    static let backgroundSecondary = Color("BackgroundSecondary", bundle: .main)
        .fallback(light: Color(hex: "#F2F2F7"), dark: Color(hex: "#2C2C2E"))

    /// Tertiary background - Hover states, subtle backgrounds
    static let backgroundTertiary = Color("BackgroundTertiary", bundle: .main)
        .fallback(light: Color(hex: "#E5E5EA"), dark: Color(hex: "#3A3A3C"))

    // MARK: - Text Colors

    /// Primary text - Main content
    static let textPrimary = Color("TextPrimary", bundle: .main)
        .fallback(light: Color(hex: "#000000"), dark: Color(hex: "#FFFFFF"))

    /// Secondary text - Supporting content
    static let textSecondary = Color("TextSecondary", bundle: .main)
        .fallback(light: Color(hex: "#3C3C43", alpha: 0.6), dark: Color(hex: "#EBEBF5", alpha: 0.6))

    /// Tertiary text - Disabled, placeholder
    static let textTertiary = Color("TextTertiary", bundle: .main)
        .fallback(light: Color(hex: "#3C3C43", alpha: 0.3), dark: Color(hex: "#EBEBF5", alpha: 0.3))

    // MARK: - Border Colors

    /// Primary border - Dividers, separators
    static let borderPrimary = Color("BorderPrimary", bundle: .main)
        .fallback(light: Color(hex: "#3C3C43", alpha: 0.2), dark: Color(hex: "#545458"))

    /// Secondary border - Subtle borders
    static let borderSecondary = Color("BorderSecondary", bundle: .main)
        .fallback(light: Color(hex: "#3C3C43", alpha: 0.1), dark: Color(hex: "#38383A"))

    // MARK: - Semantic Colors

    /// Success - Positive actions, confirmations
    static let semanticSuccess = Color("SemanticSuccess", bundle: .main)
        .fallback(light: Color(hex: "#34C759"), dark: Color(hex: "#32D74B"))

    /// Warning - Caution, important notices
    static let semanticWarning = Color("SemanticWarning", bundle: .main)
        .fallback(light: Color(hex: "#FF9500"), dark: Color(hex: "#FF9F0A"))

    /// Error - Errors, destructive actions
    static let semanticError = Color("SemanticError", bundle: .main)
        .fallback(light: Color(hex: "#FF3B30"), dark: Color(hex: "#FF453A"))

    /// Info - Informational messages
    static let semanticInfo = Color("SemanticInfo", bundle: .main)
        .fallback(light: Color(hex: "#007AFF"), dark: Color(hex: "#0A84FF"))

    // MARK: - Email Specific Colors

    /// Unread indicator - Badge for unread emails
    static let emailUnread = Color.brandPrimary

    /// Starred - Highlighted/favorited emails
    static let emailStarred = Color("EmailStarred", bundle: .main)
        .fallback(light: Color(hex: "#FF9500"), dark: Color(hex: "#FF9F0A"))

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

    /// Fallback for when asset catalog color is not available
    func fallback(light: Color, dark: Color) -> Color {
        // In production, this would check if asset exists
        // For now, return light/dark based on color scheme
        return Color(light: light, dark: dark)
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
