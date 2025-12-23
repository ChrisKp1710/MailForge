import Foundation
import OSLog

/// Centralized logging system using OSLog
final class Logger {

    // MARK: - Subsystems

    private static let subsystem = "com.mailforge.app"

    // MARK: - Categories

    enum Category: String {
        case app = "App"
        case email = "Email"
        case imap = "IMAP"
        case smtp = "SMTP"
        case database = "Database"
        case ui = "UI"
        case network = "Network"
        case keychain = "Keychain"
        case sync = "Sync"
        case pec = "PEC"

        var logger: os.Logger {
            return os.Logger(subsystem: Logger.subsystem, category: rawValue)
        }
    }

    // MARK: - Logging Methods

    /// Log debug message
    /// - Parameters:
    ///   - message: Message to log
    ///   - category: Log category
    ///   - file: Source file (auto-filled)
    ///   - function: Function name (auto-filled)
    ///   - line: Line number (auto-filled)
    static func debug(
        _ message: String,
        category: Category = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        category.logger.debug("[\(fileName):\(line)] \(function) - \(message)")
        #endif
    }

    /// Log info message
    /// - Parameters:
    ///   - message: Message to log
    ///   - category: Log category
    static func info(
        _ message: String,
        category: Category = .app
    ) {
        category.logger.info("\(message)")
    }

    /// Log warning message
    /// - Parameters:
    ///   - message: Message to log
    ///   - category: Log category
    ///   - file: Source file (auto-filled)
    ///   - line: Line number (auto-filled)
    static func warning(
        _ message: String,
        category: Category = .app,
        file: String = #file,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        category.logger.warning("[\(fileName):\(line)] ⚠️ \(message)")
    }

    /// Log error message
    /// - Parameters:
    ///   - message: Message to log
    ///   - error: Optional error object
    ///   - category: Log category
    ///   - file: Source file (auto-filled)
    ///   - line: Line number (auto-filled)
    static func error(
        _ message: String,
        error: Error? = nil,
        category: Category = .app,
        file: String = #file,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        if let error = error {
            category.logger.error("[\(fileName):\(line)] ❌ \(message) - Error: \(error.localizedDescription)")
        } else {
            category.logger.error("[\(fileName):\(line)] ❌ \(message)")
        }
    }

    /// Log fault/critical message
    /// - Parameters:
    ///   - message: Message to log
    ///   - category: Log category
    ///   - file: Source file (auto-filled)
    ///   - line: Line number (auto-filled)
    static func fault(
        _ message: String,
        category: Category = .app,
        file: String = #file,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        category.logger.fault("[\(fileName):\(line)] 🔥 \(message)")
    }

    // MARK: - Convenience Methods

    /// Log IMAP operation
    static func imap(_ message: String) {
        info(message, category: .imap)
    }

    /// Log SMTP operation
    static func smtp(_ message: String) {
        info(message, category: .smtp)
    }

    /// Log database operation
    static func database(_ message: String) {
        debug(message, category: .database)
    }

    /// Log sync operation
    static func sync(_ message: String) {
        info(message, category: .sync)
    }

    /// Log PEC operation
    static func pec(_ message: String) {
        info(message, category: .pec)
    }
}

// MARK: - Usage Examples

/*
 // Debug (only in DEBUG builds)
 Logger.debug("User tapped inbox button")

 // Info
 Logger.info("Email sync started", category: .sync)

 // Warning
 Logger.warning("Network connection unstable", category: .network)

 // Error
 Logger.error("Failed to fetch emails", error: fetchError, category: .imap)

 // Fault (critical error)
 Logger.fault("Database corruption detected", category: .database)

 // Convenience
 Logger.imap("Connected to IMAP server")
 Logger.smtp("Sent email successfully")
 Logger.sync("Sync completed: 50 messages")
 */
