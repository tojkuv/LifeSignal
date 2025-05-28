import Foundation
import ComposableArchitecture
import Dependencies
import DependenciesMacros
import UserNotifications
import Network
@_exported import Sharing

// MARK: - Session Shared State

// 1. Mutable internal state (private to Client)
struct SessionInternalState: Equatable, Codable {
    var authenticationToken: String?
    var sessionState: SessionState
    var needsOnboarding: Bool
    var internalAuthUID: String?
    var internalIdToken: String?
    var internalRefreshToken: String?
    var internalTokenExpiry: Date?
    var internalAuthUser: InternalAuthUser?
    var isNetworkConnected: Bool
    var lastNetworkCheck: Date?
    
    init(
        authenticationToken: String? = nil,
        sessionState: SessionState = .unauthenticated,
        needsOnboarding: Bool = false,
        internalAuthUID: String? = nil,
        internalIdToken: String? = nil,
        internalRefreshToken: String? = nil,
        internalTokenExpiry: Date? = nil,
        internalAuthUser: InternalAuthUser? = nil,
        isNetworkConnected: Bool = true,
        lastNetworkCheck: Date? = nil
    ) {
        self.authenticationToken = authenticationToken
        self.sessionState = sessionState
        self.needsOnboarding = needsOnboarding
        self.internalAuthUID = internalAuthUID
        self.internalIdToken = internalIdToken
        self.internalRefreshToken = internalRefreshToken
        self.internalTokenExpiry = internalTokenExpiry
        self.internalAuthUser = internalAuthUser
        self.isNetworkConnected = isNetworkConnected
        self.lastNetworkCheck = lastNetworkCheck
    }
}

// 2. Read-only wrapper (prevents direct mutation)
struct ReadOnlySessionState: Equatable, Codable {
    private let _state: SessionInternalState
    
    // 🔑 Only Client can access this init (same file = fileprivate access)
    fileprivate init(_ state: SessionInternalState) {
        self._state = state
    }
    
    // MARK: - Codable Implementation (Preserves Ownership Pattern)
    
    private enum CodingKeys: String, CodingKey {
        case state = "_state"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let state = try container.decode(SessionInternalState.self, forKey: .state)
        self.init(state)  // Uses fileprivate init - ownership preserved ✅
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(_state, forKey: .state)
    }
    
    // Read-only accessors
    var authenticationToken: String? { _state.authenticationToken }
    var sessionState: SessionState { _state.sessionState }
    var needsOnboarding: Bool { _state.needsOnboarding }
    var internalAuthUID: String? { _state.internalAuthUID }
    var internalIdToken: String? { _state.internalIdToken }
    var internalRefreshToken: String? { _state.internalRefreshToken }
    var internalTokenExpiry: Date? { _state.internalTokenExpiry }
    var internalAuthUser: InternalAuthUser? { _state.internalAuthUser }
    var isNetworkConnected: Bool { _state.isNetworkConnected }
    var lastNetworkCheck: Date? { _state.lastNetworkCheck }
}

// MARK: - RawRepresentable Conformance for AppStorage (Preserves Ownership)

extension ReadOnlySessionState: RawRepresentable {
    typealias RawValue = String
    
    var rawValue: String {
        do {
            let data = try JSONEncoder().encode(self)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            print("Failed to encode ReadOnlySessionState: \(error)")
            return ""
        }
    }
    
    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8) else { return nil }
        do {
            self = try JSONDecoder().decode(ReadOnlySessionState.self, from: data)
        } catch {
            print("Failed to decode ReadOnlySessionState: \(error)")
            return nil
        }
    }
}

extension SharedReaderKey where Self == AppStorageKey<ReadOnlySessionState>.Default {
    static var sessionInternalState: Self {
        Self[.appStorage("sessionInternalState"), default: ReadOnlySessionState(SessionInternalState())]
    }
}

// Legacy individual accessors for Features
extension SharedReaderKey where Self == InMemoryKey<String?>.Default {
    static var authenticationToken: Self {
        Self[.inMemory("authenticationToken"), default: nil]
    }
}

extension SharedReaderKey where Self == InMemoryKey<SessionState>.Default {
    static var sessionState: Self {
        Self[.inMemory("sessionState"), default: .unauthenticated]
    }
}

// MARK: - Authentication Shared State

extension SharedReaderKey where Self == InMemoryKey<Bool>.Default {
    static var needsOnboarding: Self {
        Self[.inMemory("needsOnboarding"), default: false]
    }
}

// MARK: - Internal Auth State (Implementation Details - Read-Only Access for Clients)

extension SharedReaderKey where Self == InMemoryKey<String?>.Default {
    static var internalAuthUID: Self {
        Self[.inMemory("internalAuthUID"), default: nil]
    }
}

private extension SharedReaderKey where Self == InMemoryKey<String?>.Default {
    static var internalIdToken: Self {
        Self[.inMemory("internalIdToken"), default: nil]
    }
    
    static var internalRefreshToken: Self {
        Self[.inMemory("internalRefreshToken"), default: nil]
    }
}

private extension SharedReaderKey where Self == InMemoryKey<Date?>.Default {
    static var internalTokenExpiry: Self {
        Self[.inMemory("internalTokenExpiry"), default: nil]
    }
}

private extension SharedReaderKey where Self == InMemoryKey<InternalAuthUser?>.Default {
    static var internalAuthUser: Self {
        Self[.inMemory("internalAuthUser"), default: nil]
    }
}

// MARK: - Network Shared State

extension SharedReaderKey where Self == InMemoryKey<Bool>.Default {
    static var isNetworkConnected: Self {
        Self[.inMemory("isNetworkConnected"), default: true]
    }
}


extension SharedReaderKey where Self == InMemoryKey<Date?>.Default {
    static var lastNetworkCheck: Self {
        Self[.inMemory("lastNetworkCheck"), default: nil]
    }
}

// MARK: - Public Authentication Types

// MARK: - Internal Auth Service Types (Implementation Details)

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

// MARK: - Mapping Extensions

// MARK: - Network Types

enum ConnectionType: String, CaseIterable, Sendable {
    case none = "none"
    case cellular = "cellular"
    case wifi = "wifi"
    case ethernet = "ethernet"
    
    var displayName: String {
        switch self {
        case .none: return "No Connection"
        case .cellular: return "Cellular"
        case .wifi: return "Wi-Fi"
        case .ethernet: return "Ethernet"
        }
    }
}

enum NetworkQuality: String, CaseIterable, Sendable {
    case poor = "poor"
    case fair = "fair"
    case good = "good"
    case excellent = "excellent"
    
    var displayName: String {
        switch self {
        case .poor: return "Poor"
        case .fair: return "Fair"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
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

// MARK: - Session State

enum SessionState: String, Codable, CaseIterable, Sendable {
    case unauthenticated = "unauthenticated"
    case authenticating = "authenticating"
    case authenticated = "authenticated"
    case loading = "loading"
    case error = "error"
    
    var isAuthenticated: Bool {
        self == .authenticated
    }
}


// MARK: - Session Client Errors

enum SessionClientError: Error, LocalizedError {
    // Session errors
    case authenticationFailed
    case tokenRefreshFailed
    case userLoadFailed
    case sessionExpired
    
    // Authentication errors
    case authenticationFailedWithDetails(String)
    case signOutFailed(String)
    case networkError(String)
    case invalidCredentials(String)
    case validationFailed(String)
    
    // Network errors
    case connectionUnavailable(String)
    case connectionTimeout(String)
    case connectionFailure(String)
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication failed"
        case .tokenRefreshFailed:
            return "Token refresh failed"
        case .userLoadFailed:
            return "Failed to load user data"
        case .sessionExpired:
            return "Session expired"
        case .authenticationFailedWithDetails(let details):
            return "Authentication failed: \(details)"
        case .signOutFailed(let details):
            return "Sign out failed: \(details)"
        case .networkError(let details):
            return "Network error: \(details)"
        case .invalidCredentials(let details):
            return "Invalid credentials: \(details)"
        case .validationFailed(let details):
            return "Validation failed: \(details)"
        case .connectionUnavailable(let details):
            return "Network connection unavailable: \(details)"
        case .connectionTimeout(let details):
            return "Network connection timeout: \(details)"
        case .connectionFailure(let details):
            return "Network connection failed: \(details)"
        }
    }
}

// MARK: - Mock Auth Service

final class MockAuthService: AuthServiceProtocol {
    func sendVerificationCode(phoneNumber: String) async throws -> String {
        try await Task.sleep(for: SessionClient.MockDelays.authVerification)
        
        // Validate phone number format
        let cleaned = phoneNumber.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        guard !cleaned.isEmpty else {
            throw SessionClientError.validationFailed("Phone number is required")
        }
        
        // Mock sending verification code and return verification ID
        return "mock_verification_id_\(UUID().uuidString)"
    }
    
    func verifyPhoneCode(verificationID: String, verificationCode: String) async throws -> AuthResult {
        try await Task.sleep(for: SessionClient.MockDelays.phoneVerification)
        
        // Validate verification code
        let cleanedCode = verificationCode.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        guard cleanedCode.count == 6 else {
            throw SessionClientError.validationFailed("Verification code must be 6 digits")
        }
        
        // Simulate phone authentication
        let authUser = InternalAuthUser(
            uid: "mock_auth_uid_\(UUID().uuidString)",
            phoneNumber: "+1234567890", // Would extract from verification flow
            displayName: "Phone User",
            creationDate: Date(),
            lastSignInDate: Date()
        )
        
        return AuthResult(
            user: authUser,
            idToken: "mock_auth_id_token_\(UUID().uuidString)",
            refreshToken: "mock_auth_refresh_token_\(UUID().uuidString)",
            expiresAt: Date().addingTimeInterval(3600) // 1 hour from now
        )
    }
    
    func getCurrentAuthUser() async -> InternalAuthUser? {
        // Mock getting current user from shared state
        @Shared(.internalAuthUser) var authUser
        return authUser
    }
    
    func getIdToken(forceRefresh: Bool = false) async throws -> String? {
        @Shared(.internalIdToken) var idToken
        @Shared(.internalTokenExpiry) var tokenExpiry
        
        // Check if token needs refresh
        if forceRefresh || (tokenExpiry != nil && Date() >= tokenExpiry!) {
            // Mock token refresh
            let refreshResult = try await refreshToken()
            return refreshResult.idToken
        }
        
        return idToken ?? "current_mock_auth_id_token"
    }
    
    func refreshToken() async throws -> AuthResult {
        try await Task.sleep(for: SessionClient.MockDelays.tokenRefresh)
        
        @Shared(.internalAuthUser) var currentUser
        let user = currentUser ?? InternalAuthUser(
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
        try await Task.sleep(for: SessionClient.MockDelays.signOut)
        // Mock sign out
    }
    
    func deleteAccount() async throws -> Void {
        try await Task.sleep(for: SessionClient.MockDelays.accountDeletion)
        // Mock account deletion
    }
}

// MARK: - Session Client

/// The central client for managing user sessions, authentication, and network connectivity.
/// 
/// SessionClient consolidates functionality from the former AuthenticationClient and NetworkClient
/// to provide a unified interface for all session-related operations. Features should only depend
/// on SessionClient and never access authentication providers or network APIs directly.
///
/// Key responsibilities:
/// - Phone-only authentication flow (SMS verification, no passwords)
/// - Session lifecycle management (start, validate, refresh, end)
/// - Network connectivity monitoring and status
/// - Input validation and phone number formatting
/// - Coordination with UserClient and NotificationClient
/// - Shared state management for all session data
@DependencyClient
struct SessionClient {
    // Auth service integration
    var authService: AuthServiceProtocol = MockAuthService()
    
    // MARK: - Session Management
    
    /// Validates an existing session by checking authentication state, token validity, and user data.
    /// Called on app startup and when app becomes active.
    var validateExistingSession: @Sendable () async throws -> Void = { throw SessionClientError.authenticationFailed }
    
    /// Ends the current session by deleting user data, cleaning up notifications, and signing out.
    /// This terminates the backend session to enforce single-session rule.
    var endSession: @Sendable () async throws -> Void = { throw SessionClientError.authenticationFailed }
    
    /// Refreshes the authentication token and updates shared state.
    var refreshToken: @Sendable () async throws -> Void = { throw SessionClientError.tokenRefreshFailed }
    
    
    // MARK: - Phone-Only Authentication
    
    /// Sends an SMS verification code to the provided phone number.
    /// Returns a verification ID to be used with verifyPhoneCodeAndStartSession.
    var sendVerificationCode: @Sendable (String) async throws -> String = { _ in throw SessionClientError.authenticationFailed }
    
    /// Verifies the SMS code and starts a new session if successful.
    /// Coordinates phone authentication, user data loading, and notification setup.
    var verifyPhoneCodeAndStartSession: @Sendable (String, String) async throws -> Void = { _, _ in throw SessionClientError.authenticationFailed }
    
    
    // MARK: - Authentication State
    
    
    /// Starts the onboarding process.
    var startOnboarding: @Sendable () async throws -> Void = { }
    
    /// Updates user profile during onboarding and marks onboarding as completed.
    var completeUserProfile: @Sendable (String, String, String, TimeInterval, Int, Bool) async throws -> Void = { _, _, _, _, _, _ in }
    
    /// Marks onboarding as completed for the current user.
    var completeOnboarding: @Sendable () async throws -> Void = { }
    
    // MARK: - Phone Number Management
    
    /// Sends a verification code to a new phone number for phone number change.
    /// Returns a verification ID to be used with changePhoneNumber.
    var sendPhoneChangeVerificationCode: @Sendable (String) async throws -> String = { _ in throw SessionClientError.authenticationFailed }
    
    /// Changes the user's phone number after SMS verification.
    /// Updates authentication and user profile via UserClient.
    var changePhoneNumber: @Sendable (String, String) async throws -> Void = { _, _ in throw SessionClientError.authenticationFailed }
    
    // MARK: - Input Validation
    
    /// Validates a user name for profile creation/updates.
    var validateName: @Sendable (String) -> ValidationResult = { _ in .valid }
    
    // MARK: - Network Connectivity
    
    /// Updates the network status in shared state.
    var updateNetworkStatus: @Sendable (Bool) async -> Void = { _ in }
    
    /// Provides a stream of connectivity status changes for real-time monitoring.
    var monitorConnectivity: @Sendable () async -> AsyncStream<Bool> = { AsyncStream { _ in } }
    
    // MARK: - Session State
    
    /// Quick check if the user is currently authenticated.
    var isAuthenticated: @Sendable () -> Bool = { false }
    
    /// Quick check of network connectivity without making network calls
    var checkConnectivity: @Sendable () async -> Bool = { true }
    
    // MARK: - Stream Management
    
    /// Starts all real-time streams (notifications, contacts, connectivity)
    var startAllStreams: @Sendable () async throws -> Void = { }
    
    /// Stops all real-time streams
    var stopAllStreams: @Sendable () async throws -> Void = { }
    
    // MARK: - Debug Methods
    
    /// DEBUG ONLY: Creates a mock authenticated session with sample user data, bypassing sign-in and onboarding
    var debugSkipAuthenticationAndOnboarding: @Sendable () async throws -> Void = { }
    
    /// Mock state initialization for development - initializes User shared state with sample data
    var initializeMockUserState: @Sendable () async throws -> Void = { }
    
    /// Mock state initialization for development - initializes Contacts shared state with sample data
    var initializeMockContactsState: @Sendable () async throws -> Void = { }
    
    /// Mock state initialization for development - initializes Notifications shared state with sample data
    var initializeMockNotificationsState: @Sendable () async throws -> Void = { }
    
    /// Mock state initialization for development - initializes all shared states with comprehensive sample data
    var initializeAllMockStates: @Sendable () async throws -> Void = { }
    
}

extension SessionClient: DependencyKey {
    static let liveValue: SessionClient = SessionClient()
    static let testValue = SessionClient()
    
    static let mockValue = SessionClient(
        authService: MockAuthService(),
        
        // Session management
        validateExistingSession: {
            @Shared(.sessionState) var sessionState
            @Shared(.authenticationToken) var authToken
            @Shared(.currentUser) var currentUser
            
            // Set loading state
            $sessionState.withLock { $0 = .loading }
            
            do {
                // Check if we have an authenticated user
                let service = MockAuthService()
                guard let firebaseUser = await service.getCurrentAuthUser() else {
                    Self.setSessionUnauthenticated()
                    throw SessionClientError.authenticationFailed
                }
                
                // Check if token is still valid
                guard let token = try await service.getIdToken(forceRefresh: false) else {
                    Self.setSessionUnauthenticated()
                    throw SessionClientError.sessionExpired
                }
                
                // Store token in shared state
                $authToken.withLock { $0 = token }
                
                // Load current user data via UserClient
                @Dependency(\.userClient) var userClient
                let loadedUser = try await userClient.getUser()
                
                // If user doesn't exist, session becomes unauthenticated
                if currentUser == nil {
                    Self.setSessionUnauthenticated()
                    $authToken.withLock { $0 = nil }
                    throw SessionClientError.userLoadFailed
                }
                
                // Initialize NotificationClient with session and start listening for real-time notifications
                @Dependency(\.notificationClient) var notificationClient
                try await notificationClient.initialize()
                try await notificationClient.startListening()
                
                // Start contact updates stream via ContactsClient
                @Dependency(\.contactsClient) var contactsClient
                // ContactsClient stream will be managed by features that need it
                
                // Set authenticated state
                $sessionState.withLock { $0 = .authenticated }
                
            } catch {
                // Stop any streams that may have started before error
                @Dependency(\.notificationClient) var notificationClient
                try? await notificationClient.stopListening()
                
                // Clear state on error
                Self.clearSessionOnError()
                throw error
            }
        },
        
        endSession: {
            @Shared(.sessionState) var sessionState
            @Shared(.currentUser) var currentUser
            
            // Set loading state
            $sessionState.withLock { $0 = .loading }
            
            do {
                // Stop notification streams and clean up NotificationClient first
                @Dependency(\.notificationClient) var notificationClient
                try await notificationClient.stopListening()
                try await notificationClient.cleanup()
                
                // Delete user data via UserClient
                @Dependency(\.userClient) var userClient
                if let user = currentUser {
                    try await userClient.deleteUser(user.id)
                }
                
                // Sign out from auth service
                try await MockAuthService().signOut()
                
            } catch {
                // Continue with cleanup even if operations fail
            }
            
            // Clear all shared state regardless of errors
            Self.clearAllUserState()
        },
        
        refreshToken: {
            @Shared(.authenticationToken) var authToken
            @Shared(.sessionState) var sessionState
            
            guard sessionState.isAuthenticated else {
                throw SessionClientError.sessionExpired
            }
            
            do {
                // Force refresh token from auth service
                let authResult = try await MockAuthService().refreshToken()
                
                // Update internal auth state
                Self.updateInternalAuthState(from: authResult)
                
            } catch {
                // If refresh fails, end session
                Self.clearSessionOnError()
                throw SessionClientError.tokenRefreshFailed
            }
        },
        
        // Phone authentication
        sendVerificationCode: { phoneNumber in
            return try await MockAuthService().sendVerificationCode(phoneNumber: phoneNumber)
        },
        
        
        verifyPhoneCodeAndStartSession: { verificationID, verificationCode in
            @Shared(.sessionState) var sessionState
            @Shared(.authenticationToken) var authToken
            @Shared(.currentUser) var currentUser
            
            // Set authenticating state
            $sessionState.withLock { $0 = .authenticating }
            
            do {
                // Verify phone code via auth service
                let authResult = try await MockAuthService().verifyPhoneCode(
                    verificationID: verificationID, 
                    verificationCode: verificationCode
                )
                
                // Store authentication state
                Self.updateInternalAuthState(from: authResult)
                
                @Shared(.needsOnboarding) var needsOnboarding
                $needsOnboarding.withLock { $0 = true } // New phone users need onboarding
                
                // Set loading state while fetching user
                $sessionState.withLock { $0 = .loading }
                
                // Try to load existing user via UserClient
                @Dependency(\.userClient) var userClient
                do {
                    let loadedUser = try await userClient.getUser()
                    // UserClient handles shared state updates
                } catch {
                    // User doesn't exist - this is expected for new phone users
                    // Keep auth state for user creation flow
                }
                
                // If user doesn't exist, session remains unauthenticated (needs user creation)
                if currentUser == nil {
                    Self.setSessionUnauthenticated()
                    // Keep Firebase auth but clear session token since no user profile exists
                    $authToken.withLock { $0 = nil }
                    throw SessionClientError.userLoadFailed
                }
                
                // Initialize NotificationClient for authenticated session and start streams
                @Dependency(\.notificationClient) var notificationClient
                try await notificationClient.initialize()
                try await notificationClient.startListening()
                
                // Set authenticated state
                $sessionState.withLock { $0 = .authenticated }
                
            } catch {
                // Stop any streams that may have started before error  
                @Dependency(\.notificationClient) var notificationClient
                try? await notificationClient.stopListening()
                
                // Clear session state on error but preserve auth for potential user creation
                $sessionState.withLock { $0 = .error }
                $authToken.withLock { $0 = nil }
                $currentUser.withLock { $0 = nil }
                throw error
            }
        },
        
        // Authentication state
        
        startOnboarding: {
            // SessionClient handles setting onboarding state
            @Shared(.needsOnboarding) var needsOnboarding
            needsOnboarding = true
        },
        
        completeUserProfile: { firstName, lastName, emergencyNote, checkInInterval, reminderMinutes, biometricAuthEnabled in
            @Shared(.currentUser) var currentUser
            guard var user = currentUser else {
                throw SessionClientError.userLoadFailed
            }
            
            // Update user with all onboarding data
            let fullName = "\(firstName) \(lastName)"
            user.name = fullName
            user.emergencyNote = emergencyNote
            user.checkInInterval = checkInInterval
            
            // Convert reminderMinutes to NotificationPreference
            let notificationPreference: NotificationPreference = switch reminderMinutes {
            case 0: .disabled
            case 30: .thirtyMinutes
            case 120: .twoHours
            default: .thirtyMinutes
            }
            user.notificationPreference = notificationPreference
            user.biometricAuthEnabled = biometricAuthEnabled
            user.lastModified = Date()
            
            // Update user via UserClient - it handles shared state updates
            @Dependency(\.userClient) var userClient
            try await userClient.updateUser(user)
        },
        
        completeOnboarding: {
            Self.setOnboardingCompleted()
        },
        
        // Phone number management
        sendPhoneChangeVerificationCode: { newPhoneNumber in
            // Mock: Simulate sending verification code to new phone number
            try await Task.sleep(for: .seconds(1))
            // Encode phone number in verification ID for mock implementation
            return "mock_phone_change_verification_id_\(newPhoneNumber)_\(UUID().uuidString)"
        },
        
        changePhoneNumber: { verificationID, verificationCode in
            @Shared(.sessionState) var sessionState
            @Shared(.currentUser) var currentUser
            
            // Ensure user is authenticated
            guard sessionState.isAuthenticated else {
                throw SessionClientError.authenticationFailed
            }
            
            guard var user = currentUser else {
                throw SessionClientError.userLoadFailed
            }
            
            // Mock: Simulate phone number change process
            try await Task.sleep(for: .seconds(1))
            
            // Validate verification code (mock validation)
            guard verificationCode.filter({ $0.isNumber }).count == 6 else {
                throw SessionClientError.authenticationFailed
            }
            
            // Extract new phone number from verification ID (mock implementation)
            // In real implementation, this would come from the Firebase auth result
            // For now, extract from verification ID which contains the phone number
            let newPhoneNumber = Self.extractPhoneNumberFromVerificationID(verificationID)
            
            // Update user's phone number in the user profile
            user.phoneNumber = newPhoneNumber
            user.lastModified = Date()
            
            // Update user via UserClient - it handles shared state updates
            @Dependency(\.userClient) var userClient
            try await userClient.updateUser(user)
            
            // Mock: Update internal auth state with new phone number
            @Shared(.internalAuthUser) var internalAuthUser
            if var authUser = internalAuthUser {
                authUser = InternalAuthUser(
                    uid: authUser.uid,
                    phoneNumber: newPhoneNumber,
                    displayName: authUser.displayName,
                    creationDate: authUser.creationDate,
                    lastSignInDate: Date()
                )
                $internalAuthUser.withLock { $0 = authUser }
            }
        },
        
        // Validation methods
        validateName: { name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.isEmpty {
                return .invalid("Name cannot be empty")
            }
            
            if trimmed.count < 2 {
                return .invalid("Name must be at least 2 characters")
            }
            
            if trimmed.count > 50 {
                return .invalid("Name cannot exceed 50 characters")
            }
            
            // Check for valid characters (letters, spaces, hyphens, apostrophes)
            let allowedCharacters = CharacterSet.letters.union(.whitespaces).union(CharacterSet(charactersIn: "-'"))
            if !trimmed.unicodeScalars.allSatisfy(allowedCharacters.contains) {
                return .invalid("Name can only contain letters, spaces, hyphens, and apostrophes")
            }
            
            return .valid
        },
        
        // Network connectivity
        updateNetworkStatus: { connected in
            @Shared(.sessionInternalState) var sharedSessionState
            let currentState = sharedSessionState
            
            // Update shared state using read-only wrapper pattern
            let mutableState = SessionInternalState(
                authenticationToken: currentState.authenticationToken,
                sessionState: currentState.sessionState,
                needsOnboarding: currentState.needsOnboarding,
                internalAuthUID: currentState.internalAuthUID,
                internalIdToken: currentState.internalIdToken,
                internalRefreshToken: currentState.internalRefreshToken,
                internalTokenExpiry: currentState.internalTokenExpiry,
                internalAuthUser: currentState.internalAuthUser,
                isNetworkConnected: connected,
                lastNetworkCheck: Date()
            )
            $sharedSessionState.withLock { $0 = ReadOnlySessionState(mutableState) }
            
            // Update legacy shared state for Features
            @Shared(.isNetworkConnected) var isConnected
            @Shared(.lastNetworkCheck) var lastCheck
            $isConnected.withLock { $0 = connected }
            $lastCheck.withLock { $0 = Date() }
        },
        
        monitorConnectivity: {
            AsyncStream { continuation in
                let monitor = NWPathMonitor()
                let queue = DispatchQueue(label: "NetworkMonitor")
                
                monitor.pathUpdateHandler = { path in
                    let isConnected = path.status == .satisfied
                    continuation.yield(isConnected)
                    
                    // Update shared state
                    Task {
                        @Shared(.isNetworkConnected) var networkConnected
                        @Shared(.lastNetworkCheck) var lastCheck
                        $networkConnected.withLock { $0 = isConnected }
                        $lastCheck.withLock { $0 = Date() }
                    }
                }
                
                monitor.start(queue: queue)
                
                continuation.onTermination = { _ in
                    monitor.cancel()
                }
            }
        },
        
        isAuthenticated: {
            @Shared(.sessionState) var sessionState
            return sessionState.isAuthenticated
        },
        
        checkConnectivity: {
            await withCheckedContinuation { continuation in
                let monitor = NWPathMonitor()
                let queue = DispatchQueue(label: "ConnectivityCheck")
                
                monitor.pathUpdateHandler = { path in
                    let isConnected = path.status == .satisfied
                    monitor.cancel()
                    continuation.resume(returning: isConnected)
                }
                
                monitor.start(queue: queue)
                
                // Timeout after 3 seconds
                DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                    monitor.cancel()
                    continuation.resume(returning: false)
                }
            }
        },
        
        // Stream management
        startAllStreams: {
            @Dependency(\.notificationClient) var notificationClient
            try await notificationClient.startListening()
            
            // ContactsClient streams are managed per-feature as needed
            // Connectivity monitoring is handled via monitorConnectivity method
        },
        
        stopAllStreams: {
            @Dependency(\.notificationClient) var notificationClient
            try await notificationClient.stopListening()
            
            // Other streams will be cancelled when their Tasks are cancelled
        },
        
        // Debug method
        debugSkipAuthenticationAndOnboarding: {
            @Shared(.sessionInternalState) var sharedSessionState
            
            // Create mock auth user
            let mockAuthUser = InternalAuthUser(
                uid: "debug_mock_uid_\(UUID().uuidString)",
                phoneNumber: "+1234567890",
                displayName: "Debug User",
                creationDate: Date().addingTimeInterval(-86400), // 1 day ago
                lastSignInDate: Date()
            )
            
            // Set internal auth state using read-only wrapper pattern
            let mockIdToken = "debug_mock_id_token_\(UUID().uuidString)"
            let mockRefreshToken = "debug_mock_refresh_token_\(UUID().uuidString)"
            let mockExpiry = Date().addingTimeInterval(3600) // 1 hour from now
            
            let mutableState = SessionInternalState(
                authenticationToken: mockIdToken,
                sessionState: .authenticated,
                needsOnboarding: false,
                internalAuthUID: mockAuthUser.uid,
                internalIdToken: mockIdToken,
                internalRefreshToken: mockRefreshToken,
                internalTokenExpiry: mockExpiry,
                internalAuthUser: mockAuthUser,
                isNetworkConnected: true,
                lastNetworkCheck: Date()
            )
            $sharedSessionState.withLock { $0 = ReadOnlySessionState(mutableState) }
            
            // Update legacy shared state for Features
            @Shared(.sessionState) var sessionState
            @Shared(.authenticationToken) var authToken
            @Shared(.needsOnboarding) var needsOnboarding
            @Shared(.internalAuthUID) var internalAuthUID
            @Shared(.internalIdToken) var internalIdToken
            @Shared(.internalRefreshToken) var internalRefreshToken
            @Shared(.internalTokenExpiry) var tokenExpiry
            @Shared(.internalAuthUser) var internalAuthUser
            @Shared(.currentUser) var currentUser
            
            $internalAuthUID.withLock { $0 = mockAuthUser.uid }
            $internalIdToken.withLock { $0 = mockIdToken }
            $internalRefreshToken.withLock { $0 = mockRefreshToken }
            $tokenExpiry.withLock { $0 = mockExpiry }
            $internalAuthUser.withLock { $0 = mockAuthUser }
            $authToken.withLock { $0 = mockIdToken }
            $needsOnboarding.withLock { $0 = false }
            $sessionState.withLock { $0 = .authenticated }
            
            // Create mock user via UserClient
            @Dependency(\.userClient) var userClient
            
            try await userClient.createUser(
                mockAuthUser.uid,        // firebaseUID
                "Debug User",            // name  
                "+1234567890",          // phoneNumber
                "US"                    // phoneRegion
            )
            
            // Set up a realistic last check-in time for debug mode
            if var user = currentUser {
                user.lastCheckedIn = Date().addingTimeInterval(-3600) // 1 hour ago
                user.lastModified = Date()
                try await userClient.updateUser(user)
            }
            
            // Initialize NotificationClient and start streams
            @Dependency(\.notificationClient) var notificationClient
            try await notificationClient.initialize()
            try await notificationClient.startListening()
        },
        
        initializeMockUserState: {
            // Import dependencies first
            @Dependency(\.userClient) var userClient
            
            // Create mock user via UserClient (which handles shared state updates)
            let mockUID = "mock_user_\(UUID().uuidString)"
            try await userClient.createUser(
                mockUID,
                "John Doe",
                "+15551234567",
                "US"
            )
            
            // Update user with additional mock data
            @Shared(.currentUser) var currentUser
            if var user = currentUser {
                user.emergencyNote = "Emergency contact: Jane Doe (spouse) - 555-987-6543"
                user.checkInInterval = 86400 // 24 hours
                user.lastCheckedIn = Date().addingTimeInterval(-7200) // 2 hours ago
                user.notificationPreference = .thirtyMinutes
                user.isEmergencyAlertEnabled = false
                user.lastModified = Date()
                try await userClient.updateUser(user)
            }
        },
        
        initializeMockContactsState: {
            // SessionClient should NOT directly create Contact objects with complex initializers
            // This should be delegated to ContactsClient's own mock initialization methods
            @Dependency(\.contactsClient) var contactsClient
            // Note: ContactsClient would need its own initializeMockState method
            // For now, this is a placeholder that doesn't violate the pattern
        },
        
        initializeMockNotificationsState: {
            // SessionClient should NOT directly manipulate NotificationClient state
            // This should be delegated to NotificationClient's own mock initialization methods
            @Dependency(\.notificationClient) var notificationClient
            // Note: NotificationClient would need its own initializeMockState method
            // For now, this is a placeholder that doesn't violate the pattern
        },
        
        initializeAllMockStates: {
            // SessionClient should coordinate with other Clients via their dependency injection
            // rather than calling its own methods which causes circular references
            
            @Dependency(\.userClient) var userClient
            @Dependency(\.contactsClient) var contactsClient 
            @Dependency(\.notificationClient) var notificationClient
            
            // Note: Each client would need its own initializeMockState method
            // This avoids circular references and respects the TCA Shared State Pattern
        }
    )
}

// MARK: - SessionClient Configuration

extension SessionClient {
    /// Mock delay configurations for consistent testing behavior
    enum MockDelays {
        static let authVerification: Duration = .milliseconds(800)
        static let phoneVerification: Duration = .seconds(1)
        static let tokenRefresh: Duration = .milliseconds(300)
        static let signOut: Duration = .milliseconds(500)
        static let accountDeletion: Duration = .milliseconds(800)
        static let phoneNumberChange: Duration = .seconds(1)
    }
}

// MARK: - SessionClient Helper Methods

extension SessionClient {
    /// Stops all active streams safely
    static func stopAllActiveStreams() async {
        // NotificationClient streams will be stopped via the client methods
        // Connectivity monitoring streams are managed by their respective consumers
        // Contact streams are managed per-feature basis
        // This method provides a centralized way to ensure all streams are stopped
        // Additional stream cleanup can be added here as needed
        }
    
    /// Clears all authentication and user-related state from shared storage
    static func clearAllUserState() {
        @Shared(.sessionInternalState) var sharedSessionState
        let currentState = sharedSessionState
        
        // Clear shared state using read-only wrapper pattern
        let mutableState = SessionInternalState(
            authenticationToken: nil,
            sessionState: .unauthenticated,
            needsOnboarding: false,
            internalAuthUID: nil,
            internalIdToken: nil,
            internalRefreshToken: nil,
            internalTokenExpiry: nil,
            internalAuthUser: nil,
            isNetworkConnected: currentState.isNetworkConnected, // Preserve network state
            lastNetworkCheck: currentState.lastNetworkCheck
        )
        $sharedSessionState.withLock { $0 = ReadOnlySessionState(mutableState) }
        
        // Clear legacy shared state for Features
        @Shared(.internalAuthUID) var internalAuthUID
        @Shared(.internalIdToken) var internalIdToken
        @Shared(.internalRefreshToken) var internalRefreshToken
        @Shared(.internalTokenExpiry) var tokenExpiry
        @Shared(.internalAuthUser) var internalAuthUser
        @Shared(.needsOnboarding) var needsOnboarding
        @Shared(.currentUser) var currentUser
        @Shared(.sessionState) var sessionState
        @Shared(.authenticationToken) var authToken
        @Shared(.userQRCodeImage) var qrCodeImage
        @Shared(.userShareableQRCodeImage) var shareableQRCodeImage
        @Shared(.userAvatarImage) var avatarImage
        
        $internalAuthUID.withLock { $0 = nil }
        $internalIdToken.withLock { $0 = nil }
        $internalRefreshToken.withLock { $0 = nil }
        $tokenExpiry.withLock { $0 = nil }
        $internalAuthUser.withLock { $0 = nil }
        $needsOnboarding.withLock { $0 = false }
        $currentUser.withLock { $0 = nil }
        $sessionState.withLock { $0 = .unauthenticated }
        $authToken.withLock { $0 = nil }
        $qrCodeImage.withLock { $0 = nil }
        $shareableQRCodeImage.withLock { $0 = nil }
        $avatarImage.withLock { $0 = nil }
    }
    
    /// Sets the onboarding completion status
    static func setOnboardingCompleted() {
        @Shared(.sessionInternalState) var sharedSessionState
        let currentState = sharedSessionState
        
        // Update shared state using read-only wrapper pattern
        let mutableState = SessionInternalState(
            authenticationToken: currentState.authenticationToken,
            sessionState: currentState.sessionState,
            needsOnboarding: false,
            internalAuthUID: currentState.internalAuthUID,
            internalIdToken: currentState.internalIdToken,
            internalRefreshToken: currentState.internalRefreshToken,
            internalTokenExpiry: currentState.internalTokenExpiry,
            internalAuthUser: currentState.internalAuthUser,
            isNetworkConnected: currentState.isNetworkConnected,
            lastNetworkCheck: currentState.lastNetworkCheck
        )
        $sharedSessionState.withLock { $0 = ReadOnlySessionState(mutableState) }
        
        // Update legacy shared state for Features
        @Shared(.needsOnboarding) var needsOnboarding
        $needsOnboarding.withLock { $0 = false }
    }
    
    /// Gets the current onboarding status
    static func getOnboardingStatus() -> Bool {
        @Shared(.needsOnboarding) var needsOnboarding
        return needsOnboarding
    }
    
    /// Checks if current session is valid without making network calls
    static func isSessionValid() -> Bool {
        @Shared(.sessionState) var sessionState
        @Shared(.authenticationToken) var authToken
        @Shared(.currentUser) var currentUser
        @Shared(.internalTokenExpiry) var tokenExpiry
        
        // Must have authenticated session state
        guard sessionState.isAuthenticated else { return false }
        
        // Must have authentication token
        guard authToken != nil else { return false }
        
        // Must have current user
        guard currentUser != nil else { return false }
        
        // Check token expiry if available
        if let expiry = tokenExpiry {
            guard Date() < expiry else { return false }
        }
        
        return true
    }
    
    
    /// Clears session state on error
    static func clearSessionOnError() {
        @Shared(.sessionInternalState) var sharedSessionState
        let currentState = sharedSessionState
        
        // Update shared state using read-only wrapper pattern
        let mutableState = SessionInternalState(
            authenticationToken: nil,
            sessionState: .error,
            needsOnboarding: currentState.needsOnboarding,
            internalAuthUID: currentState.internalAuthUID,
            internalIdToken: currentState.internalIdToken,
            internalRefreshToken: currentState.internalRefreshToken,
            internalTokenExpiry: currentState.internalTokenExpiry,
            internalAuthUser: currentState.internalAuthUser,
            isNetworkConnected: currentState.isNetworkConnected,
            lastNetworkCheck: currentState.lastNetworkCheck
        )
        $sharedSessionState.withLock { $0 = ReadOnlySessionState(mutableState) }
        
        // Update legacy shared state for Features
        @Shared(.sessionState) var sessionState
        @Shared(.authenticationToken) var authToken
        @Shared(.currentUser) var currentUser
        
        $sessionState.withLock { $0 = .error }
        $authToken.withLock { $0 = nil }
        $currentUser.withLock { $0 = nil }
    }
    
    /// Sets session state to unauthenticated
    static func setSessionUnauthenticated() {
        @Shared(.sessionInternalState) var sharedSessionState
        let currentState = sharedSessionState
        
        // Update shared state using read-only wrapper pattern
        let mutableState = SessionInternalState(
            authenticationToken: currentState.authenticationToken,
            sessionState: .unauthenticated,
            needsOnboarding: currentState.needsOnboarding,
            internalAuthUID: currentState.internalAuthUID,
            internalIdToken: currentState.internalIdToken,
            internalRefreshToken: currentState.internalRefreshToken,
            internalTokenExpiry: currentState.internalTokenExpiry,
            internalAuthUser: currentState.internalAuthUser,
            isNetworkConnected: currentState.isNetworkConnected,
            lastNetworkCheck: currentState.lastNetworkCheck
        )
        $sharedSessionState.withLock { $0 = ReadOnlySessionState(mutableState) }
        
        // Update legacy shared state for Features
        @Shared(.sessionState) var sessionState
        $sessionState.withLock { $0 = .unauthenticated }
    }
    
    /// Updates internal auth state from auth result
    static func updateInternalAuthState(from authResult: AuthResult) {
        @Shared(.sessionInternalState) var sharedSessionState
        let currentState = sharedSessionState
        
        // Update shared state using read-only wrapper pattern
        let mutableState = SessionInternalState(
            authenticationToken: authResult.idToken,
            sessionState: currentState.sessionState,
            needsOnboarding: currentState.needsOnboarding,
            internalAuthUID: authResult.user.uid,
            internalIdToken: authResult.idToken,
            internalRefreshToken: authResult.refreshToken,
            internalTokenExpiry: authResult.expiresAt,
            internalAuthUser: authResult.user,
            isNetworkConnected: currentState.isNetworkConnected,
            lastNetworkCheck: currentState.lastNetworkCheck
        )
        $sharedSessionState.withLock { $0 = ReadOnlySessionState(mutableState) }
        
        // Update legacy shared state for Features
        @Shared(.internalAuthUID) var internalAuthUID
        @Shared(.internalIdToken) var internalIdToken
        @Shared(.internalRefreshToken) var internalRefreshToken
        @Shared(.internalTokenExpiry) var tokenExpiry
        @Shared(.internalAuthUser) var internalAuthUser
        @Shared(.authenticationToken) var authToken
        
        $internalAuthUID.withLock { $0 = authResult.user.uid }
        $internalIdToken.withLock { $0 = authResult.idToken }
        $internalRefreshToken.withLock { $0 = authResult.refreshToken }
        $tokenExpiry.withLock { $0 = authResult.expiresAt }
        $internalAuthUser.withLock { $0 = authResult.user }
        $authToken.withLock { $0 = authResult.idToken }
    }
    
    // MARK: - Phone Formatting Helpers
    
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
    
    // MARK: - Phone Number Change Helpers
    
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
    var sessionClient: SessionClient {
        get { self[SessionClient.self] }
        set { self[SessionClient.self] = newValue }
    }
}
