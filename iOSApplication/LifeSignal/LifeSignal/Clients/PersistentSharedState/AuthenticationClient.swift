import Foundation
import ComposableArchitecture
import Dependencies
import DependenciesMacros
@_exported import Sharing

// MARK: - Authentication Shared State

// 1. Mutable internal state (private to Client)
struct AuthenticationInternalState: Equatable, Codable {
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

// 2. Read-only wrapper (prevents direct mutation)
struct ReadOnlyAuthenticationState: Equatable, Codable {
    private let _state: AuthenticationInternalState
    
    // 🔑 Only Client can access this init (same file = fileprivate access)
    fileprivate init(_ state: AuthenticationInternalState) {
        self._state = state
    }
    
    // MARK: - Codable Implementation (Preserves Ownership Pattern)
    
    private enum CodingKeys: String, CodingKey {
        case state = "_state"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let state = try container.decode(AuthenticationInternalState.self, forKey: .state)
        self.init(state)  // Uses fileprivate init - ownership preserved ✅
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(_state, forKey: .state)
    }
    
    // Read-only accessors
    var authenticationToken: String? { _state.authenticationToken }
    var authState: AuthenticationState { _state.authState }
    var internalAuthUID: String? { _state.internalAuthUID }
    var internalIdToken: String? { _state.internalIdToken }
    var internalRefreshToken: String? { _state.internalRefreshToken }
    var internalTokenExpiry: Date? { _state.internalTokenExpiry }
    var internalAuthUser: InternalAuthUser? { _state.internalAuthUser }
}

// MARK: - RawRepresentable Conformance for AppStorage (Preserves Ownership)

extension ReadOnlyAuthenticationState: RawRepresentable {
    typealias RawValue = String
    
    var rawValue: String {
        // Use a static encoder to avoid creating new instances repeatedly
        struct EncoderHolder {
            static let encoder: JSONEncoder = {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                return encoder
            }()
        }
        
        do {
            let data = try EncoderHolder.encoder.encode(self)
            guard let jsonString = String(data: data, encoding: .utf8) else {
                return ""
            }
            return jsonString
        } catch {
            return ""
        }
    }
    
    init?(rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        
        guard let data = rawValue.data(using: .utf8) else { 
            return nil 
        }
        
        // Use a static decoder to avoid creating new instances repeatedly
        struct DecoderHolder {
            static let decoder: JSONDecoder = {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return decoder
            }()
        }
        
        do {
            self = try DecoderHolder.decoder.decode(ReadOnlyAuthenticationState.self, from: data)
        } catch {
            return nil
        }
    }
}

extension SharedReaderKey where Self == AppStorageKey<ReadOnlyAuthenticationState>.Default {
    static var authenticationInternalState: Self {
        Self[.appStorage("authenticationInternalState"), default: ReadOnlyAuthenticationState(AuthenticationInternalState())]
    }
}

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
        @Shared(.authenticationInternalState) var authState
        guard let uid = authState.internalAuthUID else { return nil }
        return backend.getAuthUser(uid: uid)
    }
    
    func getIdToken(forceRefresh: Bool = false) async throws -> String? {
        @Shared(.authenticationInternalState) var authState
        
        // Check if token needs refresh
        if forceRefresh || (authState.internalTokenExpiry != nil && Date() >= authState.internalTokenExpiry!) {
            // Mock token refresh
            let refreshResult = try await refreshToken()
            return refreshResult.idToken
        }
        
        return authState.internalIdToken ?? "current_mock_auth_id_token"
    }
    
    func refreshToken() async throws -> AuthResult {
        try await Task.sleep(for: .milliseconds(300))
        
        @Shared(.authenticationInternalState) var authState
        let user = authState.internalAuthUser ?? InternalAuthUser(
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
        
        @Shared(.authenticationInternalState) var authState
        if let uid = authState.internalAuthUID {
            // Remove user from backend
            backend.deleteAuthUser(uid: uid)
        }
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
struct AuthenticationClient {
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
    var refreshToken: @Sendable () async throws -> Void = { throw AuthenticationClientError.tokenRefreshFailed }
    
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
            Self.updateAuthState(.authenticating)
            
            do {
                // Verify phone code via auth service
                let authResult = try await MockAuthService().verifyPhoneCode(
                    verificationID: verificationID, 
                    verificationCode: verificationCode
                )
                
                // Update authentication state
                Self.updateAuthenticationState(from: authResult)
                Self.updateAuthState(.authenticated)
                
            } catch {
                Self.updateAuthState(.error)
                throw error
            }
        },
        
        // Authentication creation
        createAuthenticationSession: { verificationID, verificationCode in
            Self.updateAuthState(.authenticating)
            
            do {
                // Create authentication session via auth service
                let authResult = try await MockAuthService().verifyPhoneCode(
                    verificationID: verificationID, 
                    verificationCode: verificationCode
                )
                
                // Update authentication state
                Self.updateAuthenticationState(from: authResult)
                Self.updateAuthState(.authenticated)
                
            } catch {
                Self.updateAuthState(.error)
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
                Self.updateAuthenticationState(from: authResult)
                
            } catch {
                // If refresh fails, clear auth state
                Self.clearAuthenticationState()
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
                Self.updateAuthenticationState(from: authResult)
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
            do {
                // Sign out from auth service
                try await MockAuthService().signOut()
            } catch {
                // Continue with cleanup even if auth service fails
            }
            
            // Clear authentication state
            Self.clearAuthenticationState()
        },
        
        deleteAccount: {
            do {
                // Delete account via auth service
                try await MockAuthService().deleteAccount()
            } catch {
                // Continue with cleanup even if auth service fails
            }
            
            // Clear authentication state
            Self.clearAuthenticationState()
        },
        
        clearAuthenticationState: {
            Self.clearAuthenticationState()
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
            let newPhoneNumber = Self.extractPhoneNumberFromVerificationID(verificationID)
            
            // Update auth user with new phone number
            if var authUser = authState.internalAuthUser {
                let updatedAuthUser = InternalAuthUser(
                    uid: authUser.uid,
                    phoneNumber: newPhoneNumber,
                    displayName: authUser.displayName,
                    creationDate: authUser.creationDate,
                    lastSignInDate: Date()
                )
                Self.updateAuthUser(updatedAuthUser)
            }
        }
    )
}

// MARK: - AuthenticationClient Helper Methods

extension AuthenticationClient {
    
    /// Updates authentication state using unified state pattern
    static func updateAuthState(_ newState: AuthenticationState) {
        // Ensure this runs on main thread to prevent memory access violations
        if Thread.isMainThread {
            updateAuthStateSync(newState)
        } else {
            DispatchQueue.main.sync {
                updateAuthStateSync(newState)
            }
        }
    }
    
    /// Synchronously updates authentication state - must be called on main thread
    private static func updateAuthStateSync(_ newState: AuthenticationState) {
        @Shared(.authenticationInternalState) var sharedAuthState
        let currentState = sharedAuthState
        
        // Update shared state using read-only wrapper pattern
        let mutableState = AuthenticationInternalState(
            authenticationToken: currentState.authenticationToken,
            authState: newState,
            internalAuthUID: currentState.internalAuthUID,
            internalIdToken: currentState.internalIdToken,
            internalRefreshToken: currentState.internalRefreshToken,
            internalTokenExpiry: currentState.internalTokenExpiry,
            internalAuthUser: currentState.internalAuthUser
        )
        $sharedAuthState.withLock { $0 = ReadOnlyAuthenticationState(mutableState) }
    }
    
    /// Updates authentication state from auth result
    static func updateAuthenticationState(from authResult: AuthResult) {
        // Ensure this runs on main thread to prevent memory access violations
        if Thread.isMainThread {
            updateAuthenticationStateSync(from: authResult)
        } else {
            DispatchQueue.main.sync {
                updateAuthenticationStateSync(from: authResult)
            }
        }
    }
    
    /// Synchronously updates authentication state from auth result - must be called on main thread
    private static func updateAuthenticationStateSync(from authResult: AuthResult) {
        @Shared(.authenticationInternalState) var sharedAuthState
        let currentState = sharedAuthState
        
        // Update shared state using read-only wrapper pattern
        let mutableState = AuthenticationInternalState(
            authenticationToken: authResult.idToken,
            authState: currentState.authState,
            internalAuthUID: authResult.user.uid,
            internalIdToken: authResult.idToken,
            internalRefreshToken: authResult.refreshToken,
            internalTokenExpiry: authResult.expiresAt,
            internalAuthUser: authResult.user
        )
        $sharedAuthState.withLock { $0 = ReadOnlyAuthenticationState(mutableState) }
    }
    
    /// Updates auth user information
    static func updateAuthUser(_ authUser: InternalAuthUser) {
        // Ensure this runs on main thread to prevent memory access violations
        if Thread.isMainThread {
            updateAuthUserSync(authUser)
        } else {
            DispatchQueue.main.sync {
                updateAuthUserSync(authUser)
            }
        }
    }
    
    /// Synchronously updates auth user - must be called on main thread
    private static func updateAuthUserSync(_ authUser: InternalAuthUser) {
        @Shared(.authenticationInternalState) var sharedAuthState
        let currentState = sharedAuthState
        
        // Update shared state using read-only wrapper pattern
        let mutableState = AuthenticationInternalState(
            authenticationToken: currentState.authenticationToken,
            authState: currentState.authState,
            internalAuthUID: authUser.uid,
            internalIdToken: currentState.internalIdToken,
            internalRefreshToken: currentState.internalRefreshToken,
            internalTokenExpiry: currentState.internalTokenExpiry,
            internalAuthUser: authUser
        )
        $sharedAuthState.withLock { $0 = ReadOnlyAuthenticationState(mutableState) }
    }
    
    /// Clears all authentication state
    static func clearAuthenticationState() {
        Self.updateAuthStateSync(.unauthenticated)
        
        @Shared(.authenticationInternalState) var sharedAuthState
        
        // Clear shared state using read-only wrapper pattern
        let mutableState = AuthenticationInternalState(
            authenticationToken: nil,
            authState: .unauthenticated,
            internalAuthUID: nil,
            internalIdToken: nil,
            internalRefreshToken: nil,
            internalTokenExpiry: nil,
            internalAuthUser: nil
        )
        $sharedAuthState.withLock { $0 = ReadOnlyAuthenticationState(mutableState) }
    }
    
    /// Extracts phone number from mock verification ID 
    private static func extractPhoneNumberFromVerificationID(_ verificationID: String) -> String {
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
}

extension DependencyValues {
    var authenticationClient: AuthenticationClient {
        get { self[AuthenticationClient.self] }
        set { self[AuthenticationClient.self] = newValue }
    }
}