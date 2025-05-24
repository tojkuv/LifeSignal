import Foundation
import SwiftUI
import ComposableArchitecture
import Perception
import UserNotifications

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
        case startOnboarding
    }

    @Dependency(\.hapticClient) var haptics
    @Dependency(\.analytics) var analytics
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.sessionClient) var sessionClient

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .startOnboarding:
                state.currentStep = .welcome
                state.isLoading = false
                state.errorMessage = nil
                state.permissionsGranted = [:]

                return .run { _ in
                    await analytics.track(.onboardingStarted)
                    await haptics.impact(.light)
                }

            case .nextStep:
                guard state.canProceed else { return .none }

                let currentStepTitle = state.currentStep.title
                let nextStepIndex = state.currentStep.rawValue + 1

                if let nextStep = State.OnboardingStep(rawValue: nextStepIndex) {
                    state.currentStep = nextStep
                    state.errorMessage = nil

                    return .run { _ in
                        await haptics.impact(.medium)
                        await analytics.track(.onboardingCompleted(step: currentStepTitle))
                        await analytics.track(.featureUsed(feature: "onboarding_step", context: [
                            "from_step": currentStepTitle,
                            "to_step": nextStep.title,
                            "step_number": "\(nextStep.rawValue)"
                        ]))
                    }
                } else {
                    return .send(.completeOnboarding)
                }

            case .previousStep:
                let currentStepTitle = state.currentStep.title
                let previousStepIndex = state.currentStep.rawValue - 1

                if let previousStep = State.OnboardingStep(rawValue: previousStepIndex) {
                    state.currentStep = previousStep
                    state.errorMessage = nil

                    return .run { _ in
                        await haptics.impact(.medium)
                        await analytics.track(.featureUsed(feature: "onboarding_back", context: [
                            "from_step": currentStepTitle,
                            "to_step": previousStep.title
                        ]))
                    }
                }
                return .none

            case .skipOnboarding:
                let currentStepTitle = state.currentStep.title
                let currentStepNumber = state.currentStep.rawValue

                // Update shared state immediately  
                state.$needsOnboarding.withLock { $0 = false }
                
                return .run { send in
                    await haptics.impact(.medium)
                    await analytics.track(.onboardingSkipped(step: currentStepTitle))
                    await analytics.track(.featureUsed(feature: "onboarding_skipped", context: [
                        "step": currentStepTitle,
                        "step_number": "\(currentStepNumber)"
                    ]))

                    await send(.onboardingCompleted)
                }

            case .completeOnboarding:
                state.currentStep = .complete
                
                // Update shared state immediately
                state.$needsOnboarding.withLock { $0 = false }

                return .run { [permissionsCount = state.permissionsGranted.count] send in
                    await haptics.notification(.success)
                    await analytics.track(.onboardingCompleted(step: "complete"))
                    await analytics.track(.featureUsed(feature: "onboarding_completed", context: [
                        "total_steps": "\(State.OnboardingStep.allCases.count)",
                        "permissions_granted": "\(permissionsCount)"
                    ]))

                    // Show notifications about successful onboarding
                    let notification = NotificationItem(
                        type: .system,
                        title: "Welcome to LifeSignal!",
                        message: "You're all set up and ready to go."
                    )
                    try? await notificationClient.sendNotification(notification)

                    // Small delay to show completion step
                    try? await Task.sleep(for: .seconds(1.5))
                    await send(.onboardingCompleted)
                }

            case let .requestPermission(permission):
                state.isLoading = true
                state.errorMessage = nil

                return .run { send in
                    await analytics.track(.permissionRequested(permission: permission.rawValue))
                    await analytics.track(.featureUsed(feature: "permission_request", context: [
                        "permission": permission.rawValue,
                        "step": "onboarding"
                    ]))

                    await send(.permissionResponse(permission, Result {
                        switch permission {
                        case .notifications:
                            return try await notificationClient.requestPermission()
                        case .location:
                            // Location permission would be handled here
                            // For now, return true as placeholder
                            try await Task.sleep(for: .milliseconds(500))
                            return true
                        }
                    }))
                }

            case let .permissionResponse(permission, .success(granted)):
                state.isLoading = false
                state.permissionsGranted[permission] = granted

                if granted {
                    return .run { _ in
                        await haptics.notification(.success)
                        await analytics.track(.permissionGranted(permission: permission.rawValue))
                        await analytics.track(.featureUsed(feature: "permission_granted", context: [
                            "permission": permission.rawValue,
                            "step": "onboarding"
                        ]))
                    }
                } else {
                    state.errorMessage = "Permission denied for \(permission.rawValue.capitalized)"
                    return .run { _ in
                        await haptics.notification(.error)
                        await analytics.track(.permissionDenied(permission: permission.rawValue))
                        await analytics.track(.featureUsed(feature: "permission_denied", context: [
                            "permission": permission.rawValue,
                            "step": "onboarding"
                        ]))
                    }
                }

            case let .permissionResponse(permission, .failure(error)):
                state.isLoading = false
                state.errorMessage = "Failed to request \(permission.rawValue.capitalized) permission: \(error.localizedDescription)"

                return .run { _ in
                    await haptics.notification(.error)
                    await analytics.trackError(
                        domain: "onboarding",
                        code: "permission_error",
                        description: "Failed to request \(permission.rawValue) permission: \(error.localizedDescription)"
                    )
                }

            case .onboardingCompleted:
                // This action is handled by the parent reducer
                // Additional cleanup can be done here if needed
                return .run { _ in
                    await analytics.track(.featureUsed(feature: "onboarding_flow_completed", context: [
                        "completion_time": "\(Date().timeIntervalSince1970)"
                    ]))
                }
            }
        }
    }
}

struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingFeature>

    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                VStack {
                    // Progress indicator - fixed position
                    progressIndicator()

                    // Content based on current step
                    Group {
                        switch store.currentStep {
                        case .welcome:
                            welcomeView()
                        case .permissions:
                            permissionsView()
                        case .profile:
                            // Profile step is handled in AuthenticationView
                            EmptyView()
                        case .complete:
                            completionView()
                        }
                    }
                }
                .padding()
                .navigationTitle("Welcome to LifeSignal")
                .navigationBarTitleDisplayMode(.inline)
                .background(Color(UIColor.systemGroupedBackground))
                .alert("Permission Error", isPresented: .constant(store.errorMessage != nil)) {
                    Button("OK") {
                        store.send(.binding(.set(\.errorMessage, nil)))
                    }
                } message: {
                    Text(store.errorMessage ?? "")
                }
                .onAppear {
                    store.send(.startOnboarding)
                }
            }
        }
    }

    @ViewBuilder
    private func progressIndicator() -> some View {
        ProgressView(value: store.progress)
            .progressViewStyle(LinearProgressViewStyle())
            .padding(.vertical)
    }

    @ViewBuilder
    private func welcomeView() -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "shield.checkered")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)

            Text("Welcome to LifeSignal")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Stay connected with your loved ones and ensure their safety with real-time check-ins and emergency alerts.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Spacer()

            Button(action: {
                store.send(.nextStep)
            }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
    }

    @ViewBuilder
    private func permissionsView() -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)

            Text("Enable Notifications")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("We'll send you important alerts about check-ins and emergency situations.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                Button(action: {
                    store.send(.requestPermission(.notifications))
                }) {
                    HStack {
                        if store.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Requesting Permission...")
                        } else {
                            Text("Enable Notifications")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(store.isLoading ? Color.gray : Color.blue)
                    .cornerRadius(10)
                }
                .disabled(store.isLoading)

                Button(action: {
                    store.send(.nextStep)
                }) {
                    Text("Maybe Later")
                        .font(.body)
                        .foregroundColor(.blue)
                }
                .disabled(store.isLoading)
            }
        }
    }

    @ViewBuilder
    private func completionView() -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.green)

            Text("You're All Set!")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Welcome to LifeSignal. Let's keep you and your loved ones safe.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Spacer()

            Button(action: {
                store.send(.completeOnboarding)
            }) {
                Text("Start Using LifeSignal")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
    }
}

// MARK: - Previews

#Preview("Onboarding View") {
    OnboardingView(
        store: Store(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }
    )
}