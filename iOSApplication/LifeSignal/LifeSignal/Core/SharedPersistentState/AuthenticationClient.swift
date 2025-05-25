import Foundation
import ComposableArchitecture
import Dependencies
import DependenciesMacros
@_exported import Sharing

// MARK: - Firebase Auth Integration

protocol FirebaseAuthServiceProtocol: Sendable {
    // Phone-first authentication (primary flow)
    func sendVerificationCode(phoneNumber: String) async throws -> String // Returns verification ID
    func verifyPhoneCode(verificationID: String, verificationCode: String) async throws -> FirebaseAuthResult
    
    // Token management
    func getCurrentAuthUser() async -> FirebaseUser?
    func getIdToken(forceRefresh: Bool) async throws -> String?
    func refreshToken() async throws -> FirebaseAuthResult
    
    // Account management
    func signOut() async throws -> Void
    func deleteAccount() async throws -> Void
}

// MARK: - Firebase Auth Types

struct FirebaseAuthResult: Sendable {
    let user: FirebaseUser
    let idToken: String
    let refreshToken: String
    let expiresAt: Date
}

struct FirebaseUser: Sendable {
    let uid: String
    let email: String?
    let phoneNumber: String?
    let displayName: String?
    let isEmailVerified: Bool
    let creationDate: Date
    let lastSignInDate: Date
}

// MARK: - Credentials Shared State

extension SharedReaderKey where Self == InMemoryKey<String?>.Default {
    static var firebaseUID: Self {
        Self[.inMemory("firebaseUID"), default: nil]
    }
}

extension SharedReaderKey where Self == InMemoryKey<String?>.Default {
    static var firebaseIdToken: Self {
        Self[.inMemory("firebaseIdToken"), default: nil]
    }
}

extension SharedReaderKey where Self == InMemoryKey<String?>.Default {
    static var firebaseRefreshToken: Self {
        Self[.inMemory("firebaseRefreshToken"), default: nil]
    }
}

extension SharedReaderKey where Self == InMemoryKey<Date?>.Default {
    static var firebaseTokenExpiry: Self {
        Self[.inMemory("firebaseTokenExpiry"), default: nil]
    }
}

extension SharedReaderKey where Self == InMemoryKey<FirebaseUser?>.Default {
    static var firebaseUser: Self {
        Self[.inMemory("firebaseUser"), default: nil]
    }
}

// MARK: - Mock Firebase Auth Service

final class MockFirebaseAuthService: FirebaseAuthServiceProtocol {
    func sendVerificationCode(phoneNumber: String) async throws -> String {
        try await Task.sleep(for: .milliseconds(800))
        // Mock sending verification code and return verification ID
        return "mock_verification_id_\(UUID().uuidString)"
    }
    
    func verifyPhoneCode(verificationID: String, verificationCode: String) async throws -> FirebaseAuthResult {
        try await Task.sleep(for: .milliseconds(1000))
        
        let firebaseUser = FirebaseUser(
            uid: "mock_firebase_uid_\(UUID().uuidString)",
            email: nil,
            phoneNumber: "+1234567890", // Would extract from verification flow
            displayName: "Phone User",
            isEmailVerified: false,
            creationDate: Date(),
            lastSignInDate: Date()
        )
        
        return FirebaseAuthResult(
            user: firebaseUser,
            idToken: "mock_firebase_id_token_\(UUID().uuidString)",
            refreshToken: "mock_firebase_refresh_token_\(UUID().uuidString)",
            expiresAt: Date().addingTimeInterval(3600) // 1 hour from now
        )
    }
    
    func getCurrentAuthUser() async -> FirebaseUser? {
        // Mock getting current user from shared state
        @Shared(.firebaseUser) var firebaseUser
        return firebaseUser
    }
    
    func getIdToken(forceRefresh: Bool = false) async throws -> String? {
        @Shared(.firebaseIdToken) var idToken
        @Shared(.firebaseTokenExpiry) var tokenExpiry
        
        // Check if token needs refresh
        if forceRefresh || (tokenExpiry != nil && Date() >= tokenExpiry!) {
            // Mock token refresh
            let refreshResult = try await refreshToken()
            return refreshResult.idToken
        }
        
        return idToken ?? "current_mock_firebase_id_token"
    }
    
    func refreshToken() async throws -> FirebaseAuthResult {
        try await Task.sleep(for: .milliseconds(300))
        
        @Shared(.firebaseUser) var currentUser
        let user = currentUser ?? FirebaseUser(
            uid: "current_mock_firebase_uid",
            email: nil,
            phoneNumber: "+1234567890",
            displayName: "Current User",
            isEmailVerified: false,
            creationDate: Date().addingTimeInterval(-86400),
            lastSignInDate: Date()
        )
        
        return FirebaseAuthResult(
            user: user,
            idToken: "refreshed_mock_firebase_id_token_\(UUID().uuidString)",
            refreshToken: "refreshed_mock_firebase_refresh_token_\(UUID().uuidString)",
            expiresAt: Date().addingTimeInterval(3600) // 1 hour from now
        )
    }
    
    func signOut() async throws -> Void {
        try await Task.sleep(for: .milliseconds(500))
        // Mock sign out
    }
    
    func deleteAccount() async throws -> Void {
        try await Task.sleep(for: .milliseconds(800))
        // Mock account deletion
    }
}

// MARK: - Authentication Shared State

extension SharedReaderKey where Self == InMemoryKey<Bool>.Default {
    static var isAuthenticated: Self {
        Self[.inMemory("isAuthenticated"), default: false]
    }
}

extension SharedReaderKey where Self == InMemoryKey<Bool>.Default {
    static var needsOnboarding: Self {
        Self[.inMemory("needsOnboarding"), default: false]
    }
}

// MARK: - Validation Types

enum ValidationResult: Equatable {
    case valid
    case invalid(String)
    
    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
    
    var errorMessage: String? {
        if case .invalid(let msg) = self { return msg }
        return nil
    }
}

// MARK: - Client Errors

enum AuthenticationClientError: Error, LocalizedError {
    case authenticationFailed(String)
    case signOutFailed(String)
    case tokenRefreshFailed(String)
    case networkError(String)
    case invalidCredentials(String)
    case validationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed(let details):
            return "Authentication failed: \(details)"
        case .signOutFailed(let details):
            return "Sign out failed: \(details)"
        case .tokenRefreshFailed(let details):
            return "Token refresh failed: \(details)"
        case .networkError(let details):
            return "Network error: \(details)"
        case .invalidCredentials(let details):
            return "Invalid credentials: \(details)"
        case .validationFailed(let details):
            return "Validation failed: \(details)"
        }
    }
}

// MARK: - Authentication Client

// MARK: - Authentication Helpers

extension AuthenticationClient {
    /// Clears all authentication and user-related state from shared storage
    static func clearAllUserState() async {
        @Shared(.isAuthenticated) var isAuthenticated
        @Shared(.firebaseUID) var firebaseUID
        @Shared(.firebaseIdToken) var firebaseIdToken
        @Shared(.firebaseRefreshToken) var firebaseRefreshToken
        @Shared(.firebaseTokenExpiry) var tokenExpiry
        @Shared(.firebaseUser) var firebaseUser
        @Shared(.needsOnboarding) var needsOnboarding
        @Shared(.currentUser) var currentUser
        @Shared(.contacts) var contacts
        @Shared(.notifications) var notifications
        @Shared(.unreadNotificationCount) var unreadCount
        
        $isAuthenticated.withLock { $0 = false }
        $firebaseUID.withLock { $0 = nil }
        $firebaseIdToken.withLock { $0 = nil }
        $firebaseRefreshToken.withLock { $0 = nil }
        $firebaseTokenExpiry.withLock { $0 = nil }
        $firebaseUser.withLock { $0 = nil }
        $needsOnboarding.withLock { $0 = false }
        $currentUser.withLock { $0 = nil }
        $contacts.withLock { $0 = [] }
        $notifications.withLock { $0 = [] }
        $unreadCount.withLock { $0 = 0 }
    }
    
    /// Sets the onboarding completion status
    static func setOnboardingCompleted() async {
        @Shared(.needsOnboarding) var needsOnboarding
        $needsOnboarding.withLock { $0 = false }
    }
    
    /// Gets the current onboarding status
    static func getOnboardingStatus() async -> Bool {
        @Shared(.needsOnboarding) var needsOnboarding
        return needsOnboarding
    }
}

@DependencyClient
struct AuthenticationClient {
    // Firebase Auth service integration
    var firebaseAuthService: FirebaseAuthServiceProtocol = MockFirebaseAuthService()
    
    // Phone-based authentication (primary flow)
    var sendVerificationCode: @Sendable (String) async throws -> String = { _ in
        throw AuthenticationClientError.authenticationFailed("SendVerificationCode")
    }
    var verifyPhoneCode: @Sendable (String, String) async throws -> FirebaseUser = { _, _ in
        throw AuthenticationClientError.authenticationFailed("VerifyPhoneCode")
    }
    
    // Token management (critical for other clients)
    var getIdToken: @Sendable (Bool) async throws -> String? = { _ in nil }
    var refreshToken: @Sendable () async throws -> Void = { 
        throw AuthenticationClientError.tokenRefreshFailed("RefreshToken")
    }
    
    // Account management
    var signOut: @Sendable () async throws -> Void = { 
        throw AuthenticationClientError.signOutFailed("SignOut")
    }
    var deleteAccount: @Sendable () async throws -> Void = { 
        throw AuthenticationClientError.authenticationFailed("DeleteAccount")
    }
    
    // Authentication state checks
    var isAuthenticated: @Sendable () async -> Bool = { false }
    var needsOnboarding: @Sendable () async -> Bool = { false }
    var getCurrentAuthUser: @Sendable () async -> FirebaseUser? = { nil }
    
    // Onboarding operations
    var completeOnboarding: @Sendable () async throws -> Void = { }
    var skipOnboarding: @Sendable () async throws -> Void = { }
    
    // Validation methods (authentication-related only)
    var validatePhoneNumber: @Sendable (String) -> ValidationResult = { _ in .valid }
    var validateName: @Sendable (String) -> ValidationResult = { _ in .valid }
    var validateVerificationCode: @Sendable (String) -> ValidationResult = { _ in .valid }
    
    // Phone formatting for authentication
    var formatPhoneNumber: @Sendable (String, String) -> String = { _, _ in "" }
    var formatPhoneNumberForEditing: @Sendable (String, String) -> String = { _, _ in "" }
}

extension AuthenticationClient: DependencyKey {
    static let liveValue: AuthenticationClient = AuthenticationClient()
    static let testValue = AuthenticationClient()
    
    static let mockValue = AuthenticationClient(
        firebaseAuthService: MockFirebaseAuthService(),
        
        sendVerificationCode: { phoneNumber in
            let service = MockFirebaseAuthService()
            return try await service.sendVerificationCode(phoneNumber: phoneNumber)
        },
        
        verifyPhoneCode: { verificationID, verificationCode in
            let service = MockFirebaseAuthService()
            let authResult = try await service.verifyPhoneCode(verificationID: verificationID, verificationCode: verificationCode)
            
            // Store Firebase credentials in shared state
            @Shared(.isAuthenticated) var isAuthenticated
            @Shared(.firebaseUID) var firebaseUID
            @Shared(.firebaseIdToken) var firebaseIdToken
            @Shared(.firebaseRefreshToken) var firebaseRefreshToken
            @Shared(.firebaseTokenExpiry) var tokenExpiry
            @Shared(.firebaseUser) var firebaseUser
            @Shared(.needsOnboarding) var needsOnboarding
            
            $isAuthenticated.withLock { $0 = true }
            $firebaseUID.withLock { $0 = authResult.user.uid }
            $firebaseIdToken.withLock { $0 = authResult.idToken }
            $firebaseRefreshToken.withLock { $0 = authResult.refreshToken }
            $firebaseTokenExpiry.withLock { $0 = authResult.expiresAt }
            $firebaseUser.withLock { $0 = authResult.user }
            $needsOnboarding.withLock { $0 = true } // New phone users need onboarding
            
            return authResult.user
        },
        
        getIdToken: { forceRefresh in
            let service = MockFirebaseAuthService()
            return try await service.getIdToken(forceRefresh: forceRefresh)
        },
        
        refreshToken: {
            let service = MockFirebaseAuthService()
            let authResult = try await service.refreshToken()
            
            // Update Firebase credentials
            @Shared(.firebaseIdToken) var firebaseIdToken
            @Shared(.firebaseRefreshToken) var firebaseRefreshToken
            @Shared(.firebaseTokenExpiry) var tokenExpiry
            @Shared(.firebaseUser) var firebaseUser
            
            $firebaseIdToken.withLock { $0 = authResult.idToken }
            $firebaseRefreshToken.withLock { $0 = authResult.refreshToken }
            $firebaseTokenExpiry.withLock { $0 = authResult.expiresAt }
            $firebaseUser.withLock { $0 = authResult.user }
        },
        
        signOut: {
            let service = MockFirebaseAuthService()
            try await service.signOut()
            
            // Clear all user state
            await Self.clearAllUserState()
        },
        
        deleteAccount: {
            let service = MockFirebaseAuthService()
            try await service.deleteAccount()
            
            // Clear all user state
            await Self.clearAllUserState()
        },
        
        isAuthenticated: {
            @Shared(.isAuthenticated) var isAuthenticated
            return isAuthenticated
        },
        
        needsOnboarding: {
            return await Self.getOnboardingStatus()
        },
        
        getCurrentAuthUser: {
            @Shared(.firebaseUser) var firebaseUser
            return firebaseUser
        },
        
        completeOnboarding: {
            // Simulate delay
            try await Task.sleep(for: .milliseconds(200))
            
            await Self.setOnboardingCompleted()
        },
        
        skipOnboarding: {
            // Simulate delay
            try await Task.sleep(for: .milliseconds(100))
            
            await Self.setOnboardingCompleted()
        },
        
        validatePhoneNumber: { phone in
            let cleaned = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
            if cleaned.isEmpty { return .invalid("Phone number is required") }
            if cleaned.hasPrefix("+") {
                return cleaned.count >= 8 && cleaned.count <= 16 ? .valid : .invalid("Invalid international phone number")
            } else {
                return cleaned.count == 10 ? .valid : .invalid("Phone number must be 10 digits")
            }
        },
        
        validateName: { name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return .invalid("Name is required") }
            return trimmed.count >= 2 && trimmed.count <= 50 ? .valid : .invalid("Name must be 2-50 characters")
        },
        
        validateVerificationCode: { code in
            let cleaned = code.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            return cleaned.count == 6 ? .valid : .invalid("Verification code must be 6 digits")
        },
        
        formatPhoneNumber: { phoneNumber, region in
            let digits = phoneNumber.filter { $0.isNumber }
            
            guard !digits.isEmpty else { return "" }
            
            switch region {
            case "US", "CA":
                return Self.formatUSPhoneNumber(digits)
            case "UK":
                return Self.formatUKPhoneNumber(digits)
            case "AU":
                return Self.formatAUPhoneNumber(digits)
            default:
                return Self.formatUSPhoneNumber(digits)
            }
        },
        
        formatPhoneNumberForEditing: { phoneNumber, region in
            let digits = phoneNumber.filter { $0.isNumber }
            
            guard !digits.isEmpty else { return "" }
            
            switch region {
            case "US", "CA":
                return Self.formatUSPhoneNumberForEditing(digits)
            case "UK":
                return Self.formatUKPhoneNumberForEditing(digits)
            case "AU":
                return Self.formatAUPhoneNumberForEditing(digits)
            default:
                return Self.formatUSPhoneNumberForEditing(digits)
            }
        }
    )
}

// MARK: - Phone Formatting Helpers

extension AuthenticationClient {
    static func formatUSPhoneNumber(_ digits: String) -> String {
        let limitedDigits = String(digits.prefix(10))
        
        if limitedDigits.count == 10 {
            let areaCode = limitedDigits.prefix(3)
            let prefix = limitedDigits.dropFirst(3).prefix(3)
            let lineNumber = limitedDigits.dropFirst(6)
            return "+1 (\(areaCode)) \(prefix)-\(lineNumber)"
        } else if limitedDigits.count > 0 {
            return "+1 \(limitedDigits)"
        } else {
            return ""
        }
    }
    
    static func formatUKPhoneNumber(_ digits: String) -> String {
        let limitedDigits = String(digits.prefix(10))
        
        if limitedDigits.count == 10 {
            let areaCode = limitedDigits.prefix(4)
            let prefix = limitedDigits.dropFirst(4).prefix(3)
            let lineNumber = limitedDigits.dropFirst(7)
            return "+44 \(areaCode) \(prefix) \(lineNumber)"
        } else if limitedDigits.count > 0 {
            return "+44 \(limitedDigits)"
        } else {
            return ""
        }
    }
    
    static func formatAUPhoneNumber(_ digits: String) -> String {
        let limitedDigits = String(digits.prefix(10))
        
        if limitedDigits.count == 10 {
            let areaCode = limitedDigits.prefix(4)
            let prefix = limitedDigits.dropFirst(4).prefix(3)
            let lineNumber = limitedDigits.dropFirst(7)
            return "+61 \(areaCode) \(prefix) \(lineNumber)"
        } else if limitedDigits.count > 0 {
            return "+61 \(limitedDigits)"
        } else {
            return ""
        }
    }
    
    static func formatUSPhoneNumberForEditing(_ digits: String) -> String {
        let limitedDigits = String(digits.prefix(10))
        
        if limitedDigits.count > 6 {
            let areaCode = limitedDigits.prefix(3)
            let prefix = limitedDigits.dropFirst(3).prefix(3)
            let lineNumber = limitedDigits.dropFirst(6)
            return "\(areaCode)-\(prefix)-\(lineNumber)"
        } else if limitedDigits.count > 3 {
            let areaCode = limitedDigits.prefix(3)
            let prefix = limitedDigits.dropFirst(3)
            return "\(areaCode)-\(prefix)"
        } else if limitedDigits.count > 0 {
            return limitedDigits
        } else {
            return ""
        }
    }
    
    static func formatUKPhoneNumberForEditing(_ digits: String) -> String {
        let limitedDigits = String(digits.prefix(10))
        
        if limitedDigits.count > 7 {
            let areaCode = limitedDigits.prefix(4)
            let prefix = limitedDigits.dropFirst(4).prefix(3)
            let lineNumber = limitedDigits.dropFirst(7)
            return "\(areaCode)-\(prefix)-\(lineNumber)"
        } else if limitedDigits.count > 4 {
            let areaCode = limitedDigits.prefix(4)
            let prefix = limitedDigits.dropFirst(4)
            return "\(areaCode)-\(prefix)"
        } else if limitedDigits.count > 0 {
            return limitedDigits
        } else {
            return ""
        }
    }
    
    static func formatAUPhoneNumberForEditing(_ digits: String) -> String {
        let limitedDigits = String(digits.prefix(10))
        
        if limitedDigits.count > 7 {
            let areaCode = limitedDigits.prefix(4)
            let prefix = limitedDigits.dropFirst(4).prefix(3)
            let lineNumber = limitedDigits.dropFirst(7)
            return "\(areaCode)-\(prefix)-\(lineNumber)"
        } else if limitedDigits.count > 4 {
            let areaCode = limitedDigits.prefix(4)
            let prefix = limitedDigits.dropFirst(4)
            return "\(areaCode)-\(prefix)"
        } else if limitedDigits.count > 0 {
            return limitedDigits
        } else {
            return ""
        }
    }
}

extension DependencyValues {
    var authenticationClient: AuthenticationClient {
        get { self[AuthenticationClient.self] }
        set { self[AuthenticationClient.self] = newValue }
    }
}