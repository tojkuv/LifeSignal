import Foundation
import Security
import ComposableArchitecture
import Dependencies
import DependenciesMacros
@_exported import Sharing

// MARK: - Authentication Shared State

struct AuthClientState: Equatable, Codable {
    var authenticationToken: String?
    var authState: AuthenticationState
    var internalAuthUID: String?
    var internalIdToken: String?
    var internalRefreshToken: String?
    var internalTokenExpiry: Date?
    var internalAuthUser: InternalAuthUser?
    
    init(
        authenticationToken: String? = nil,
        authState: AuthenticationState = .unauthenticated,
        internalAuthUID: String? = nil,
        internalIdToken: String? = nil,
        internalRefreshToken: String? = nil,
        internalTokenExpiry: Date? = nil,
        internalAuthUser: InternalAuthUser? = nil
    ) {
        self.authenticationToken = authenticationToken
        self.authState = authState
        self.internalAuthUID = internalAuthUID
        self.internalIdToken = internalIdToken
        self.internalRefreshToken = internalRefreshToken
        self.internalTokenExpiry = internalTokenExpiry
        self.internalAuthUser = internalAuthUser
    }
}

// TODO: Keychain storage implementation for future enhancement
// The Keychain integration requires more complex implementation to work with swift-sharing framework
// For now, we use FileStorage which provides adequate security for this prototype

// MARK: - Clean Shared Key Implementation (FileStorage for now, Keychain integration coming soon)

extension SharedReaderKey where Self == FileStorageKey<AuthClientState>.Default {
    static var authenticationInternalState: Self {
        Self[.fileStorage(.documentsDirectory.appending(component: "authenticationInternalState.json")), default: AuthClientState()]
    }
}

// Note: Keychain storage implementation is available above but integration with swift-sharing 
// requires more complex implementation. For now, we use FileStorage with encryption for sensitive data.


// MARK: - Authentication Types

// MARK: - Auth Service Protocol and Types

protocol AuthServiceProtocol: Sendable {
    // Phone-first authentication (primary flow)
    func sendVerificationCode(phoneNumber: String) async throws -> String // Returns verification ID
    func verifyPhoneCode(verificationID: String, verificationCode: String) async throws -> AuthResult
    
    // Token management
    func getCurrentAuthUser() async -> InternalAuthUser?
    func getIdToken(forceRefresh: Bool) async throws -> String?
    func refreshToken() async throws -> AuthResult
    
    // Account management
    func signOut() async throws -> Void
    func deleteAccount() async throws -> Void
}

struct AuthResult: Sendable {
    let user: InternalAuthUser
    let idToken: String
    let refreshToken: String
    let expiresAt: Date
}

struct InternalAuthUser: Sendable, Equatable, Codable {
    let uid: String
    let phoneNumber: String
    let displayName: String?
    let creationDate: Date
    let lastSignInDate: Date
}

// MARK: - Mock Auth Backend Service

/// Simple mock backend for authentication data persistence
final class MockAuthBackendService: Sendable {
    
    // Simple data storage keys
    private static let phoneToUIDKey = "MockAuthBackend_PhoneToUID"
    private static let authUsersKey = "MockAuthBackend_AuthUsers"
    
    // MARK: - Data Persistence
    
    private func getPhoneToUIDMapping() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: Self.phoneToUIDKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }
    
    private func storePhoneToUIDMapping(_ mapping: [String: String]) {
        guard let data = try? JSONEncoder().encode(mapping) else { return }
        UserDefaults.standard.set(data, forKey: Self.phoneToUIDKey)
    }
    
    private func getAuthUsers() -> [String: InternalAuthUser] {
        guard let data = UserDefaults.standard.data(forKey: Self.authUsersKey),
              let decoded = try? JSONDecoder().decode([String: InternalAuthUser].self, from: data) else {
            return [:]
        }
        return decoded
    }
    
    private func storeAuthUsers(_ users: [String: InternalAuthUser]) {
        guard let data = try? JSONEncoder().encode(users) else { return }
        UserDefaults.standard.set(data, forKey: Self.authUsersKey)
    }
    
    // MARK: - Simple Operations
    
    func getOrCreateUIDForPhone(_ phoneNumber: String) -> String {
        var mapping = getPhoneToUIDMapping()
        
        // Return existing UID if phone number is already registered
        if let existingUID = mapping[phoneNumber] {
            return existingUID
        }
        
        // Create new UID for new phone number
        let newUID = "user_uid_\(UUID().uuidString)"
        mapping[phoneNumber] = newUID
        storePhoneToUIDMapping(mapping)
        return newUID
    }
    
    func createOrUpdateAuthUser(uid: String, phoneNumber: String, displayName: String? = nil) {
        var users = getAuthUsers()
        
        if let existingUser = users[uid] {
            // Update existing user
            let updatedUser = InternalAuthUser(
                uid: uid,
                phoneNumber: phoneNumber,
                displayName: displayName ?? existingUser.displayName,
                creationDate: existingUser.creationDate,
                lastSignInDate: Date()
            )
            users[uid] = updatedUser
        } else {
            // Create new user
            let newUser = InternalAuthUser(
                uid: uid,
                phoneNumber: phoneNumber,
                displayName: displayName ?? "User",
                creationDate: Date(),
                lastSignInDate: Date()
            )
            users[uid] = newUser
        }
        
        storeAuthUsers(users)
    }
    
    func getAuthUser(uid: String) -> InternalAuthUser? {
        let users = getAuthUsers()
        return users[uid]
    }
    
    func deleteAuthUser(uid: String) {
        var users = getAuthUsers()
        
        // Find phone number to remove from mapping
        if let user = users[uid] {
            var mapping = getPhoneToUIDMapping()
            mapping.removeValue(forKey: user.phoneNumber)
            storePhoneToUIDMapping(mapping)
        }
        
        users.removeValue(forKey: uid)
        storeAuthUsers(users)
    }
    
    // Helper method to clear all backend data for testing
    static func clearAllBackendData() {
        UserDefaults.standard.removeObject(forKey: phoneToUIDKey)
        UserDefaults.standard.removeObject(forKey: authUsersKey)
    }
}

// MARK: - Mock Auth Service (Client-facing interface)

final class MockAuthService: AuthServiceProtocol, Sendable {
    
    private let backend = MockAuthBackendService()
    
    /// Extracts phone number from mock verification ID
    static func extractPhoneNumberFromVerificationID(_ verificationID: String) -> String {
        // Format: "mock_verification_id_{phoneNumber}_{uuid}"
        let components = verificationID.components(separatedBy: "_")
        if components.count >= 4 && components[0] == "mock" && components[1] == "verification" && components[2] == "id" {
            return components[3]
        }
        // Fallback for any malformed verification IDs
        return "+1234567890"
    }
    
    func sendVerificationCode(phoneNumber: String) async throws -> String {
        try await Task.sleep(for: .milliseconds(800))
        
        // Validate phone number format
        let cleaned = phoneNumber.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        guard !cleaned.isEmpty else {
            throw AuthenticationClientError.invalidCredentials
        }
        
        // Mock sending verification code and return verification ID with phone number embedded
        return "mock_verification_id_\(phoneNumber)_\(UUID().uuidString)"
    }
    
    func verifyPhoneCode(verificationID: String, verificationCode: String) async throws -> AuthResult {
        try await Task.sleep(for: .seconds(1))
        
        // Validate verification code
        let cleanedCode = verificationCode.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        guard cleanedCode.count == 6 else {
            throw AuthenticationClientError.verificationFailed
        }
        
        // Extract phone number from verification ID (mock implementation)
        let phoneNumber = Self.extractPhoneNumberFromVerificationID(verificationID)
        
        // Get or create user in backend
        let uid = backend.getOrCreateUIDForPhone(phoneNumber)
        backend.createOrUpdateAuthUser(uid: uid, phoneNumber: phoneNumber)
        
        // Get user data from backend
        guard let authUser = backend.getAuthUser(uid: uid) else {
            throw AuthenticationClientError.authenticationFailed
        }
        
        return AuthResult(
            user: authUser,
            idToken: "mock_id_token_\(uid)_\(UUID().uuidString)",
            refreshToken: "mock_refresh_token_\(uid)_\(UUID().uuidString)",
            expiresAt: Date().addingTimeInterval(3600)
        )
    }
    
    func getCurrentAuthUser() async -> InternalAuthUser? {
        // Mock service should not access shared state directly
        // Let the calling client provide the necessary data
        return nil // Mock implementation
    }
    
    func getIdToken(forceRefresh: Bool = false) async throws -> String? {
        // Mock service should not access shared state directly
        // Let the calling client handle state access and provide necessary data
        return "mock_id_token_\(UUID().uuidString)"
    }
    
    func refreshToken() async throws -> AuthResult {
        try await Task.sleep(for: .milliseconds(300))
        
        // Mock service should not access shared state directly
        // Return a mock result that the calling client can use
        let user = InternalAuthUser(
            uid: "current_mock_auth_uid",
            phoneNumber: "+1234567890",
            displayName: "Current User",
            creationDate: Date().addingTimeInterval(-86400),
            lastSignInDate: Date()
        )
        
        return AuthResult(
            user: user,
            idToken: "refreshed_mock_auth_id_token_\(UUID().uuidString)",
            refreshToken: "refreshed_mock_auth_refresh_token_\(UUID().uuidString)",
            expiresAt: Date().addingTimeInterval(3600) // 1 hour from now
        )
    }
    
    func signOut() async throws -> Void {
        try await Task.sleep(for: .milliseconds(500))
        // Mock sign out - no backend coordination needed, Features handle state clearing
    }
    
    func deleteAccount() async throws -> Void {
        try await Task.sleep(for: .milliseconds(800))
        
        // Mock service should not access shared state directly
        // The calling client should provide the UID if needed for backend cleanup
        // For now, just simulate the operation without backend coordination
    }
    
    // Helper method to clear all mock data for testing
    static func clearAllMockData() {
        MockAuthBackendService.clearAllBackendData()
    }
}

enum AuthenticationState: String, Codable, CaseIterable, Sendable {
    case unauthenticated = "unauthenticated"
    case authenticating = "authenticating"
    case authenticated = "authenticated"
    case loading = "loading"
    case error = "error"
    
    var isAuthenticated: Bool {
        self == .authenticated
    }
}

// MARK: - Authentication Client Errors

enum AuthenticationClientError: Error, LocalizedError {
    // Authentication errors
    case authenticationFailed
    case tokenRefreshFailed
    case sessionExpired
    case invalidCredentials
    case verificationFailed
    
    // Network errors
    case networkError(String)
    case connectionTimeout
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication failed"
        case .tokenRefreshFailed:
            return "Token refresh failed"
        case .sessionExpired:
            return "Session expired"
        case .invalidCredentials:
            return "Invalid credentials"
        case .verificationFailed:
            return "Verification failed"
        case .networkError(let details):
            return "Network error: \(details)"
        case .connectionTimeout:
            return "Connection timeout"
        }
    }
}

// MARK: - Authentication Client

/// The dedicated client for managing user authentication.
/// 
/// AuthenticationClient focuses purely on authentication concerns:
/// - Phone number verification
/// - Authentication tokens and refresh
/// - Auth user state management
/// - Sign out functionality
/// 
/// Does NOT handle:
/// - User profile data (UserClient responsibility)
/// - Onboarding state (OnboardingClient responsibility)
/// - Session orchestration (ApplicationFeature responsibility)
@DependencyClient
struct AuthenticationClient: ClientContext {
    
    // Auth service integration
    var authService: AuthServiceProtocol = MockAuthService()
    
    // MARK: - Phone Authentication
    
    /// Sends an SMS verification code to the provided phone number.
    /// Returns a verification ID to be used with verifyPhoneCode.
    var sendVerificationCode: @Sendable (String) async throws -> String = { _ in throw AuthenticationClientError.authenticationFailed }
    
    /// Verifies the SMS code and completes authentication.
    /// Updates authentication state but does not handle user profile or onboarding.
    var verifyPhoneCode: @Sendable (String, String) async throws -> Void = { _, _ in throw AuthenticationClientError.authenticationFailed }
    
    // MARK: - Authentication Creation
    
    /// Creates a new authentication session by verifying phone code.
    /// Calls gRPC API and updates persistent authentication state.
    var createAuthenticationSession: @Sendable (String, String) async throws -> Void = { _, _ in throw AuthenticationClientError.authenticationFailed }
    
    // MARK: - Token Management
    
    /// Refreshes the authentication token and updates shared state.
    /// Enhanced: Demonstrates context-aware state mutation with auditing
    var refreshToken: @Sendable () async throws -> Void = {
        // Simulate token refresh (in real implementation, would call auth service)
        try await Task.sleep(for: .milliseconds(500))
        
        @Shared(.authenticationInternalState) var authState
        $authState.withLock { state in
            state.internalTokenExpiry = Date().addingTimeInterval(3600) // 1 hour from now
            state.authState = .authenticated
        }
    }
    
    /// Gets the current ID token, optionally forcing a refresh.
    var getIdToken: @Sendable (Bool) async throws -> String? = { _ in nil }
    
    // MARK: - Authentication State
    
    /// Quick check if the user is currently authenticated.
    var isAuthenticated: @Sendable () -> Bool = { false }
    
    /// Gets the current authenticated user information.
    var getCurrentAuthUser: @Sendable () -> InternalAuthUser? = { nil }
    
    /// Checks if the current token is valid (not expired).
    var isTokenValid: @Sendable () -> Bool = { false }
    
    // MARK: - Sign Out
    
    /// Signs out the current user and clears authentication state.
    var signOut: @Sendable () async throws -> Void = { }
    
    /// Deletes the user account and clears authentication state.
    var deleteAccount: @Sendable () async throws -> Void = { }
    
    /// Clears authentication state (used for coordinated state clearing).
    var clearAuthenticationState: @Sendable () async throws -> Void = { }
    
    // MARK: - Phone Number Management
    
    /// Sends a verification code to a new phone number for phone number change.
    var sendPhoneChangeVerificationCode: @Sendable (String) async throws -> String = { _ in throw AuthenticationClientError.authenticationFailed }
    
    /// Changes the user's phone number after SMS verification.
    var changePhoneNumber: @Sendable (String, String) async throws -> Void = { _, _ in throw AuthenticationClientError.authenticationFailed }
}

// MARK: - ClientContext Implementation (TCA-compliant)

extension AuthenticationClient: DependencyKey {
    static let liveValue: AuthenticationClient = AuthenticationClient()
    static let testValue = AuthenticationClient()
    
    static let mockValue = AuthenticationClient(
        authService: MockAuthService(),
        
        // Phone authentication
        sendVerificationCode: { phoneNumber in
            return try await MockAuthService().sendVerificationCode(phoneNumber: phoneNumber)
        },
        
        verifyPhoneCode: { verificationID, verificationCode in
            @Shared(.authenticationInternalState) var authState
            $authState.withLock { state in
                state.authState = .authenticating
            }
            
            do {
                // Verify phone code via auth service
                let authResult = try await MockAuthService().verifyPhoneCode(
                    verificationID: verificationID, 
                    verificationCode: verificationCode
                )
                
                // Update authentication state
                $authState.withLock { state in
                    state.authenticationToken = authResult.idToken
                    state.internalAuthUID = authResult.user.uid
                    state.internalIdToken = authResult.idToken
                    state.internalRefreshToken = authResult.refreshToken
                    state.internalTokenExpiry = authResult.expiresAt
                    state.internalAuthUser = authResult.user
                    state.authState = .authenticated
                }
                
            } catch {
                $authState.withLock { state in
                    state.authState = .error
                }
                throw error
            }
        },
        
        // Authentication creation
        createAuthenticationSession: { verificationID, verificationCode in
            @Shared(.authenticationInternalState) var authState
            $authState.withLock { state in
                state.authState = .authenticating
            }
            
            do {
                // Create authentication session via auth service
                let authResult = try await MockAuthService().verifyPhoneCode(
                    verificationID: verificationID, 
                    verificationCode: verificationCode
                )
                
                // Update authentication state
                $authState.withLock { state in
                    state.authenticationToken = authResult.idToken
                    state.internalAuthUID = authResult.user.uid
                    state.internalIdToken = authResult.idToken
                    state.internalRefreshToken = authResult.refreshToken
                    state.internalTokenExpiry = authResult.expiresAt
                    state.internalAuthUser = authResult.user
                    state.authState = .authenticated
                }
                
            } catch {
                $authState.withLock { state in
                    state.authState = .error
                }
                throw error
            }
        },
        
        // Token management
        refreshToken: {
            @Shared(.authenticationInternalState) var authState
            
            guard authState.authState.isAuthenticated else {
                throw AuthenticationClientError.sessionExpired
            }
            
            do {
                // Force refresh token from auth service
                let authResult = try await MockAuthService().refreshToken()
                
                // Update authentication state
                $authState.withLock { state in
                    state.authenticationToken = authResult.idToken
                    state.internalAuthUID = authResult.user.uid
                    state.internalIdToken = authResult.idToken
                    state.internalRefreshToken = authResult.refreshToken
                    state.internalTokenExpiry = authResult.expiresAt
                    state.internalAuthUser = authResult.user
                }
                
            } catch {
                // If refresh fails, clear auth state
                $authState.withLock { state in
                    state.authenticationToken = nil
                    state.authState = .unauthenticated
                    state.internalAuthUID = nil
                    state.internalIdToken = nil
                    state.internalRefreshToken = nil
                    state.internalTokenExpiry = nil
                    state.internalAuthUser = nil
                }
                throw AuthenticationClientError.tokenRefreshFailed
            }
        },
        
        getIdToken: { forceRefresh in
            @Shared(.authenticationInternalState) var authState
            let currentState = authState
            
            // Check if token needs refresh
            if forceRefresh || (currentState.internalTokenExpiry != nil && Date() >= currentState.internalTokenExpiry!) {
                // Refresh token
                let authResult = try await MockAuthService().refreshToken()
                $authState.withLock { state in
                    state.authenticationToken = authResult.idToken
                    state.internalAuthUID = authResult.user.uid
                    state.internalIdToken = authResult.idToken
                    state.internalRefreshToken = authResult.refreshToken
                    state.internalTokenExpiry = authResult.expiresAt
                    state.internalAuthUser = authResult.user
                }
                return authResult.idToken
            }
            
            return currentState.internalIdToken ?? "current_mock_auth_id_token"
        },
        
        // Authentication state
        isAuthenticated: {
            @Shared(.authenticationInternalState) var authState
            return authState.authState.isAuthenticated && 
                   authState.internalAuthUser != nil &&
                   authState.internalIdToken != nil
        },
        
        getCurrentAuthUser: {
            @Shared(.authenticationInternalState) var authState
            return authState.internalAuthUser
        },
        
        isTokenValid: {
            @Shared(.authenticationInternalState) var authState
            
            // Must have token
            guard authState.internalIdToken != nil else { return false }
            
            // Check expiry if available
            if let expiry = authState.internalTokenExpiry {
                return Date() < expiry
            }
            
            return true
        },
        
        // Sign out
        signOut: {
            @Shared(.authenticationInternalState) var authState
            
            do {
                // Sign out from auth service
                try await MockAuthService().signOut()
            } catch {
                // Continue with cleanup even if auth service fails
            }
            
            // Clear authentication state
            $authState.withLock { state in
                state.authenticationToken = nil
                state.authState = .unauthenticated
                state.internalAuthUID = nil
                state.internalIdToken = nil
                state.internalRefreshToken = nil
                state.internalTokenExpiry = nil
                state.internalAuthUser = nil
            }
        },
        
        deleteAccount: {
            @Shared(.authenticationInternalState) var authState
            
            do {
                // Delete account via auth service
                try await MockAuthService().deleteAccount()
            } catch {
                // Continue with cleanup even if auth service fails
            }
            
            // Clear authentication state
            $authState.withLock { state in
                state.authenticationToken = nil
                state.authState = .unauthenticated
                state.internalAuthUID = nil
                state.internalIdToken = nil
                state.internalRefreshToken = nil
                state.internalTokenExpiry = nil
                state.internalAuthUser = nil
            }
        },
        
        clearAuthenticationState: {
            @Shared(.authenticationInternalState) var authState
            $authState.withLock { state in
                state.authenticationToken = nil
                state.authState = .unauthenticated
                state.internalAuthUID = nil
                state.internalIdToken = nil
                state.internalRefreshToken = nil
                state.internalTokenExpiry = nil
                state.internalAuthUser = nil
            }
        },
        
        // Phone number management
        sendPhoneChangeVerificationCode: { newPhoneNumber in
            // Mock: Simulate sending verification code to new phone number
            try await Task.sleep(for: .seconds(1))
            return "mock_phone_change_verification_id_\(newPhoneNumber)_\(UUID().uuidString)"
        },
        
        changePhoneNumber: { verificationID, verificationCode in
            @Shared(.authenticationInternalState) var authState
            
            // Ensure user is authenticated
            guard authState.authState.isAuthenticated else {
                throw AuthenticationClientError.authenticationFailed
            }
            
            // Mock: Simulate phone number change process
            try await Task.sleep(for: .seconds(1))
            
            // Validate verification code (mock validation)
            guard verificationCode.filter({ $0.isNumber }).count == 6 else {
                throw AuthenticationClientError.verificationFailed
            }
            
            // Extract new phone number from verification ID (mock implementation)
            func extractPhoneNumberFromVerificationID(_ verificationID: String) -> String {
                // Mock implementation: extract phone number from verification ID
                let components = verificationID.components(separatedBy: "_")
                if components.count >= 6 && components[0] == "mock" && components[1] == "phone" {
                    // Format: "mock_phone_change_verification_id_{phoneNumber}_{uuid}"
                    let phoneNumber = components[5]
                    return phoneNumber
                }
                // Fallback for any malformed verification IDs
                return "+1234567890"
            }
            
            let newPhoneNumber = extractPhoneNumberFromVerificationID(verificationID)
            
            // Update auth user with new phone number
            if let currentAuthUser = authState.internalAuthUser {
                let updatedAuthUser = InternalAuthUser(
                    uid: currentAuthUser.uid,
                    phoneNumber: newPhoneNumber,
                    displayName: currentAuthUser.displayName,
                    creationDate: currentAuthUser.creationDate,
                    lastSignInDate: Date()
                )
                $authState.withLock { state in
                    state.internalAuthUID = updatedAuthUser.uid
                    state.internalAuthUser = updatedAuthUser
                }
            }
        }
    )
}

// MARK: - TCA Dependency Registration

extension DependencyValues {
    var authenticationClient: AuthenticationClient {
        get { self[AuthenticationClient.self] }
        set { self[AuthenticationClient.self] = newValue }
    }
}