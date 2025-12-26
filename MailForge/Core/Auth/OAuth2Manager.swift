import Foundation
import AuthenticationServices

// MARK: - OAuth2 Provider

/// Supported OAuth2 providers
enum OAuth2Provider {
    case google
    case microsoft
    case apple

    var name: String {
        switch self {
        case .google: return "Google"
        case .microsoft: return "Microsoft"
        case .apple: return "Apple"
        }
    }

    /// OAuth2 configuration for each provider
    var config: OAuth2Config {
        switch self {
        case .google:
            // Load credentials from GoogleService-Info.plist
            guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
                  let config = NSDictionary(contentsOfFile: path),
                  let clientId = config["CLIENT_ID"] as? String,
                  let reversedClientId = config["REVERSED_CLIENT_ID"] as? String else {
                fatalError("GoogleService-Info.plist not found or invalid. Please add your OAuth2 credentials.")
            }

            return OAuth2Config(
                clientId: clientId,
                clientSecret: "", // iOS apps don't need client secret
                authorizationEndpoint: "https://accounts.google.com/o/oauth2/v2/auth",
                tokenEndpoint: "https://oauth2.googleapis.com/token",
                redirectURI: "\(reversedClientId):/oauth2callback",
                scopes: [
                    "https://mail.google.com/", // Full Gmail access
                    "https://www.googleapis.com/auth/userinfo.email",
                    "https://www.googleapis.com/auth/userinfo.profile"
                ]
            )

        case .microsoft:
            return OAuth2Config(
                clientId: "YOUR_MICROSOFT_CLIENT_ID", // TODO: Replace with real Client ID
                clientSecret: "", // Microsoft public clients don't need secret
                authorizationEndpoint: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
                tokenEndpoint: "https://login.microsoftonline.com/common/oauth2/v2.0/token",
                redirectURI: "http://localhost",
                scopes: [
                    "https://outlook.office.com/IMAP.AccessAsUser.All",
                    "https://outlook.office.com/SMTP.Send",
                    "offline_access" // For refresh token
                ]
            )

        case .apple:
            return OAuth2Config(
                clientId: "YOUR_APPLE_CLIENT_ID",
                clientSecret: "",
                authorizationEndpoint: "https://appleid.apple.com/auth/authorize",
                tokenEndpoint: "https://appleid.apple.com/auth/token",
                redirectURI: "http://localhost",
                scopes: ["email"]
            )
        }
    }

    /// IMAP server configuration
    var imapConfig: (host: String, port: Int) {
        switch self {
        case .google:
            return ("imap.gmail.com", 993)
        case .microsoft:
            return ("outlook.office365.com", 993)
        case .apple:
            return ("imap.mail.me.com", 993)
        }
    }

    /// SMTP server configuration
    var smtpConfig: (host: String, port: Int) {
        switch self {
        case .google:
            return ("smtp.gmail.com", 465)
        case .microsoft:
            return ("smtp.office365.com", 587)
        case .apple:
            return ("smtp.mail.me.com", 587)
        }
    }
}

// MARK: - OAuth2 Configuration

/// OAuth2 configuration for a provider
struct OAuth2Config {
    let clientId: String
    let clientSecret: String
    let authorizationEndpoint: String
    let tokenEndpoint: String
    let redirectURI: String
    let scopes: [String]

    /// Build authorization URL
    func buildAuthorizationURL(state: String) -> URL? {
        var components = URLComponents(string: authorizationEndpoint)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"), // For refresh token
            URLQueryItem(name: "prompt", value: "consent") // Force consent to get refresh token
        ]
        return components?.url
    }
}

// MARK: - OAuth2 Tokens

/// OAuth2 tokens response
struct OAuth2Tokens: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String
    let scope: String?

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case scope
    }

    /// Calculate expiration date
    var expirationDate: Date {
        Date().addingTimeInterval(TimeInterval(expiresIn))
    }
}

// MARK: - OAuth2 Manager

/// Manages OAuth2 authentication flows
final class OAuth2Manager: NSObject, ObservableObject, @unchecked Sendable {

    // MARK: - Published Properties

    @MainActor @Published var isAuthenticating = false
    @MainActor @Published var authError: Error?

    // MARK: - Private Properties

    private var provider: OAuth2Provider
    private var authSession: ASWebAuthenticationSession?
    private var currentState: String?

    // MARK: - Initialization

    init(provider: OAuth2Provider) {
        self.provider = provider
        super.init()
    }

    // MARK: - Authorization

    /// Start OAuth2 authorization flow
    /// - Returns: OAuth2 tokens on success
    func authorize() async throws -> OAuth2Tokens {
        if await isAuthenticating {
            throw OAuth2Error.authenticationInProgress
        }

        await MainActor.run { isAuthenticating = true }
        defer { Task { @MainActor in isAuthenticating = false } }

        // Generate state for CSRF protection
        let state = UUID().uuidString
        currentState = state

        // Build authorization URL
        guard let authURL = provider.config.buildAuthorizationURL(state: state) else {
            throw OAuth2Error.invalidConfiguration
        }

        Logger.info("Starting OAuth2 flow for \(provider.name)", category: .email)
        Logger.debug("Authorization URL: \(authURL)", category: .email)

        // Get authorization code
        let code = try await performWebAuthentication(url: authURL)

        // Exchange code for tokens
        let tokens = try await exchangeCodeForTokens(code: code)

        Logger.info("OAuth2 authentication successful for \(provider.name)", category: .email)

        return tokens
    }

    /// Refresh access token using refresh token
    /// - Parameter refreshToken: The refresh token
    /// - Returns: New OAuth2 tokens
    func refreshAccessToken(refreshToken: String) async throws -> OAuth2Tokens {
        Logger.info("Refreshing access token for \(provider.name)", category: .email)

        let config = provider.config

        var request = URLRequest(url: URL(string: config.tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var parameters = [
            "client_id": config.clientId,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]

        // Add client secret if available (Google requires it, Microsoft doesn't)
        if !config.clientSecret.isEmpty {
            parameters["client_secret"] = config.clientSecret
        }

        let body = parameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuth2Error.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            Logger.error("Token refresh failed with status: \(httpResponse.statusCode)", category: .email)
            throw OAuth2Error.tokenRefreshFailed(statusCode: httpResponse.statusCode)
        }

        let tokens = try JSONDecoder().decode(OAuth2Tokens.self, from: data)

        Logger.info("Access token refreshed successfully", category: .email)

        return tokens
    }

    // MARK: - Private Methods

    /// Perform web authentication using ASWebAuthenticationSession
    private func performWebAuthentication(url: URL) async throws -> String {
        Logger.debug("performWebAuthentication: Starting", category: .email)

        return try await withCheckedThrowingContinuation { continuation in
            Logger.debug("performWebAuthentication: Inside continuation", category: .email)

            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: URL(string: provider.config.redirectURI)?.scheme
            ) { callbackURL, error in
                Logger.debug("performWebAuthentication: Callback received", category: .email)
                Logger.debug("performWebAuthentication: Current thread: \(Thread.current)", category: .email)
                Logger.debug("performWebAuthentication: Is main thread: \(Thread.isMainThread)", category: .email)

                // Always resume continuation on main queue to avoid threading issues
                Logger.debug("performWebAuthentication: About to dispatch to main queue", category: .email)
                DispatchQueue.main.async {
                    Logger.debug("performWebAuthentication: Inside main queue dispatch", category: .email)

                    if let error = error {
                        Logger.debug("performWebAuthentication: Got error: \(error)", category: .email)
                        // User cancelled
                        if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                            Logger.debug("performWebAuthentication: User cancelled", category: .email)
                            continuation.resume(throwing: OAuth2Error.userCancelled)
                        } else {
                            Logger.debug("performWebAuthentication: Other error", category: .email)
                            continuation.resume(throwing: error)
                        }
                        return
                    }

                    Logger.debug("performWebAuthentication: Checking callback URL", category: .email)
                    guard let callbackURL = callbackURL else {
                        Logger.debug("performWebAuthentication: No callback URL", category: .email)
                        continuation.resume(throwing: OAuth2Error.invalidCallback)
                        return
                    }

                    Logger.debug("performWebAuthentication: Callback URL: \(callbackURL)", category: .email)

                    // Extract authorization code from callback URL
                    guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                          let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                        Logger.debug("performWebAuthentication: Missing authorization code", category: .email)
                        continuation.resume(throwing: OAuth2Error.missingAuthorizationCode)
                        return
                    }

                    Logger.debug("performWebAuthentication: Got authorization code: \(code.prefix(10))...", category: .email)

                    // Verify state for CSRF protection
                    if let state = components.queryItems?.first(where: { $0.name == "state" })?.value,
                       state != self.currentState {
                        Logger.debug("performWebAuthentication: State mismatch", category: .email)
                        continuation.resume(throwing: OAuth2Error.stateMismatch)
                        return
                    }

                    Logger.debug("performWebAuthentication: About to resume continuation with code", category: .email)
                    continuation.resume(returning: code)
                    Logger.debug("performWebAuthentication: Continuation resumed", category: .email)
                }
            }

            Logger.debug("performWebAuthentication: Setting presentation context provider", category: .email)
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false // Allow cookies for smoother UX

            Logger.debug("performWebAuthentication: Storing session", category: .email)
            self.authSession = session

            // Start session on main thread SYNCHRONOUSLY
            Logger.debug("performWebAuthentication: About to start session", category: .email)
            Logger.debug("performWebAuthentication: Current thread before start: \(Thread.current)", category: .email)
            Logger.debug("performWebAuthentication: Is main thread: \(Thread.isMainThread)", category: .email)

            // Use DispatchQueue.main.sync if not on main thread, otherwise call directly
            if Thread.isMainThread {
                Logger.debug("performWebAuthentication: Already on main thread, starting directly", category: .email)
                session.start()
            } else {
                Logger.debug("performWebAuthentication: Not on main thread, dispatching sync to main", category: .email)
                DispatchQueue.main.sync {
                    session.start()
                }
            }
            Logger.debug("performWebAuthentication: Session started", category: .email)
        }
    }

    /// Exchange authorization code for access/refresh tokens
    private func exchangeCodeForTokens(code: String) async throws -> OAuth2Tokens {
        let config = provider.config

        var request = URLRequest(url: URL(string: config.tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var parameters = [
            "client_id": config.clientId,
            "code": code,
            "redirect_uri": config.redirectURI,
            "grant_type": "authorization_code"
        ]

        // Add client secret if available (Google requires it, Microsoft doesn't)
        if !config.clientSecret.isEmpty {
            parameters["client_secret"] = config.clientSecret
        }

        let body = parameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuth2Error.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Try to decode error response
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
               let errorDescription = errorResponse["error_description"] {
                Logger.error("Token exchange failed: \(errorDescription)", category: .email)
            }
            throw OAuth2Error.tokenExchangeFailed(statusCode: httpResponse.statusCode)
        }

        let tokens = try JSONDecoder().decode(OAuth2Tokens.self, from: data)

        return tokens
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension OAuth2Manager: ASWebAuthenticationPresentationContextProviding {

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the main window
        return NSApplication.shared.windows.first { $0.isKeyWindow } ?? NSApplication.shared.windows.first!
    }
}

// MARK: - OAuth2 Error

/// OAuth2-specific errors
enum OAuth2Error: LocalizedError {
    case invalidConfiguration
    case authenticationInProgress
    case userCancelled
    case invalidCallback
    case missingAuthorizationCode
    case stateMismatch
    case invalidResponse
    case tokenExchangeFailed(statusCode: Int)
    case tokenRefreshFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "OAuth2 configuration is invalid"
        case .authenticationInProgress:
            return "Authentication is already in progress"
        case .userCancelled:
            return "User cancelled the authentication"
        case .invalidCallback:
            return "Invalid callback URL received"
        case .missingAuthorizationCode:
            return "Authorization code not found in callback"
        case .stateMismatch:
            return "State parameter mismatch (possible CSRF attack)"
        case .invalidResponse:
            return "Invalid response from OAuth2 server"
        case .tokenExchangeFailed(let statusCode):
            return "Token exchange failed with status code \(statusCode)"
        case .tokenRefreshFailed(let statusCode):
            return "Token refresh failed with status code \(statusCode)"
        }
    }
}
