import Foundation
import SwiftUI
import ComposableArchitecture
import Perception
// import UserNotifications

@LifeSignalFeature
@Reducer
struct OnboardingFeature: FeatureContext { // : FeatureContext (will be enforced by macro in Phase 2)
    @ObservableState
    struct State: Equatable {
        // Features have read-only access to shared state through SessionClient only
        // No direct access to session internal state
        
        // Features have read-only access to shared state
        var currentStep = 0
        // var showInstructions = false
        var isLoading = false
        
        // Name entry fields
        var firstName = ""
        var lastName = ""
        var emergencyNote = ""
        
        // Focus state management
        var firstNameFieldFocused = false
        var lastNameFieldFocused = false
        var noteFieldFocused = false
        
        // New onboarding settings
        var checkInInterval: TimeInterval = 86400  // 1 day default
        var reminderMinutesBefore: Int = 30
        var biometricAuthEnabled: Bool = false
        var intervalPickerUnit: String = "days"
        var intervalPickerValue: Int = 1
        
        // Biometric authentication state
        var biometricType: BiometricType = .none
        var isBiometricCapable: Bool = false
        var showBiometricAuthError = false
        var biometricAuthErrorMessage: String? = nil
        var showPermissionAlert = false
        var isBiometricAuthLoading: Bool = false

        var progress: Double {
            Double(currentStep) / 4.0  // 5 steps total (0-4)
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
        
        // Interval picker helpers
        var dayValues: [Int] { Array(1...7) }
        var hourValues: [Int] { [8, 16, 32] }
        var isDayUnit: Bool { intervalPickerUnit == "days" }
        
        // Get computed interval in seconds from picker values
        func getComputedIntervalInSeconds() -> TimeInterval {
            if intervalPickerUnit == "days" {
                return TimeInterval(intervalPickerValue * 86400)
            } else {
                return TimeInterval(intervalPickerValue * 3600)
            }
        }
        
        // Format an interval for display
        func formatInterval(_ interval: TimeInterval) -> String {
            let hours = Int(interval / 3600)
            let days = hours / 24
            if days > 0 {
                return "\(days) day\(days == 1 ? "" : "s")"
            } else {
                return "\(hours) hour\(hours == 1 ? "" : "s")"
            }
        }
    }

    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        // Onboarding flow
        case startOnboarding
        case nextStep
        case previousStep
        case cancelOnboarding
        case completeOnboarding
        case onboardingCompleted
        case viewAppeared
        
        // User profile creation
        case createUserProfile
        case userProfileCreatedSuccess
        case userProfileCreatedFailure(String)
        
        // Instructions
        // case handleInstructionsDismissal
        // case handleGotItButtonTap
        
        // Focus management
        case setFirstNameFieldFocused(Bool)
        case setLastNameFieldFocused(Bool)
        case setNoteFieldFocused(Bool)
        
        // Interval management
        case updateIntervalPickerUnit(String)
        case updateIntervalPickerValue(Int)
        case setCheckInInterval(TimeInterval)
        
        // Notification preference
        case setReminderMinutes(Int)
        
        // Biometric auth
        case setBiometricAuth(Bool)
        case requestBiometricAuth
        case biometricAuthResult(Result<Bool, Error>)
        case dismissBiometricError
        case requestPermissionAndRetry
        case openSettings
    }

    // OnboardingFeature only uses OnboardingClient for shared state
    // PureUtilities clients are allowed for UI/device functionality
    @Dependency(\.onboardingClient) var onboardingClient
    @Dependency(\.biometricClient) var biometricClient  // PureUtility for device capability checks

    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .startOnboarding:
                state.currentStep = 0
                state.firstName = ""
                state.lastName = ""
                state.emergencyNote = ""
                state.biometricType = biometricClient.getBiometricType()
                state.isBiometricCapable = biometricClient.isBiometricCapable()

                return .run { send in
                    try await Task.sleep(for: .milliseconds(100))
                    await send(.setFirstNameFieldFocused(true))
                }

            case .nextStep:
                if state.currentStep == 0 && !state.areBothNamesFilled {
                    return .none
                }
                if state.currentStep == 2 {
                    state.checkInInterval = state.getComputedIntervalInSeconds()
                }
                if state.currentStep < 4 {
                    state.currentStep += 1
                    // Focus appropriate field when moving to emergency note step
                    if state.currentStep == 1 {
                        return .run { send in
                            try await Task.sleep(for: .milliseconds(100))
                            await send(.setNoteFieldFocused(true))
                        }
                    }
                }
                return .none

            case .previousStep:
                if state.currentStep > 0 {
                    state.currentStep -= 1
                    let currentStep = state.currentStep
                    // Focus appropriate field when going back
                    return .run { send in
                        try await Task.sleep(for: .milliseconds(100))
                        if currentStep == 0 {
                            await send(.setFirstNameFieldFocused(true))
                        } else if currentStep == 1 {
                            await send(.setNoteFieldFocused(true))
                        }
                    }
                }
                return .none

            case .cancelOnboarding:
                // Cancel onboarding - ApplicationFeature will handle sign out
                return .none

            case .completeOnboarding:
                state.isLoading = true
                
                // Ensure checkInInterval is set from picker values
                state.checkInInterval = state.getComputedIntervalInSeconds()
                
                // First complete the user profile in OnboardingClient, then mark onboarding complete
                return .run { [firstName = state.firstName, lastName = state.lastName, emergencyNote = state.emergencyNote, checkInInterval = state.checkInInterval, reminderMinutes = state.reminderMinutesBefore, biometricEnabled = state.biometricAuthEnabled] send in
                    do {
                        // Mark that user has completed profile setup
                        try await onboardingClient.completeUserProfile(
                            firstName,
                            lastName, 
                            emergencyNote,
                            checkInInterval,
                            reminderMinutes,
                            biometricEnabled
                        )
                        
                        // Then mark onboarding as complete
                        try await onboardingClient.completeOnboarding()
                        await send(.onboardingCompleted)
                    } catch {
                        // Handle error silently, onboarding completion should still proceed
                        await send(.onboardingCompleted)
                    }
                }

            case .createUserProfile:
                // This action is no longer used - ApplicationFeature handles user creation
                return .none

            case .userProfileCreatedSuccess:
                // This action is no longer used - ApplicationFeature handles user creation
                return .none

            case .userProfileCreatedFailure:
                // This action is no longer used - ApplicationFeature handles user creation
                return .none

            // case .handleInstructionsDismissal:
            //     state.showInstructions = false
            //     
            //     return .run { send in
            //         do {
            //             try await sessionClient.completeOnboarding()
            //             await send(.onboardingCompleted)
            //         } catch {
            //             // Handle error silently, onboarding completion should still proceed
            //             await send(.onboardingCompleted)
            //         }
            //     }

            // case .handleGotItButtonTap:
            //     state.showInstructions = false
            //     
            //     return .run { send in
            //         do {
            //             try await sessionClient.completeOnboarding()
            //             await send(.onboardingCompleted)
            //         } catch {
            //             // Handle error silently, onboarding completion should still proceed
            //             await send(.onboardingCompleted)
            //         }
            //     }

            case let .setFirstNameFieldFocused(focused):
                state.firstNameFieldFocused = focused
                return .none

            case let .setLastNameFieldFocused(focused):
                state.lastNameFieldFocused = focused
                return .none

            case let .setNoteFieldFocused(focused):
                state.noteFieldFocused = focused
                return .none
                
            // Interval management
            case let .updateIntervalPickerUnit(newUnit):
                state.intervalPickerUnit = newUnit
                if newUnit == "days" {
                    state.intervalPickerValue = 1
                } else {
                    state.intervalPickerValue = 8
                }
                return .none
                
            case let .updateIntervalPickerValue(value):
                state.intervalPickerValue = value
                return .none
                
            case let .setCheckInInterval(interval):
                state.checkInInterval = interval
                return .none
                
            // Notification preference
            case let .setReminderMinutes(minutes):
                state.reminderMinutesBefore = minutes
                return .none
                
            // Biometric auth - OnboardingFeature tests permission and collects preference
            case let .setBiometricAuth(enabled):
                if enabled {
                    if state.biometricType != .none {
                        // Device supports biometrics, test authentication first
                        return .run { send in
                            await send(.requestBiometricAuth)
                        }
                    } else if state.isBiometricCapable {
                        // Device has biometric hardware but it's disabled/not enrolled
                        state.showPermissionAlert = true
                        state.biometricAuthErrorMessage = "Biometric authentication is not enabled. Please set it up in Settings first."
                        return .none
                    } else {
                        // Device doesn't support biometrics
                        state.showBiometricAuthError = true
                        state.biometricAuthErrorMessage = "This device does not support biometric authentication."
                        return .none
                    }
                } else {
                    // Allow disabling without confirmation
                    state.biometricAuthEnabled = enabled
                    return .none
                }
                
            case .requestBiometricAuth:
                // Test biometric authentication to verify it's enabled and working
                state.isBiometricAuthLoading = true
                return .run { send in
                    do {
                        let success = try await biometricClient.authenticateWithPermissionRequest(
                            "Enable biometric authentication for secure actions in LifeSignal"
                        )
                        await send(.biometricAuthResult(.success(success)))
                    } catch {
                        await send(.biometricAuthResult(.failure(error)))
                    }
                }
                
            case .biometricAuthResult(.success(let authenticated)):
                state.isBiometricAuthLoading = false
                if authenticated {
                    // Authentication succeeded, enable biometric auth
                    state.biometricAuthEnabled = true
                } else {
                    // Authentication failed, don't enable
                    state.biometricAuthEnabled = false
                    state.showBiometricAuthError = true
                    state.biometricAuthErrorMessage = "Biometric authentication failed. Please try again."
                }
                return .none
                
            case .biometricAuthResult(.failure(let error)):
                // Authentication failed, don't enable and show appropriate error
                state.isBiometricAuthLoading = false
                state.biometricAuthEnabled = false
                if let biometricError = error as? BiometricClientError {
                    switch biometricError {
                    case .userCancel:
                        // User cancelled, don't show error
                        return .none
                    case .notEnrolled:
                        state.showPermissionAlert = true
                        state.biometricAuthErrorMessage = "Biometric authentication is not enrolled. Please set it up in Settings first."
                    case .biometryLocked:
                        state.showBiometricAuthError = true
                        state.biometricAuthErrorMessage = biometricError.errorDescription
                    default:
                        state.showBiometricAuthError = true
                        state.biometricAuthErrorMessage = biometricError.errorDescription
                    }
                } else {
                    state.showBiometricAuthError = true
                    state.biometricAuthErrorMessage = "Biometric authentication failed: \(error.localizedDescription)"
                }
                return .none
                
            case .dismissBiometricError:
                state.showBiometricAuthError = false
                state.biometricAuthErrorMessage = nil
                return .none
                
            case .requestPermissionAndRetry:
                state.showPermissionAlert = false
                return .none
                
            case .openSettings:
                state.showPermissionAlert = false
                biometricClient.openSettings()
                return .none
                
            case .viewAppeared:
                // Update biometric type and capability when view appears
                state.biometricType = biometricClient.getBiometricType()
                state.isBiometricCapable = biometricClient.isBiometricCapable()
                return .run { [currentStep = state.currentStep] send in
                    try await Task.sleep(for: .milliseconds(100))
                    if currentStep == 0 {
                        await send(.setFirstNameFieldFocused(true))
                    } else if currentStep == 1 {
                        await send(.setNoteFieldFocused(true))
                    }
                }
                

            case .onboardingCompleted:
                // Mark onboarding as complete and persist the state
                state.isLoading = false
                return .run { send in
                    do {
                        try await onboardingClient.completeOnboarding()
                    } catch {
                        // Handle error silently - onboarding completion failed
                    }
                }
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
                ScrollView {
                    VStack {
                        // Progress indicator - fixed position
                        progressIndicator()

                        // Content based on current step
                        switch store.currentStep {
                        case 0:
                            nameEntryView()
                        case 1:
                            emergencyNoteView()
                        case 2:
                            checkInIntervalView()
                        case 3:
                            reminderSettingsView()
                        case 4:
                            biometricAuthView()
                        default:
                            nameEntryView()
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 50)
                .background(Color(UIColor.systemGroupedBackground))
                .navigationTitle("Setup")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .onAppear {
                    store.send(.viewAppeared)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if store.currentStep > 0 {
                            Button(action: {
                                store.send(.previousStep, animation: .default)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("Back")
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            store.send(.cancelOnboarding, animation: .default)
                        }
                        .foregroundColor(.blue)
                    }
                }
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
                // .sheet(isPresented: $store.showInstructions, onDismiss: {
                //     store.send(.handleInstructionsDismissal)
                // }) {
                //     instructionsView()
                // }
            }
        }
    }

    @ViewBuilder
    private func progressIndicator() -> some View {
        HStack(spacing: 8) {
            ForEach(0..<5) { step in
                RoundedRectangle(cornerRadius: 4)
                    .fill(step == store.currentStep ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 24, height: 6)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private func nameEntryView() -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                Text("What's your name?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

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
            }
            
            Spacer()
                .frame(minHeight: 24)
            
            Button(action: {
                if store.areBothNamesFilled {
                    store.send(.nextStep, animation: .default)
                }
            }) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(store.areBothNamesFilled ? Color.blue : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!store.areBothNamesFilled)
        }
    }

    @ViewBuilder
    private func emergencyNoteView() -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                Text("Your emergency note")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

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
            }
            
            Spacer()
                .frame(minHeight: 24)
            
            Button(action: {
                store.send(.nextStep, animation: .default)
            }) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
    }

    @ViewBuilder
    private func checkInIntervalView() -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                Text("How often should you check in?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                VStack(spacing: 16) {
                    Picker("Unit", selection: $store.intervalPickerUnit) {
                        Text("Days").tag("days")
                        Text("Hours").tag("hours")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: store.intervalPickerUnit) { oldUnit, newUnit in
                        store.send(.updateIntervalPickerUnit(newUnit))
                    }

                    Picker("Value", selection: $store.intervalPickerValue) {
                        if store.isDayUnit {
                            ForEach(store.dayValues, id: \.self) { day in
                                Text("\(day) day\(day > 1 ? "s" : "")").tag(day)
                            }
                        } else {
                            ForEach(store.hourValues, id: \.self) { hour in
                                Text("\(hour) hours").tag(hour)
                            }
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 120)
                    .clipped()
                    .onChange(of: store.intervalPickerValue) { _, newValue in
                        store.send(.updateIntervalPickerValue(newValue))
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
            
            Spacer()
                .frame(minHeight: 24)
            
            Button(action: {
                store.send(.nextStep, animation: .default)
            }) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
    }

    @ViewBuilder
    private func reminderSettingsView() -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                Text("When should we remind you?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Picker("Check-in notification", selection: Binding<Int>(
                    get: { store.reminderMinutesBefore },
                    set: { store.send(.setReminderMinutes($0)) }
                )) {
                    Text("Disabled").tag(0)
                    Text("30 mins").tag(30)
                    Text("2 hours").tag(120)
                }
                .pickerStyle(.segmented)
            }
            
            Spacer()
                .frame(minHeight: 24)
            
            Button(action: {
                store.send(.nextStep, animation: .default)
            }) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(store.isLoading ? Color.gray : Color.blue)
                    .cornerRadius(12)
            }
            .disabled(store.isLoading)
        }
    }

    @ViewBuilder
    private func biometricAuthView() -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                Text("Secure your actions")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Biometric Authentication")
                                .font(.body)
                                .foregroundColor(.primary)
                            Text(store.isBiometricAuthLoading
                                 ? "Authenticating..."
                                 : store.biometricType != .none 
                                 ? "Enable \(store.biometricType.displayName) for secure actions"
                                 : store.isBiometricCapable 
                                 ? "Enable biometric authentication for secure actions" 
                                 : "Biometric authentication not available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { store.biometricAuthEnabled },
                            set: { enabled in
                                if enabled {
                                    store.send(.setBiometricAuth(true))
                                } else {
                                    store.send(.setBiometricAuth(false))
                                }
                            }
                        ))
                        .labelsHidden()
                        .disabled(!store.isBiometricCapable || store.isBiometricAuthLoading)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
            }
            
            Spacer()
                .frame(minHeight: 24)
            
            Button(action: {
                store.send(.completeOnboarding, animation: .default)
            }) {
                Text("Complete")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(store.isLoading ? Color.gray : Color.blue)
                    .cornerRadius(12)
            }
            .disabled(store.isLoading)
        }
        .alert("Biometric Authentication", isPresented: Binding(
            get: { store.showBiometricAuthError },
            set: { _ in store.send(.dismissBiometricError) }
        )) {
            Button("OK", role: .cancel) {
                store.send(.dismissBiometricError)
            }
        } message: {
            Text(store.biometricAuthErrorMessage ?? "Authentication failed")
        }
        .alert("Enable Biometric Authentication", isPresented: Binding(
            get: { store.showPermissionAlert },
            set: { _ in store.showPermissionAlert = false }
        )) {
            Button("Try Again") {
                store.send(.requestPermissionAndRetry)
            }
            Button("Settings") {
                store.send(.openSettings)
            }
            Button("Cancel", role: .cancel) {
                store.showPermissionAlert = false
            }
        } message: {
            Text(store.biometricAuthErrorMessage ?? "Biometric authentication is disabled. Would you like to enable it in Settings?")
        }
    }

    // @ViewBuilder
    // private func instructionsView() -> some View {
    //     VStack(alignment: .leading, spacing: 20) {
    //         Text("How to use LifeSignal")
    //             .font(.title)
    //             .fontWeight(.bold)
    //             .padding(.bottom, 10)

    //         VStack(alignment: .leading, spacing: 15) {
    //             instructionItem(
    //                 number: "1",
    //                 title: "Set your interval",
    //                 description: "Choose how often you need to check in. This is the maximum time before your contacts are alerted if you don't check in."
    //             )

    //             instructionItem(
    //                 number: "2",
    //                 title: "Add responders",
    //                 description: "Share your QR code with trusted contacts who will respond if you need help. They'll be notified if you miss a check-in."
    //             )

    //             instructionItem(
    //                 number: "3",
    //                 title: "Check in regularly",
    //                 description: "Tap the check-in button before your timer expires. This resets your countdown and lets your contacts know you're safe."
    //             )

    //             instructionItem(
    //                 number: "4",
    //                 title: "Emergency alert",
    //                 description: "If you need immediate help, activate the alert to notify all your responders instantly."
    //             )
    //         }

    //         Spacer()

    //         Button(action: {
    //             store.send(.handleGotItButtonTap, animation: .default)
    //         }) {
    //             Text("Got it")
    //                 .font(.headline)
    //                 .frame(maxWidth: .infinity)
    //                 .padding()
    //                 .background(Color.blue)
    //                 .foregroundColor(.white)
    //                 .cornerRadius(12)
    //         }
    //         .padding(.top)
    //     }
    //     .padding()
    //     .background(Color(UIColor.systemGroupedBackground))
    //     .presentationDetents([.large])
    //     .presentationDragIndicator(.visible)
    // }

    // private func instructionItem(number: String, title: String, description: String) -> some View {
    //     HStack(alignment: .top, spacing: 15) {
    //         Text(number)
    //             .font(.headline)
    //             .foregroundColor(.white)
    //             .frame(width: 30, height: 30)
    //             .background(Color.blue)
    //             .clipShape(Circle())

    //         VStack(alignment: .leading, spacing: 5) {
    //             Text(title)
    //                 .font(.headline)
    //             Text(description)
    //                 .font(.body)
    //                 .fixedSize(horizontal: false, vertical: true)
    //         }
    //     }
    //     .padding(.bottom, 10)
    // }
}

// MARK: - Previews

#Preview("Onboarding View") {
    OnboardingView(
        store: Store(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }
    )
}
