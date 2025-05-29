import Foundation
import ComposableArchitecture
import Dependencies
import DependenciesMacros
@_exported import Sharing

// MARK: - Onboarding Shared State

struct OnboardingClientState: Equatable, Codable {
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

// MARK: - Clean Shared Key Implementation (FileStorage)

extension SharedReaderKey where Self == FileStorageKey<OnboardingClientState>.Default {
    static var onboardingInternalState: Self {
        Self[.fileStorage(.documentsDirectory.appending(component: "onboardingInternalState.json")), default: OnboardingClientState()]
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
struct OnboardingClient: ClientContext {
    
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

// MARK: - StateOwner Implementation

extension OnboardingClient {
    nonisolated(unsafe) static var mutationLog: LockIsolated<[StateMutation]> = StateOwnershipHelpers.createMutationLog()
    
    /// Performs tracked mutation on onboarding state
    static func updateOnboardingState(_ operation: String, _ mutation: @escaping (inout OnboardingClientState) -> Void) {
        logMutation(operation, stateType: "OnboardingClientState")
        
        @Shared(.onboardingInternalState) var onboardingState: OnboardingClientState
        $onboardingState.withLock { state in
            mutation(&state)
        }
    }
    
    /// Convenience method for starting onboarding
    static func startOnboarding() {
        updateOnboardingState("startOnboarding") { state in
            state.needsOnboarding = true
            state.isCompleted = false
            state.currentStep = .profileSetup
        }
    }
    
    /// Convenience method for moving to next onboarding step
    static func moveToNextStep() {
        updateOnboardingState("moveToNextStep") { state in
            switch state.currentStep {
            case .profileSetup:
                state.currentStep = .completed
                state.isCompleted = true
                state.needsOnboarding = false
            case .completed:
                // Already completed, no further steps
                break
            }
        }
    }
    
    /// Convenience method for completing profile setup
    static func completeProfileSetup() {
        updateOnboardingState("completeProfileSetup") { state in
            state.hasUserProfile = true
        }
    }
    
    /// Convenience method for completing onboarding
    static func completeOnboarding() {
        updateOnboardingState("completeOnboarding") { state in
            state.isCompleted = true
            state.needsOnboarding = false
            state.currentStep = .completed
        }
    }
    
    /// Convenience method for clearing onboarding state
    static func clearOnboardingState() {
        updateOnboardingState("clearOnboardingState") { state in
            state.needsOnboarding = false
            state.hasUserProfile = false
            state.currentStep = .profileSetup
            state.isCompleted = false
        }
    }
}

extension OnboardingClient: DependencyKey {
    static let liveValue: OnboardingClient = OnboardingClient()
    static let testValue = OnboardingClient()
    
    static let mockValue = OnboardingClient(
        
        // Onboarding flow management
        startOnboarding: {
            @Shared(.onboardingInternalState) var onboardingState
            $onboardingState.withLock { state in
                state.needsOnboarding = true
                state.hasUserProfile = false
                state.currentStep = .profileSetup
                state.isCompleted = false
            }
        },
        
        completeUserProfile: { firstName, lastName, emergencyNote, checkInInterval, reminderMinutes, biometricAuthEnabled in
            // OnboardingClient should only manage its own onboarding state
            // ApplicationFeature should validate authentication and handle UserClient calls
            
            // Mark that the user now has a profile - this is OnboardingClient's responsibility
            @Shared(.onboardingInternalState) var onboardingState
            $onboardingState.withLock { state in
                state.needsOnboarding = true // Still in onboarding until explicitly completed
                state.hasUserProfile = true
                state.currentStep = .completed
                state.isCompleted = false
            }
        },
        
        completeOnboarding: {
            @Shared(.onboardingInternalState) var onboardingState
            
            // Ensure user has completed their profile
            guard onboardingState.hasUserProfile else {
                throw OnboardingClientError.profileCreationFailed
            }
            
            $onboardingState.withLock { state in
                state.needsOnboarding = false
                state.hasUserProfile = true
                state.currentStep = .completed
                state.isCompleted = true
            }
        },
        
        resetOnboarding: {
            @Shared(.onboardingInternalState) var onboardingState
            $onboardingState.withLock { state in
                state.needsOnboarding = true
                state.hasUserProfile = false
                state.currentStep = .profileSetup
                state.isCompleted = false
            }
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
            @Shared(.onboardingInternalState) var onboardingState
            $onboardingState.withLock { state in
                state.needsOnboarding = false
                state.hasUserProfile = false
                state.currentStep = .profileSetup
                state.isCompleted = false
            }
        }
    )
}

// MARK: - OnboardingClient Helper Methods

extension OnboardingClient {
    // Helper methods removed - using direct $state.withLock pattern for thread safety
}

extension DependencyValues {
    var onboardingClient: OnboardingClient {
        get { self[OnboardingClient.self] }
        set { self[OnboardingClient.self] = newValue }
    }
}