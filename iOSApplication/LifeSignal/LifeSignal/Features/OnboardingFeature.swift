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

        var currentStep = 0
        var isLoading = false
        var errorMessage: String?
        var showError = false
        var showInstructions = false
        
        // Name entry fields
        var firstName = ""
        var lastName = ""
        var emergencyNote = ""
        
        // Focus state management
        var firstNameFieldFocused = false
        var lastNameFieldFocused = false
        var noteFieldFocused = false

        var progress: Double {
            Double(currentStep) / 1.0  // 2 steps total (0 and 1)
        }

        var areBothNamesFilled: Bool {
            !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        // Format name as user types (capitalize first letter)
        func formatNameAsTyped(_ input: String) -> String {
            guard !input.isEmpty else { return input }
            let cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.prefix(1).capitalized + cleaned.dropFirst().lowercased()
        }
    }

    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        // Onboarding flow
        case startOnboarding
        case nextStep
        case previousStep
        case completeOnboarding(completion: (Bool) -> Void)
        case onboardingCompleted
        
        // User profile creation
        case createUserProfile
        case userProfileCreated(Result<User, Error>)
        
        // Instructions
        case handleInstructionsDismissal
        case handleGotItButtonTap
        
        // Focus management
        case setFirstNameFieldFocused(Bool)
        case setLastNameFieldFocused(Bool)
        case setNoteFieldFocused(Bool)
    }

    @Dependency(\.hapticClient) var haptics
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.userClient) var userClient

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .startOnboarding:
                state.currentStep = 0
                state.isLoading = false
                state.errorMessage = nil
                state.showError = false
                state.firstName = ""
                state.lastName = ""
                state.emergencyNote = ""

                return .run { _ in
                    await haptics.impact(.light)
                }

            case .nextStep:
                guard state.areBothNamesFilled else { return .none }
                
                state.currentStep = 1
                state.errorMessage = nil

                return .run { _ in
                    await haptics.impact(.medium)
                }

            case .previousStep:
                state.currentStep = 0
                state.errorMessage = nil

                return .run { _ in
                    await haptics.impact(.medium)
                }

            case .completeOnboarding:
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { send in
                    await send(.createUserProfile)
                }

            case .createUserProfile:
                return .run { [firstName = state.firstName, lastName = state.lastName, emergencyNote = state.emergencyNote] send in
                    let result = await Result {
                        // Create user profile with name from onboarding
                        let fullName = "\(firstName) \(lastName)"
                        return try await userClient.updateProfile(fullName, emergencyNote)
                    }
                    await send(.userProfileCreated(result))
                }

            case let .userProfileCreated(.success(user)):
                state.isLoading = false
                state.$currentUser.withLock { $0 = user }
                state.showInstructions = true
                
                return .run { _ in
                    await haptics.notification(.success)
                }

            case let .userProfileCreated(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                state.showError = true
                
                return .run { _ in
                    await haptics.notification(.error)
                }

            case .handleInstructionsDismissal:
                state.showInstructions = false
                state.$needsOnboarding.withLock { $0 = false }
                
                return .run { send in
                    await send(.onboardingCompleted)
                }

            case .handleGotItButtonTap:
                state.showInstructions = false
                state.$needsOnboarding.withLock { $0 = false }
                
                return .run { send in
                    await haptics.impact(.medium)
                    await send(.onboardingCompleted)
                }

            case let .setFirstNameFieldFocused(focused):
                state.firstNameFieldFocused = focused
                return .none

            case let .setLastNameFieldFocused(focused):
                state.lastNameFieldFocused = focused
                return .none

            case let .setNoteFieldFocused(focused):
                state.noteFieldFocused = focused
                return .none

            case .onboardingCompleted:
                return .none
            }
        }
    }
}

struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingFeature>
    @FocusState private var firstNameFieldFocused: Bool
    @FocusState private var lastNameFieldFocused: Bool
    @FocusState private var noteFieldFocused: Bool

    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                VStack {
                    // Progress indicator - fixed position
                    progressIndicator()

                    // Content based on current step
                    if store.currentStep == 0 {
                        nameEntryView()
                    } else {
                        emergencyNoteView()
                    }
                }
                .padding()
                .navigationTitle("Welcome to LifeSignal")
                .navigationBarTitleDisplayMode(.inline)
                .background(Color(UIColor.systemGroupedBackground))
                .alert("Error", isPresented: $store.showError) {
                    Button("OK") { }
                } message: {
                    Text(store.errorMessage ?? "")
                }
                .disabled(store.isLoading)
                .onChange(of: store.firstNameFieldFocused) { _, newValue in
                    firstNameFieldFocused = newValue
                }
                .onChange(of: store.lastNameFieldFocused) { _, newValue in
                    lastNameFieldFocused = newValue
                }
                .onChange(of: store.noteFieldFocused) { _, newValue in
                    noteFieldFocused = newValue
                }
                .onChange(of: firstNameFieldFocused) { _, newValue in
                    store.send(.setFirstNameFieldFocused(newValue))
                }
                .onChange(of: lastNameFieldFocused) { _, newValue in
                    store.send(.setLastNameFieldFocused(newValue))
                }
                .onChange(of: noteFieldFocused) { _, newValue in
                    store.send(.setNoteFieldFocused(newValue))
                }
                .sheet(isPresented: $store.showInstructions, onDismiss: {
                    store.send(.handleInstructionsDismissal)
                }) {
                    instructionsView()
                }
            }
        }
    }

    @ViewBuilder
    private func progressIndicator() -> some View {
        HStack(spacing: 8) {
            ForEach(0..<2) { step in
                RoundedRectangle(cornerRadius: 4)
                    .fill(step == store.currentStep ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 30, height: 6)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private func nameEntryView() -> some View {
        VStack(spacing: 24) {
            Text("What's your name?")
                .font(.title2)
                .fontWeight(.bold)

            // First Name Field
            VStack(alignment: .leading, spacing: 8) {
                Text("First Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)

                TextField("First Name", text: Binding(
                    get: { store.firstName },
                    set: { newValue in
                        store.send(.binding(.set(\.firstName, store.state.formatNameAsTyped(newValue))))
                    }
                ))
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .disableAutocorrection(true)
                    .focused($firstNameFieldFocused)
                    .submitLabel(.next)
                    .onSubmit {
                        lastNameFieldFocused = true
                    }
            }
            .padding(.horizontal)

            // Last Name Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Last Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)

                TextField("Last Name", text: Binding(
                    get: { store.lastName },
                    set: { newValue in
                        store.send(.binding(.set(\.lastName, store.state.formatNameAsTyped(newValue))))
                    }
                ))
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .disableAutocorrection(true)
                    .focused($lastNameFieldFocused)
                    .submitLabel(.done)
            }
            .padding(.horizontal)

            Button(action: {
                if store.areBothNamesFilled {
                    store.send(.nextStep, animation: .default)
                }
            }) {
                Text("Continue")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(store.areBothNamesFilled ? Color.blue : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!store.areBothNamesFilled)
            .padding(.horizontal)

            Spacer()
        }
    }

    @ViewBuilder
    private func emergencyNoteView() -> some View {
        VStack(spacing: 24) {
            Text("Your emergency note")
                .font(.title2)
                .fontWeight(.bold)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $store.emergencyNote)
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(height: 120)
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                    .scrollContentBackground(.hidden)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .focused($noteFieldFocused)
            }
            .padding(.horizontal)

            HStack {
                Button(action: {
                    store.send(.previousStep, animation: .default)
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                    .foregroundColor(.blue)
                }

                Spacer()

                Button(action: {
                    store.send(.completeOnboarding { success in
                        if !success {
                            // Error handled by reducer
                        }
                    }, animation: .default)
                }) {
                    Text("Complete")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 120)
                        .padding()
                }
                .background(store.isLoading ? Color.gray : Color.blue)
                .cornerRadius(12)
                .disabled(store.isLoading)
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    @ViewBuilder
    private func instructionsView() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("How to use LifeSignal")
                .font(.title)
                .fontWeight(.bold)
                .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 15) {
                instructionItem(
                    number: "1",
                    title: "Set your interval",
                    description: "Choose how often you need to check in. This is the maximum time before your contacts are alerted if you don't check in."
                )

                instructionItem(
                    number: "2",
                    title: "Add responders",
                    description: "Share your QR code with trusted contacts who will respond if you need help. They'll be notified if you miss a check-in."
                )

                instructionItem(
                    number: "3",
                    title: "Check in regularly",
                    description: "Tap the check-in button before your timer expires. This resets your countdown and lets your contacts know you're safe."
                )

                instructionItem(
                    number: "4",
                    title: "Emergency alert",
                    description: "If you need immediate help, activate the alert to notify all your responders instantly."
                )
            }

            Spacer()

            Button(action: {
                store.send(.handleGotItButtonTap, animation: .default)
            }) {
                Text("Got it")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func instructionItem(number: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Text(number)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Color.blue)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 10)
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
