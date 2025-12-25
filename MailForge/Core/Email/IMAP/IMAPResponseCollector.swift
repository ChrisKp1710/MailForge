import Foundation

/// Collects IMAP responses for a specific command
final class IMAPResponseCollector {

    // MARK: - Response Collection

    /// Collected untagged responses
    private(set) var untaggedResponses: [IMAPResponse] = []

    /// Tagged response (final)
    private(set) var taggedResponse: IMAPResponse?

    /// Continuation for async/await
    private var continuation: CheckedContinuation<IMAPCommandResult, Error>?

    /// Lock for thread safety
    private let lock = NSLock()

    // MARK: - Add Responses

    /// Add untagged response
    func addUntagged(_ response: IMAPResponse) {
        lock.lock()
        defer { lock.unlock() }

        untaggedResponses.append(response)
    }

    /// Set tagged response and complete
    func complete(with response: IMAPResponse) {
        lock.lock()
        defer { lock.unlock() }

        taggedResponse = response

        let result = IMAPCommandResult(
            tagged: response,
            untagged: untaggedResponses
        )

        continuation?.resume(returning: result)
        continuation = nil
    }

    /// Fail with error
    func fail(with error: Error) {
        lock.lock()
        defer { lock.unlock() }

        continuation?.resume(throwing: error)
        continuation = nil
    }

    /// Wait for completion
    func wait() async throws -> IMAPCommandResult {
        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            defer { lock.unlock() }

            // If already completed, return immediately
            if let tagged = taggedResponse {
                let result = IMAPCommandResult(
                    tagged: tagged,
                    untagged: untaggedResponses
                )
                continuation.resume(returning: result)
                return
            }

            // Otherwise, store continuation for later
            self.continuation = continuation
        }
    }
}

// MARK: - Command Result

/// Result of an IMAP command (tagged + all untagged responses)
struct IMAPCommandResult {
    /// Tagged response (final status)
    let tagged: IMAPResponse

    /// All untagged responses
    let untagged: [IMAPResponse]

    /// Check if command was successful
    var isSuccess: Bool {
        if case .tagged(_, let status, _) = tagged {
            return status == .ok
        }
        return false
    }

    /// Get error message if failed
    var errorMessage: String? {
        if case .tagged(_, let status, let message) = tagged, status != .ok {
            return message
        }
        return nil
    }

    /// Extract capabilities from CAPABILITY response
    var capabilities: [String] {
        for response in untagged {
            if case .capability(let caps) = response {
                return caps
            }
        }
        return []
    }

    /// Extract folders from LIST responses
    var folders: [IMAPFolder] {
        var folders: [IMAPFolder] = []

        for response in untagged {
            if case .list(let folderNames) = response {
                // Convert folder names to IMAPFolder objects
                let imapFolders = folderNames.map { name in
                    IMAPFolder(
                        name: name,
                        path: name,
                        delimiter: "/",
                        attributes: []
                    )
                }
                folders.append(contentsOf: imapFolders)
            }
        }

        return folders
    }

    /// Extract folder info (EXISTS, RECENT, FLAGS, etc.)
    var folderInfo: IMAPFolderInfo? {
        var exists: Int?
        var recent: Int?
        var flags: [String] = []

        for response in untagged {
            switch response {
            case .exists(let count):
                exists = count
            case .recent(let count):
                recent = count
            case .flags(let flagList):
                flags = flagList
            default:
                break
            }
        }

        guard let existsCount = exists else {
            return nil
        }

        return IMAPFolderInfo(
            name: "",
            exists: existsCount,
            recent: recent ?? 0,
            unseen: nil,
            flags: flags,
            permanentFlags: []
        )
    }

    /// Extract message data from FETCH responses
    var messages: [IMAPMessageData] {
        var messages: [IMAPMessageData] = []

        for response in untagged {
            if case .fetch(let uid, let data) = response {
                // Parse data dictionary into IMAPMessageData
                let message = IMAPMessageData(
                    uid: uid,
                    sequenceNumber: nil,
                    flags: [],
                    size: nil,
                    envelope: nil,
                    bodyStructure: nil,
                    rfc822: nil,
                    internalDate: nil
                )
                messages.append(message)
            }
        }

        return messages
    }

    /// Extract UIDs from SEARCH response
    var searchResults: [Int64] {
        // TODO: Parse SEARCH response properly
        // For now, return empty array
        return []
    }
}
