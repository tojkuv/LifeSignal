import ComposableArchitecture
import Dependencies
import Foundation

struct FirebaseUser: Equatable, Sendable {
    let uid: String
    let phoneNumber: String?
    let email: String?
    let displayName: String?
    let isAnonymous: Bool
    let creationTime: Date?
    let lastSignInTime: Date?
    let idToken: String?

    init(
        uid: String,
        phoneNumber: String? = nil,
        email: String? = nil,
        displayName: String? = nil,
        isAnonymous: Bool = false,
        creationTime: Date? = nil,
        lastSignInTime: Date? = nil,
        idToken: String? = nil
    ) {
        self.uid = uid
        self.phoneNumber = phoneNumber
        self.email = email
        self.displayName = displayName
        self.isAnonymous = isAnonymous
        self.creationTime = creationTime
        self.lastSignInTime = lastSignInTime
        self.idToken = idToken
    }
}

struct FirebaseAuthClient {
    var getCurrentUser: @Sendable () async -> FirebaseUser? = { nil }
    var sendVerificationCode: @Sendable (String) async throws -> String = { _ in "verification-id" }
    var verifyPhoneNumber: @Sendable (String, String) async throws -> FirebaseUser = { _, _ in FirebaseUser(uid: "mock-uid") }
    var signOut: @Sendable () async throws -> Void = { }
    var deleteAccount: @Sendable () async throws -> Void = { }
    var getIDToken: @Sendable (Bool) async throws -> String = { _ in "mock-token" }
    var authStateDidChange: @Sendable () -> AsyncStream<FirebaseUser?> = {
        AsyncStream { continuation in
            continuation.yield(nil)
            continuation.finish()
        }
    }
}

extension FirebaseAuthClient: DependencyKey {
    static let liveValue = FirebaseAuthClient()
    static let mockValue = FirebaseAuthClient()
    static let testValue = FirebaseAuthClient()
}

extension DependencyValues {
    var firebaseAuth: FirebaseAuthClient {
        get { self[FirebaseAuthClient.self] }
        set { self[FirebaseAuthClient.self] = newValue }
    }
}