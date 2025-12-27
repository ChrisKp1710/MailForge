import Foundation

/// Centralized error handling for MailForge
protocol AppErrorProtocol: LocalizedError {
    var title: String { get }
    var message: String { get }
    var recoverySuggestion: String? { get }
    var category: Logger.Category { get }
    var severity: ErrorSeverity { get }
}

extension AppErrorProtocol {
    var errorDescription: String? { message }
    var failureReason: String? { message }
}

// MARK: - Error Severity

enum ErrorSeverity {
    case low        // Informational, can be ignored
    case medium     // Warning, should be addressed
    case high       // Error, requires user action
    case critical   // Fatal error, app cannot continue
}

// MARK: - Account Errors

enum AccountError: AppErrorProtocol {
    case invalidEmailAddress
    case invalidCredentials
    case accountAlreadyExists
    case accountNotFound
    case missingIMAPSettings
    case missingSMTPSettings
    case passwordNotFound(emailAddress: String)
    case invalidAccount

    var title: String {
        return "Account Error"
    }

    var message: String {
        switch self {
        case .invalidEmailAddress:
            return "The email address format is invalid"
        case .invalidCredentials:
            return "Invalid username or password"
        case .accountAlreadyExists:
            return "An account with this email address already exists"
        case .accountNotFound:
            return "Account not found"
        case .missingIMAPSettings:
            return "IMAP server settings are missing or incomplete"
        case .missingSMTPSettings:
            return "SMTP server settings are missing or incomplete"
        case .passwordNotFound(let emailAddress):
            return "Password not found for account \(emailAddress)"
        case .invalidAccount:
            return "Account configuration is invalid"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidEmailAddress:
            return "Please enter a valid email address (e.g., name@example.com)"
        case .invalidCredentials:
            return "Please verify your username and password and try again"
        case .accountAlreadyExists:
            return "Please use a different email address or update the existing account"
        case .accountNotFound:
            return "Please check the account exists and try again"
        case .missingIMAPSettings:
            return "Please provide IMAP server host and port"
        case .missingSMTPSettings:
            return "Please provide SMTP server host and port"
        case .passwordNotFound:
            return "Please try adding the account again"
        case .invalidAccount:
            return "Please check the account type and OAuth provider settings"
        }
    }

    var category: Logger.Category { .app }
    var severity: ErrorSeverity { .high }
}

// MARK: - IMAP Errors

enum IMAPError: AppErrorProtocol {
    case connectionFailed(host: String, port: Int)
    case authenticationFailed
    case folderNotFound(name: String)
    case messageFetchFailed
    case timeout
    case networkUnavailable
    case serverError(message: String)
    case tlsError

    var title: String {
        return "IMAP Error"
    }

    var message: String {
        switch self {
        case .connectionFailed(let host, let port):
            return "Failed to connect to IMAP server \(host):\(port)"
        case .authenticationFailed:
            return "IMAP authentication failed"
        case .folderNotFound(let name):
            return "Folder '\(name)' not found on server"
        case .messageFetchFailed:
            return "Failed to fetch messages from server"
        case .timeout:
            return "IMAP connection timed out"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .serverError(let message):
            return "IMAP server error: \(message)"
        case .tlsError:
            return "TLS/SSL connection failed"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .connectionFailed:
            return "Check your internet connection and server settings"
        case .authenticationFailed:
            return "Verify your username and password"
        case .folderNotFound:
            return "The folder may have been deleted or renamed on the server"
        case .messageFetchFailed:
            return "Try refreshing or check your connection"
        case .timeout:
            return "Check your internet connection and try again"
        case .networkUnavailable:
            return "Please connect to the internet and try again"
        case .serverError:
            return "Contact your email provider for assistance"
        case .tlsError:
            return "Check SSL/TLS settings or contact your email provider"
        }
    }

    var category: Logger.Category { .imap }
    var severity: ErrorSeverity {
        switch self {
        case .networkUnavailable, .timeout:
            return .medium
        case .folderNotFound:
            return .low
        default:
            return .high
        }
    }
}

// MARK: - SMTP Errors

enum SMTPError: AppErrorProtocol {
    case connectionFailed(host: String, port: Int)
    case authenticationFailed
    case sendFailed(reason: String)
    case recipientRejected(email: String)
    case messageTooLarge
    case timeout
    case networkUnavailable
    case tlsError
    case serverError(message: String)

    var title: String {
        return "SMTP Error"
    }

    var message: String {
        switch self {
        case .connectionFailed(let host, let port):
            return "Failed to connect to SMTP server \(host):\(port)"
        case .authenticationFailed:
            return "SMTP authentication failed"
        case .sendFailed(let reason):
            return "Failed to send email: \(reason)"
        case .recipientRejected(let email):
            return "Recipient \(email) was rejected by server"
        case .messageTooLarge:
            return "Email message exceeds maximum size limit"
        case .timeout:
            return "SMTP connection timed out"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .tlsError:
            return "TLS/SSL connection failed"
        case .serverError(let message):
            return "SMTP server error: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .connectionFailed:
            return "Check your internet connection and server settings"
        case .authenticationFailed:
            return "Verify your username and password"
        case .sendFailed:
            return "Try sending the email again"
        case .recipientRejected:
            return "Verify the recipient's email address is correct"
        case .messageTooLarge:
            return "Try reducing attachment sizes or remove some attachments"
        case .timeout:
            return "Check your internet connection and try again"
        case .networkUnavailable:
            return "Please connect to the internet and try again"
        case .tlsError:
            return "Check SSL/TLS settings or contact your email provider"
        case .serverError:
            return "Contact your email provider for assistance"
        }
    }

    var category: Logger.Category { .smtp }
    var severity: ErrorSeverity {
        switch self {
        case .networkUnavailable, .timeout:
            return .medium
        default:
            return .high
        }
    }
}

// MARK: - Database Errors

enum DatabaseError: AppErrorProtocol {
    case saveFailed
    case fetchFailed
    case deleteFailed
    case updateFailed
    case migrationFailed
    case corruptedData

    var title: String {
        return "Database Error"
    }

    var message: String {
        switch self {
        case .saveFailed:
            return "Failed to save data to database"
        case .fetchFailed:
            return "Failed to fetch data from database"
        case .deleteFailed:
            return "Failed to delete data from database"
        case .updateFailed:
            return "Failed to update database"
        case .migrationFailed:
            return "Database migration failed"
        case .corruptedData:
            return "Database data is corrupted"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .saveFailed, .updateFailed:
            return "Try saving again or restart the application"
        case .fetchFailed:
            return "Try refreshing or restart the application"
        case .deleteFailed:
            return "Try deleting again or restart the application"
        case .migrationFailed:
            return "Please restart the application or reinstall if the problem persists"
        case .corruptedData:
            return "You may need to reset the application data"
        }
    }

    var category: Logger.Category { .database }
    var severity: ErrorSeverity {
        switch self {
        case .migrationFailed, .corruptedData:
            return .critical
        default:
            return .high
        }
    }
}

// MARK: - PEC Errors

enum PECError: AppErrorProtocol {
    case invalidPECFormat
    case certificateNotFound
    case certificateParsingFailed
    case invalidSignature
    case receiptNotFound

    var title: String {
        return "PEC Error"
    }

    var message: String {
        switch self {
        case .invalidPECFormat:
            return "Invalid PEC email format"
        case .certificateNotFound:
            return "PEC certificate (daticert.xml) not found"
        case .certificateParsingFailed:
            return "Failed to parse PEC certificate"
        case .invalidSignature:
            return "PEC signature verification failed"
        case .receiptNotFound:
            return "PEC receipt (postacert.eml) not found"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidPECFormat:
            return "This email may not be a valid PEC message"
        case .certificateNotFound:
            return "The PEC certificate may not have been included in the email"
        case .certificateParsingFailed:
            return "The certificate file may be corrupted"
        case .invalidSignature:
            return "The PEC signature could not be verified"
        case .receiptNotFound:
            return "The PEC receipt may not have been included"
        }
    }

    var category: Logger.Category { .pec }
    var severity: ErrorSeverity { .medium }
}

// MARK: - Sync Errors

enum SyncError: AppErrorProtocol {
    case syncInProgress
    case syncFailed
    case conflictDetected
    case networkUnavailable

    var title: String {
        return "Sync Error"
    }

    var message: String {
        switch self {
        case .syncInProgress:
            return "A sync operation is already in progress"
        case .syncFailed:
            return "Failed to synchronize emails"
        case .conflictDetected:
            return "Sync conflict detected"
        case .networkUnavailable:
            return "Cannot sync without network connection"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .syncInProgress:
            return "Please wait for the current sync to complete"
        case .syncFailed:
            return "Try syncing again or check your connection"
        case .conflictDetected:
            return "Please resolve conflicts manually"
        case .networkUnavailable:
            return "Connect to the internet and try again"
        }
    }

    var category: Logger.Category { .sync }
    var severity: ErrorSeverity {
        switch self {
        case .syncInProgress, .networkUnavailable:
            return .low
        default:
            return .medium
        }
    }
}

// MARK: - File Errors

enum FileError: AppErrorProtocol {
    case notFound(path: String)
    case readFailed
    case writeFailed
    case deleteFailed
    case insufficientSpace
    case permissionDenied

    var title: String {
        return "File Error"
    }

    var message: String {
        switch self {
        case .notFound(let path):
            return "File not found: \(path)"
        case .readFailed:
            return "Failed to read file"
        case .writeFailed:
            return "Failed to write file"
        case .deleteFailed:
            return "Failed to delete file"
        case .insufficientSpace:
            return "Insufficient disk space"
        case .permissionDenied:
            return "Permission denied to access file"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notFound:
            return "The file may have been moved or deleted"
        case .readFailed:
            return "Check file permissions and try again"
        case .writeFailed:
            return "Ensure you have write permissions and sufficient disk space"
        case .deleteFailed:
            return "The file may be in use or you lack permissions"
        case .insufficientSpace:
            return "Free up disk space and try again"
        case .permissionDenied:
            return "Check file permissions in System Settings"
        }
    }

    var category: Logger.Category { .app }
    var severity: ErrorSeverity {
        switch self {
        case .insufficientSpace:
            return .critical
        default:
            return .high
        }
    }
}

// MARK: - Error Handler

/// Centralized error handler
final class ErrorHandler {

    /// Handle and log error
    /// - Parameters:
    ///   - error: The error to handle
    ///   - file: Source file (auto-filled)
    ///   - function: Function name (auto-filled)
    ///   - line: Line number (auto-filled)
    static func handle(
        _ error: Error,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        if let appError = error as? AppErrorProtocol {
            logAppError(appError, file: file, function: function, line: line)
        } else {
            logGenericError(error, file: file, function: function, line: line)
        }
    }

    /// Log app-specific error
    private static func logAppError(
        _ error: AppErrorProtocol,
        file: String,
        function: String,
        line: Int
    ) {
        let fileName = (file as NSString).lastPathComponent

        switch error.severity {
        case .low:
            Logger.info("\(error.title): \(error.message)", category: error.category)
        case .medium:
            Logger.warning("\(error.title): \(error.message)", category: error.category, file: file, line: line)
        case .high, .critical:
            Logger.error("\(error.title): \(error.message)", category: error.category, file: file, line: line)
        }

        if error.severity == .critical {
            Logger.fault("CRITICAL: \(error.title) - \(error.message)", category: error.category, file: file, line: line)
        }
    }

    /// Log generic Swift error
    private static func logGenericError(
        _ error: Error,
        file: String,
        function: String,
        line: Int
    ) {
        Logger.error("Unexpected error", error: error, category: .app, file: file, line: line)
    }

    /// Present error to user (placeholder for future UI integration)
    /// - Parameter error: The error to present
    static func present(_ error: Error) {
        // TODO: Implement UI alert presentation in Phase 2
        handle(error)
    }
}

// MARK: - Usage Examples

/*
 // Throw custom error
 throw AccountError.invalidEmailAddress

 // Handle error with logging
 do {
     try someOperation()
 } catch {
     ErrorHandler.handle(error)
 }

 // Present error to user
 do {
     try await sendEmail()
 } catch {
     ErrorHandler.present(error)
 }

 // Access error details
 let error = IMAPError.connectionFailed(host: "imap.gmail.com", port: 993)
 print(error.title)              // "IMAP Error"
 print(error.message)            // "Failed to connect..."
 print(error.recoverySuggestion) // "Check your internet..."
 print(error.severity)           // .high
 */
