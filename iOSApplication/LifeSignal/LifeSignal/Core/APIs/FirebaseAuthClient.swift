import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct FirebaseAuthClient {
    var sendVerificationCode: @Sendable (String) async throws -> String
    var verifyPhoneNumber: @Sendable (String, String) async throws -> String
    var signOut: @Sendable () async throws -> Void
    var getCurrentUID: @Sendable () -> String?
    var getToken: @Sendable () async throws -> String
}

extension FirebaseAuthClient: DependencyKey {
    static let liveValue = FirebaseAuthClient(
        sendVerificationCode: { phoneNumber in
            // TODO: Implement with Firebase Auth Phone Verification
            "verification-id-\(phoneNumber.suffix(4))"
        },
        verifyPhoneNumber: { verificationID, code in
            // TODO: Implement with Firebase Auth Phone Verification
            "firebase-uid-\(verificationID.suffix(4))"
        },
        signOut: {
            // TODO: Implement with Firebase Auth
        },
        getCurrentUID: {
            // TODO: Implement with Firebase Auth
            nil
        },
        getToken: {
            // TODO: Implement with Firebase Auth
            "firebase-token-\(UUID().uuidString.prefix(8))"
        }
    )
    
    static let testValue = FirebaseAuthClient(
        sendVerificationCode: { _ in "test-verification-id" },
        verifyPhoneNumber: { _, _ in "test-uid" },
        signOut: { },
        getCurrentUID: { "test-uid" },
        getToken: { "test-token" }
    )
}

extension DependencyValues {
    var firebaseAuth: FirebaseAuthClient {
        get { self[FirebaseAuthClient.self] }
        set { self[FirebaseAuthClient.self] = newValue }
    }
}