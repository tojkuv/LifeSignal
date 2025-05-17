import SwiftUI
import Foundation

struct OnboardingView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @Binding var isOnboarding: Bool

    @StateObject private var viewModel = OnboardingViewModel()

    // State for showing instructions after onboarding
    @State private var showInstructions = false

    // Focus state for text fields
    @FocusState private var firstNameFieldFocused: Bool
    @FocusState private var lastNameFieldFocused: Bool
    @FocusState private var noteFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack {
                // Progress indicator - fixed position
                HStack(spacing: 8) {
                    ForEach(0..<2) { step in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(step == viewModel.currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 30, height: 6)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 16)

                // Content based on current step
                if viewModel.currentStep == 0 {
                    nameEntryView
                } else {
                    emergencyNoteView
                }
            }
            .padding()
            .navigationTitle("Welcome to LifeSignal")
            .toolbar {
                // Remove the skip button to prevent skipping the name step
                // ToolbarItem(placement: .navigationBarTrailing) {
                //     if viewModel.currentStep == 0 {
                //         Button("Skip") {
                //             // Set default values and complete onboarding
                //             viewModel.name = "User"
                //             viewModel.emergencyNote = ""
                //             completeOnboarding()
                //         }
                //         .foregroundColor(.blue)
                //     }
                // }
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(UIColor.systemGroupedBackground))
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .disabled(viewModel.isLoading)
            .onAppear {
                // Auto-focus the first name field when the view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    firstNameFieldFocused = true
                }
            }
            .sheet(isPresented: $showInstructions, onDismiss: {
                // Handle proper dismissal of the sheet
                // This ensures that if the sheet is dismissed by swiping down,
                // we still complete the onboarding process
                print("Sheet dismissed")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("Setting isOnboarding to false from sheet dismissal")
                    isOnboarding = false
                    print("Successfully set isOnboarding to false from sheet dismissal")
                }
            }) {
                // Use the existing InstructionsView from the Home tab
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
                        // First dismiss the sheet, then mark onboarding as complete
                        showInstructions = false
                        // Use a slight delay to ensure the sheet is dismissed before changing isOnboarding
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            // Mark onboarding as complete after showing instructions
                            print("Setting isOnboarding to false from Got it button")
                            isOnboarding = false
                            print("Successfully set isOnboarding to false")
                        }
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
                    .hapticFeedback()
                }
                .padding()
                .background(Color(UIColor.systemGroupedBackground))
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var nameEntryView: some View {
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
                        // Focus the note field when moving to the next step
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            noteFieldFocused = true
                        }
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
            .hapticFeedback()

            Spacer()
        }
    }

    private var emergencyNoteView: some View {
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
                    HapticFeedback.triggerHaptic()
                    withAnimation {
                        viewModel.previousStep()
                        // Focus the first name field when going back
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            firstNameFieldFocused = true
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                    .foregroundColor(.blue)
                }
                .hapticFeedback(style: .light)

                Spacer()

                Button(action: completeOnboarding) {
                    Text("Complete")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 120)
                        .padding()
                }
                .background(viewModel.isLoading ? Color.gray : Color.blue)
                .cornerRadius(12)
                .disabled(viewModel.isLoading)
                .hapticFeedback()
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    private func completeOnboarding() {
        // Add haptic feedback
        HapticFeedback.triggerHaptic()

        // Update the user's profile
        viewModel.completeOnboarding { success in
            if success {
                // Update UserViewModel with the new data
                userViewModel.name = viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines)
                userViewModel.profileDescription = viewModel.emergencyNote.trimmingCharacters(in: .whitespacesAndNewlines)

                // Set default check-in interval to 1 day (24 hours)
                userViewModel.checkInInterval = 24 * 60 * 60 // 24 hours in seconds

                // Set default notification preference to 2 hours
                userViewModel.notify30MinBefore = false
                userViewModel.notify2HoursBefore = true

                // Update the check-in expiration based on the new interval
                let now = Date()
                userViewModel.lastCheckIn = now

                // Save to UserDefaults
                UserDefaults.standard.set(userViewModel.checkInInterval, forKey: "checkInInterval")
                UserDefaults.standard.set(userViewModel.notify30MinBefore, forKey: "notify30MinBefore")
                UserDefaults.standard.set(userViewModel.notify2HoursBefore, forKey: "notify2HoursBefore")
                UserDefaults.standard.set(now, forKey: "lastCheckIn")

                // Success haptic feedback
                HapticFeedback.notificationFeedback(type: .success)

                // Show instructions sheet instead of immediately completing onboarding
                // Use main thread to update UI
                DispatchQueue.main.async {
                    showInstructions = true
                }

                // Note: isOnboarding will be set to false after instructions are dismissed
            } else {
                // Error haptic feedback
                HapticFeedback.notificationFeedback(type: .error)

                // Use main thread to update UI
                DispatchQueue.main.async {
                    viewModel.errorMessage = "Failed to create user profile"
                    viewModel.showError = true
                }
            }
        }
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

#Preview {
    OnboardingView(isOnboarding: .constant(true))
        .environmentObject(UserViewModel())
}
