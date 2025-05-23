import Foundation
import SwiftUI
import ComposableArchitecture

@Reducer
struct OnboardingFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.needsOnboarding) var needsOnboarding: Bool = false
        @Shared(.currentUser) var currentUser: User? = nil
        
        var currentStep: OnboardingStep = .welcome
        var isLoading = false
        var errorMessage: String?
        var permissionsGranted: [Permission: Bool] = [:]
        
        var progress: Double {
            Double(currentStep.rawValue) / Double(OnboardingStep.allCases.count - 1)
        }
        
        var canProceed: Bool {
            switch currentStep {
            case .welcome:
                return true
            case .permissions:
                return permissionsGranted[.notifications] == true
            case .profile:
                return currentUser != nil
            case .complete:
                return true
            }
        }
        
        enum OnboardingStep: Int, CaseIterable, Equatable {
            case welcome = 0
            case permissions = 1
            case profile = 2
            case complete = 3
            
            var title: String {
                switch self {
                case .welcome: return "Welcome to LifeSignal"
                case .permissions: return "Enable Notifications"
                case .profile: return "Complete Your Profile"
                case .complete: return "You're All Set!"
                }
            }
        }
        
        enum Permission: String, CaseIterable {
            case notifications
            case location
        }
    }
    
    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case nextStep
        case previousStep
        case skipOnboarding
        case completeOnboarding
        case requestPermission(State.Permission)
        case permissionResponse(State.Permission, Result<Bool, Error>)
        case onboardingCompleted
    }
    
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.analytics) var analytics
    
    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .nextStep:
                guard state.canProceed else { return .none }
                
                let nextStepIndex = state.currentStep.rawValue + 1
                if let nextStep = State.OnboardingStep(rawValue: nextStepIndex) {
                    state.currentStep = nextStep
                    state.errorMessage = nil
                    
                    return .run { send in
                        await haptics.impact(.medium)
                        await analytics.track(.featureUsed(feature: "onboarding_step", context: ["step": nextStep.title]))
                    }
                } else {
                    return .send(.completeOnboarding)
                }
                
            case .previousStep:
                let previousStepIndex = state.currentStep.rawValue - 1
                if let previousStep = State.OnboardingStep(rawValue: previousStepIndex) {
                    state.currentStep = previousStep
                    state.errorMessage = nil
                    
                    return .run { _ in
                        await haptics.impact(.medium)
                    }
                }
                return .none
                
            case .skipOnboarding:
                return .run { [state] send in
                    await haptics.impact(.medium)
                    await analytics.track(.featureUsed(feature: "onboarding_skipped", context: ["step": state.currentStep.title]))
                    state.$needsOnboarding.withLock { $0 = false }
                    await send(.onboardingCompleted)
                }
                
            case .completeOnboarding:
                state.currentStep = .complete
                
                return .run { [state] send in
                    await haptics.notification(.success)
                    await analytics.track(.featureUsed(feature: "onboarding_completed", context: [:]))
                    state.$needsOnboarding.withLock { $0 = false }
                    // Small delay to show completion step
                    try? await Task.sleep(for: .seconds(1))
                    await send(.onboardingCompleted)
                }
                
            case let .requestPermission(permission):
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { send in
                    await analytics.track(.featureUsed(feature: "permission_request", context: ["permission": permission.rawValue]))
                    await send(.permissionResponse(permission, Result {
                        // In production, this would request actual system permissions
                        try await Task.sleep(for: .milliseconds(500))
                        return true // Simulate permission granted
                    }))
                }
                
            case let .permissionResponse(permission, .success(granted)):
                state.isLoading = false
                state.permissionsGranted[permission] = granted
                
                if granted {
                    return .run { _ in
                        await haptics.notification(.success)
                    }
                } else {
                    state.errorMessage = "Permission denied for \(permission.rawValue)"
                    return .run { _ in
                        await haptics.notification(.error)
                    }
                }
                
            case let .permissionResponse(permission, .failure(error)):
                state.isLoading = false
                state.errorMessage = "Failed to request \(permission.rawValue) permission: \(error.localizedDescription)"
                return .run { _ in
                    await haptics.notification(.error)
                }
                
            case .onboardingCompleted:
                // This action is handled by the parent reducer
                return .none
            }
        }
    }
}