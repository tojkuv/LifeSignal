import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @Binding var isOnboarding: Bool

    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        NavigationStack {
            VStack {
                // Progress indicator
                HStack(spacing: 4) {
                    ForEach(0..<2) { step in
                        Circle()
                            .fill(step == viewModel.currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.top, 20)

                // Content based on current step
                if viewModel.currentStep == 0 {
                    nameEntryView
                } else {
                    emergencyNoteView
                }
            }
            .padding()
            .navigationTitle("Complete Your Profile")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .disabled(viewModel.isLoading)
        }
    }

    private var nameEntryView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
                .padding(.top, 40)

            Text("What's your name?")
                .font(.title2)
                .fontWeight(.bold)

            Text("This will be displayed to your contacts")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("Your name", text: $viewModel.name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .autocapitalization(.words)
                .disableAutocorrection(true)

            Button(action: {
                if !viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
                    .background(viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(12)
            }
            .disabled(viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.horizontal)

            Spacer()
        }
    }

    private var emergencyNoteView: some View {
        VStack(spacing: 24) {
            Image(systemName: "note.text")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
                .padding(.top, 40)

            Text("Emergency Note")
                .font(.title2)
                .fontWeight(.bold)

            Text("Add important information that responders should know in case of emergency")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextEditor(text: $viewModel.emergencyNote)
                .frame(minHeight: 100)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal)

            HStack {
                Button(action: {
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

                Button(action: completeOnboarding) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Complete")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                    }
                }
                .background(viewModel.isLoading ? Color.gray : Color.blue)
                .cornerRadius(12)
                .disabled(viewModel.isLoading)
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    private func completeOnboarding() {
        // Update the user's profile
        viewModel.completeOnboarding { success in
            if success {
                // Update UserViewModel with the new data
                userViewModel.name = viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines)
                userViewModel.profileDescription = viewModel.emergencyNote.trimmingCharacters(in: .whitespacesAndNewlines)

                // Mark onboarding as complete
                isOnboarding = false
            } else {
                viewModel.errorMessage = "Failed to create user profile"
                viewModel.showError = true
            }
        }
    }
}

#Preview {
    OnboardingView(isOnboarding: .constant(true))
        .environmentObject(UserViewModel())
}
