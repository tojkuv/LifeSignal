import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation

// MARK: - Session Models

struct AuthSession: Codable, Equatable, Sendable {
    let firebaseUser: MockFirebaseUser
    let appUser: User
    let idToken: String
    let createdAt: Date
    let expiresAt: Date

    init(firebaseUser: MockFirebaseUser, appUser: User, idToken: String) {
        self.firebaseUser = firebaseUser
        self.appUser = appUser
        self.idToken = idToken
        self.createdAt = Date()
        self.expiresAt = Date().addingTimeInterval(3600) // 1 hour
    }

    var isExpired: Bool {
        Date() > expiresAt
    }

    var isValid: Bool {
        !isExpired && !firebaseUser.uid.isEmpty
    }
}

enum SessionState: Equatable, Sendable {
    case unknown
    case unauthenticated
    case authenticating
    case verifyingCode(verificationID: String, phoneNumber: String)
    case creatingAccount(firebaseUID: String, phoneNumber: String, phoneRegion: String)
    case authenticated(AuthSession)
    case expired
    case error(String)

    var isAuthenticated: Bool {
        if case .authenticated = self {
            return true
        }
        return false
    }

    var currentUser: User? {
        if case .authenticated(let session) = self {
            return session.appUser
        }
        return nil
    }
}

enum SessionError: Error, Equatable {
    case notAuthenticated
    case sessionExpired
    case userNotFound
    case accountCreationRequired
    case phoneVerificationFailed(String)
    case networkError(String)
    case unknown(String)

    var localizedDescription: String {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .sessionExpired:
            return "Session has expired"
        case .userNotFound:
            return "User account not found"
        case .accountCreationRequired:
            return "Account creation required"
        case .phoneVerificationFailed(let reason):
            return "Phone verification failed: \(reason)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - Mock Firebase User Model

struct MockFirebaseUser: Codable, Equatable, Sendable {
    let uid: String
    let phoneNumber: String?
    let idToken: String?

    init(uid: String, phoneNumber: String? = nil, idToken: String? = nil) {
        self.uid = uid
        self.phoneNumber = phoneNumber
        self.idToken = idToken
    }
}

// MARK: - Auth State

enum AuthState: Equatable, Sendable {
    case unknown
    case signedIn(MockFirebaseUser)
    case signedOut
}

// MARK: - Session Client

@DependencyClient
struct SessionClient {
    // Authentication flow
    var sendVerificationCode: @Sendable (String) async throws -> String = { _ in throw SessionError.notAuthenticated }
    var verifyCodeAndSignIn: @Sendable (String, String) async throws -> SessionState = { _, _ in throw SessionError.phoneVerificationFailed("Not implemented") }
    var createAccount: @Sendable (String, String, String, String) async throws -> SessionState = { _, _, _, _ in throw SessionError.accountCreationRequired }
    var signOut: @Sendable () async throws -> Void = { throw SessionError.notAuthenticated }

    // Session management
    var getCurrentSession: @Sendable () async -> AuthSession? = { nil }
    var refreshSession: @Sendable () async throws -> AuthSession = { throw SessionError.sessionExpired }
    var validateSession: @Sendable () async -> Bool = { false }
    var deleteAccount: @Sendable () async throws -> Void = { throw SessionError.notAuthenticated }

    // Session state
    var sessionStateStream: @Sendable () -> AsyncStream<SessionState> = {
        AsyncStream { continuation in
            continuation.yield(.unauthenticated)
            continuation.finish()
        }
    }
    var getCurrentState: @Sendable () async -> SessionState = { .unauthenticated }
    var isAuthenticated: @Sendable () async -> Bool = { false }

    // User operations (convenience methods)
    var getCurrentUser: @Sendable () async -> User? = { nil }
    var updateUserProfile: @Sendable (User) async throws -> User = { _ in throw SessionError.notAuthenticated }
    var uploadAvatar: @Sendable (Data) async throws -> URL = { _ in throw SessionError.notAuthenticated }
}

// MARK: - Live Implementation

extension SessionClient: DependencyKey {
    static let liveValue: SessionClient = SessionClient()
    static let testValue = SessionClient()
    static let mockValue: SessionClient = SessionClient(
        sendVerificationCode: { phoneNumber in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(500))
            return "mock-verification-id-\(UUID().uuidString.prefix(8))"
        },
        
        verifyCodeAndSignIn: { verificationID, code in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(1000))
            
            // Mock verification logic - accept "123456" as valid code
            if code == "123456" {
                let mockUser = MockFirebaseUser(
                    uid: "mock-uid-\(UUID().uuidString.prefix(8))",
                    phoneNumber: "+1234567890",
                    idToken: "mock-token-\(UUID().uuidString.prefix(12))"
                )
                
                let appUser = User(
                    id: UUID(),
                    name: "Mock User",
                    phoneNumber: "+1234567890",
                    phoneRegion: "US",
                    emergencyNote: "This is a mock emergency note",
                    checkInInterval: 86400, // 24 hours
                    lastCheckedIn: Date(),
                    isNotificationsEnabled: true,
                    notify30MinBefore: true,
                    notify2HoursBefore: false,
                    qrCodeId: UUID(),
                    avatarURL: nil,
                    avatarImageData: nil,
                    lastModified: Date()
                )
                
                let session = AuthSession(
                    firebaseUser: mockUser,
                    appUser: appUser,
                    idToken: mockUser.idToken ?? "mock-token"
                )
                
                return .authenticated(session)
            } else {
                throw SessionError.phoneVerificationFailed("Invalid verification code. Use '123456' for mock authentication.")
            }
        },
        
        createAccount: { firebaseUID, name, phoneNumber, phoneRegion in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(1000))
            
            let mockUser = MockFirebaseUser(
                uid: firebaseUID,
                phoneNumber: phoneNumber,
                idToken: "mock-token-\(UUID().uuidString.prefix(12))"
            )
            
            let appUser = User(
                id: UUID(),
                name: name,
                phoneNumber: phoneNumber,
                phoneRegion: phoneRegion,
                emergencyNote: "",
                checkInInterval: 86400, // 24 hours
                lastCheckedIn: nil,
                isNotificationsEnabled: true,
                notify30MinBefore: true,
                notify2HoursBefore: false,
                qrCodeId: UUID(),
                avatarURL: nil,
                avatarImageData: nil,
                lastModified: Date()
            )
            
            let session = AuthSession(
                firebaseUser: mockUser,
                appUser: appUser,
                idToken: mockUser.idToken ?? "mock-token"
            )
            
            return .authenticated(session)
        },
        
        signOut: {
            // Simulate delay
            try await Task.sleep(for: .milliseconds(300))
            // Mock sign out always succeeds
        },
        
        getCurrentSession: {
            // Return nil for mock - no persistent session
            return nil
        },
        
        refreshSession: {
            throw SessionError.sessionExpired
        },
        
        validateSession: {
            return false
        },
        
        deleteAccount: {
            // Simulate delay
            try await Task.sleep(for: .milliseconds(500))
            // Mock delete always succeeds
        },
        
        sessionStateStream: {
            AsyncStream { continuation in
                continuation.yield(.unauthenticated)
                continuation.finish()
            }
        },
        
        getCurrentState: {
            return .unauthenticated
        },
        
        isAuthenticated: {
            return false
        },
        
        getCurrentUser: {
            return nil
        },
        
        updateUserProfile: { user in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(500))
            
            // Return updated user with new lastModified timestamp
            var updatedUser = user
            updatedUser.lastModified = Date()
            return updatedUser
        },
        
        uploadAvatar: { imageData in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(1500))
            
            // Return mock URL
            guard let url = URL(string: "https://mock.lifesignal.app/avatars/\(UUID().uuidString).jpg") else {
                throw SessionError.unknown("Failed to create mock avatar URL")
            }
            return url
        }
    )
}

extension DependencyValues {
    var sessionClient: SessionClient {
        get { self[SessionClient.self] }
        set { self[SessionClient.self] = newValue }
    }
}