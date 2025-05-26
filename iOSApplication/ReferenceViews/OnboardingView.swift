import SwiftUI
import Foundation

struct OnboardingView: View {
    // Initialize with an external binding that will be synced with the view model
    init(isOnboarding: Binding<Bool>) {
        // Create the view model
        _viewModel = StateObject(wrappedValue: OnboardingViewModel())
        // Store the binding for later use
        self._externalIsOnboarding = isOnboarding
    }

    // External binding from parent view
    @Binding private var externalIsOnboarding: Bool

    // View model that contains all state and logic
    @StateObject private var viewModel: OnboardingViewModel

    // Focus state for text fields - these will be bound to the view model
    @FocusState private var firstNameFieldFocused: Bool
    @FocusState private var lastNameFieldFocused: Bool
    @FocusState private var noteFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack {
                // Progress indicator - fixed position
                progressIndicator()

                // Content based on current step
                if viewModel.currentStep == 0 {
                    nameEntryView()
                } else {
                    emergencyNoteView()
                }
            }
            .padding()
            .navigationTitle("Welcome to LifeSignal")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(UIColor.systemGroupedBackground))
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .disabled(viewModel.isLoading)
            .onAppear {
                // Initialize the view model with the external binding value
                viewModel.isOnboarding = externalIsOnboarding
            }
            .onChange(of: viewModel.isOnboarding) { _, newValue in
                // Keep external binding in sync with the view model
                externalIsOnboarding = newValue
            }
            .onChange(of: externalIsOnboarding) { _, newValue in
                // Keep view model in sync with external binding
                viewModel.isOnboarding = newValue
            }
            .onChange(of: viewModel.firstNameFieldFocused) { _, newValue in
                // Keep focus state in sync with view model
                firstNameFieldFocused = newValue
            }
            .onChange(of: viewModel.lastNameFieldFocused) { _, newValue in
                // Keep focus state in sync with view model
                lastNameFieldFocused = newValue
            }
            .onChange(of: viewModel.noteFieldFocused) { _, newValue in
                // Keep focus state in sync with view model
                noteFieldFocused = newValue
            }
            .onChange(of: firstNameFieldFocused) { _, newValue in
                // Update view model when focus changes in view
                viewModel.firstNameFieldFocused = newValue
            }
            .onChange(of: lastNameFieldFocused) { _, newValue in
                // Update view model when focus changes in view
                viewModel.lastNameFieldFocused = newValue
            }
            .onChange(of: noteFieldFocused) { _, newValue in
                // Update view model when focus changes in view
                viewModel.noteFieldFocused = newValue
            }
            .sheet(isPresented: $viewModel.showInstructions, onDismiss: {
                // Handle proper dismissal of the sheet
                viewModel.handleInstructionsDismissal()
            }) {
                instructionsView()
            }
        }
    }

    /// Progress indicator for the onboarding steps
    @ViewBuilder
    private func progressIndicator() -> some View {
        HStack(spacing: 8) {
            ForEach(0..<2) { step in
                RoundedRectangle(cornerRadius: 4)
                    .fill(step == viewModel.currentStep ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 30, height: 6)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 16)
    }

    /// Instructions view shown after completing onboarding
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
                HapticFeedback.triggerHaptic()
                viewModel.handleGotItButtonTap()
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

    /// Name entry view for the first step of onboarding
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
                    get: { viewModel.firstName },
                    set: { newValue in
                        // Format the text as the user types
                        viewModel.firstName = viewModel.formatNameAsTyped(newValue)
                        // This will trigger the computed property to update
                        viewModel.objectWillChange.send()
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
                    get: { viewModel.lastName },
                    set: { newValue in
                        // Format the text as the user types
                        viewModel.lastName = viewModel.formatNameAsTyped(newValue)
                        // This will trigger the computed property to update
                        viewModel.objectWillChange.send()
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
                // Check if both first and last name fields are filled
                if viewModel.areBothNamesFilled {
                    HapticFeedback.triggerHaptic()
                    withAnimation {
                        viewModel.nextStep()
                    }
                }
            }) {
                Text("Continue")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.areBothNamesFilled ? Color.blue : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!viewModel.areBothNamesFilled)
            .padding(.horizontal)

            Spacer()
        }
    }

    /// Emergency note view for the second step of onboarding
    @ViewBuilder
    private func emergencyNoteView() -> some View {
        VStack(spacing: 24) {
            Text("Your emergency note")
                .font(.title2)
                .fontWeight(.bold)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.emergencyNote)
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
                    HapticFeedback.lightImpact()
                    withAnimation {
                        viewModel.previousStep()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                    .foregroundColor(.blue)
                }

                Spacer()

                Button(action: {
                    // Add haptic feedback
                    HapticFeedback.triggerHaptic()

                    // Complete onboarding through the view model
                    viewModel.completeOnboarding { success in
                        if !success {
                            // Error haptic feedback
                            HapticFeedback.notificationFeedback(type: .error)

                            // Use main thread to update UI
                            DispatchQueue.main.async {
                                viewModel.errorMessage = "Failed to create user profile"
                                viewModel.showError = true
                            }
                        } else {
                            // Success haptic feedback
                            HapticFeedback.notificationFeedback(type: .success)
                        }
                    }
                }) {
                    Text("Complete")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 120)
                        .padding()
                }
                .background(viewModel.isLoading ? Color.gray : Color.blue)
                .cornerRadius(12)
                .disabled(viewModel.isLoading)
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    /// Creates an instruction item with a numbered circle and description
    @ViewBuilder
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

#Preview {
    // Create a preview with a constant binding
    OnboardingView(isOnboarding: .constant(true))
}