import Foundation
import ComposableArchitecture
import Dependencies
import DependenciesMacros
@_exported import Sharing

// MARK: - Onboarding Shared State

// 1. Mutable internal state (private to Client)
struct OnboardingInternalState: Equatable, Codable {
    var needsOnboarding: Bool
    var hasUserProfile: Bool
    var currentStep: OnboardingStep
    var isCompleted: Bool
    
    init(
        needsOnboarding: Bool = false,
        hasUserProfile: Bool = false,
        currentStep: OnboardingStep = .profileSetup,
        isCompleted: Bool = false
    ) {
        self.needsOnboarding = needsOnboarding
        self.hasUserProfile = hasUserProfile
        self.currentStep = currentStep
        self.isCompleted = isCompleted
    }
}

// 2. Read-only wrapper (prevents direct mutation)
struct ReadOnlyOnboardingState: Equatable, Codable {
    private let _state: OnboardingInternalState
    
    // 🔑 Only Client can access this init (same file = fileprivate access)
    fileprivate init(_ state: OnboardingInternalState) {
        self._state = state
    }
    
    // MARK: - Codable Implementation (Preserves Ownership Pattern)
    
    private enum CodingKeys: String, CodingKey {
        case state = "_state"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let state = try container.decode(OnboardingInternalState.self, forKey: .state)
        self.init(state)  // Uses fileprivate init - ownership preserved ✅
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(_state, forKey: .state)
    }
    
    // Read-only accessors
    var needsOnboarding: Bool { _state.needsOnboarding }
    var hasUserProfile: Bool { _state.hasUserProfile }
    var currentStep: OnboardingStep { _state.currentStep }
    var isCompleted: Bool { _state.isCompleted }
}

// MARK: - RawRepresentable Conformance for AppStorage (Preserves Ownership)

extension ReadOnlyOnboardingState: RawRepresentable {
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
            self = try DecoderHolder.decoder.decode(ReadOnlyOnboardingState.self, from: data)
        } catch {
            return nil
        }
    }
}

extension SharedReaderKey where Self == AppStorageKey<ReadOnlyOnboardingState>.Default {
    static var onboardingInternalState: Self {
        Self[.appStorage("onboardingInternalState"), default: ReadOnlyOnboardingState(OnboardingInternalState())]
    }
}

// MARK: - Onboarding Types

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

enum OnboardingStep: String, Codable, CaseIterable, Sendable {
    case profileSetup = "profileSetup"
    case completed = "completed"
    
    var displayName: String {
        switch self {
        case .profileSetup: return "Profile Setup"
        case .completed: return "Completed"
        }
    }
}

// MARK: - Onboarding Client Errors

enum OnboardingClientError: Error, LocalizedError {
    case invalidStep
    case profileCreationFailed
    case onboardingNotStarted
    case alreadyCompleted
    
    var errorDescription: String? {
        switch self {
        case .invalidStep:
            return "Invalid onboarding step"
        case .profileCreationFailed:
            return "Failed to create user profile"
        case .onboardingNotStarted:
            return "Onboarding has not been started"
        case .alreadyCompleted:
            return "Onboarding has already been completed"
        }
    }
}

// MARK: - Onboarding Client

/// The dedicated client for managing user onboarding flow and state.
/// 
/// OnboardingClient manages the onboarding process separate from session management,
/// following the single responsibility principle and TCA Shared State Pattern.
///
/// Key responsibilities:
/// - Onboarding flow progression and step management
/// - User profile creation and completion tracking
/// - Onboarding state persistence and restoration
/// - Integration with UserClient for profile data management
@DependencyClient
struct OnboardingClient {
    
    // MARK: - Onboarding Flow Management
    
    /// Starts the onboarding process for a new user.
    var startOnboarding: @Sendable () async throws -> Void = { }
    
    /// Completes the user profile setup during onboarding.
    /// Creates or updates user profile via UserClient and marks profile as completed.
    var completeUserProfile: @Sendable (String, String, String, TimeInterval, Int, Bool) async throws -> Void = { _, _, _, _, _, _ in }
    
    /// Marks the onboarding process as completed.
    var completeOnboarding: @Sendable () async throws -> Void = { }
    
    /// Resets the onboarding state (for testing or re-onboarding scenarios).
    var resetOnboarding: @Sendable () async throws -> Void = { }
    
    // MARK: - Onboarding State
    
    /// Gets the current onboarding status.
    var needsOnboarding: @Sendable () -> Bool = { false }
    
    /// Checks if the user has completed their profile.
    var hasUserProfile: @Sendable () -> Bool = { false }
    
    /// Gets the current onboarding step.
    var getCurrentStep: @Sendable () -> OnboardingStep = { .profileSetup }
    
    /// Checks if onboarding is completed.
    var isCompleted: @Sendable () -> Bool = { false }
    
    // MARK: - Input Validation
    
    /// Validates a user name for profile creation/updates.
    var validateName: @Sendable (String) -> ValidationResult = { _ in .valid }
    
    // MARK: - State Management
    
    /// Clears onboarding state (used during sign out).
    var clearOnboardingState: @Sendable () async throws -> Void = { }
}

extension OnboardingClient: DependencyKey {
    static let liveValue: OnboardingClient = OnboardingClient()
    static let testValue = OnboardingClient()
    
    static let mockValue = OnboardingClient(
        
        // Onboarding flow management
        startOnboarding: {
            Self.updateOnboardingState(
                needsOnboarding: true,
                hasUserProfile: false,
                currentStep: .profileSetup,
                isCompleted: false
            )
        },
        
        completeUserProfile: { firstName, lastName, emergencyNote, checkInInterval, reminderMinutes, biometricAuthEnabled in
            // OnboardingClient should only manage its own onboarding state
            // ApplicationFeature should validate authentication and handle UserClient calls
            
            // Mark that the user now has a profile - this is OnboardingClient's responsibility
            Self.updateOnboardingState(
                needsOnboarding: true, // Still in onboarding until explicitly completed
                hasUserProfile: true,
                currentStep: .completed,
                isCompleted: false
            )
        },
        
        completeOnboarding: {
            @Shared(.onboardingInternalState) var onboardingState
            
            // Ensure user has completed their profile
            guard onboardingState.hasUserProfile else {
                throw OnboardingClientError.profileCreationFailed
            }
            
            Self.updateOnboardingState(
                needsOnboarding: false,
                hasUserProfile: true,
                currentStep: .completed,
                isCompleted: true
            )
        },
        
        resetOnboarding: {
            Self.updateOnboardingState(
                needsOnboarding: true,
                hasUserProfile: false,
                currentStep: .profileSetup,
                isCompleted: false
            )
        },
        
        // Onboarding state
        needsOnboarding: {
            @Shared(.onboardingInternalState) var onboardingState
            return onboardingState.needsOnboarding
        },
        
        hasUserProfile: {
            @Shared(.onboardingInternalState) var onboardingState
            return onboardingState.hasUserProfile
        },
        
        getCurrentStep: {
            @Shared(.onboardingInternalState) var onboardingState
            return onboardingState.currentStep
        },
        
        isCompleted: {
            @Shared(.onboardingInternalState) var onboardingState
            return onboardingState.isCompleted
        },
        
        // Input validation
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
        
        clearOnboardingState: {
            Self.clearOnboardingState()
        }
    )
}

// MARK: - OnboardingClient Helper Methods

extension OnboardingClient {
    
    /// Updates onboarding state using unified state pattern
    static func updateOnboardingState(
        needsOnboarding: Bool,
        hasUserProfile: Bool,
        currentStep: OnboardingStep,
        isCompleted: Bool
    ) {
        // Ensure this runs on main thread to prevent memory access violations
        if Thread.isMainThread {
            updateOnboardingStateSync(
                needsOnboarding: needsOnboarding,
                hasUserProfile: hasUserProfile,
                currentStep: currentStep,
                isCompleted: isCompleted
            )
        } else {
            DispatchQueue.main.sync {
                updateOnboardingStateSync(
                    needsOnboarding: needsOnboarding,
                    hasUserProfile: hasUserProfile,
                    currentStep: currentStep,
                    isCompleted: isCompleted
                )
            }
        }
    }
    
    /// Synchronously updates onboarding state - must be called on main thread
    private static func updateOnboardingStateSync(
        needsOnboarding: Bool,
        hasUserProfile: Bool,
        currentStep: OnboardingStep,
        isCompleted: Bool
    ) {
        @Shared(.onboardingInternalState) var sharedOnboardingState
        
        // Update shared state using read-only wrapper pattern
        let mutableState = OnboardingInternalState(
            needsOnboarding: needsOnboarding,
            hasUserProfile: hasUserProfile,
            currentStep: currentStep,
            isCompleted: isCompleted
        )
        $sharedOnboardingState.withLock { $0 = ReadOnlyOnboardingState(mutableState) }
    }
    
    /// Clears all onboarding state
    static func clearOnboardingState() {
        Self.updateOnboardingState(
            needsOnboarding: false,
            hasUserProfile: false,
            currentStep: .profileSetup,
            isCompleted: false
        )
    }
}

extension DependencyValues {
    var onboardingClient: OnboardingClient {
        get { self[OnboardingClient.self] }
        set { self[OnboardingClient.self] = newValue }
    }
}