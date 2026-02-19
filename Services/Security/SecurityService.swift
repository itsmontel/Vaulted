import LocalAuthentication
import Foundation

// MARK: - SecurityService
@MainActor
final class SecurityService: ObservableObject {

    static let shared = SecurityService()

    // The unlock window in seconds (10 minutes)
    private let unlockDuration: TimeInterval = 600

    @Published private(set) var isPrivateUnlocked = false
    private var unlockedUntil: Date?

    // MARK: - Check if currently unlocked
    var privateDrawerIsUnlocked: Bool {
        guard let until = unlockedUntil else { return false }
        return Date() < until
    }

    // MARK: - Authenticate
    func authenticate(reason: String = "Unlock your Private drawer") async throws -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw SecurityError.biometryUnavailable(error?.localizedDescription ?? "")
        }

        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, err in
                if let err {
                    continuation.resume(throwing: err)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }

    // MARK: - Unlock private drawer
    func unlockPrivateDrawer() {
        unlockedUntil = Date().addingTimeInterval(unlockDuration)
        isPrivateUnlocked = true
    }

    // MARK: - Lock immediately (called on app background)
    func lockPrivateDrawer() {
        unlockedUntil = nil
        isPrivateUnlocked = false
    }

    // MARK: - Try to authenticate and unlock
    func authenticateAndUnlock() async -> Bool {
        // If still within window, skip prompt
        if privateDrawerIsUnlocked {
            isPrivateUnlocked = true
            return true
        }
        do {
            let success = try await authenticate()
            if success { unlockPrivateDrawer() }
            return success
        } catch {
            return false
        }
    }
}

// MARK: - Errors
enum SecurityError: LocalizedError {
    case biometryUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .biometryUnavailable(let msg): return "Authentication unavailable: \(msg)"
        }
    }
}
