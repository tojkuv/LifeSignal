import SwiftUI
import Foundation

struct CheckInView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @StateObject private var viewModel = CheckInViewModel()

    // MARK: - Lifecycle

    init() {
        // Create a view model
        _viewModel = StateObject(wrappedValue: CheckInViewModel())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Countdown circle
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 15)
                        .frame(width: 220, height: 220)

                    // Progress circle
                    Circle()
                        .trim(from: 0, to: viewModel.calculateProgress())
                        .stroke(
                            viewModel.calculateProgress() < 0.25 ? Color.red :
                                viewModel.calculateProgress() < 0.5 ? Color.orange : Color.blue,
                            style: StrokeStyle(lineWidth: 15, lineCap: .round)
                        )
                        .frame(width: 220, height: 220)
                        .rotationEffect(.degrees(-90))

                    // Time remaining text
                    VStack(spacing: 8) {
                        Text("Time Remaining")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text(viewModel.timeUntilNextCheckIn)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("until check-in")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                .padding(.top, 40)

                // Check-in button
                Button(action: {
                    viewModel.showCheckInConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                        Text("Check In Now")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 40)
                }
                .padding(.top, 20)

                // Interval information
                VStack(spacing: 16) {
                    HStack {
                        Text("Check-in interval:")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(viewModel.formatInterval(viewModel.checkInInterval))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    HStack {
                        Text("Last checked in:")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(viewModel.formatDate(viewModel.lastCheckedIn))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    HStack {
                        Text("Next check-in due:")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(viewModel.formatDate(userViewModel.checkInExpiration))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 20)

                Spacer()
            }
            .padding()
            .navigationTitle("Check-In")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Sync view model with user view model
                viewModel.lastCheckedIn = userViewModel.lastCheckIn
                viewModel.checkInInterval = Int(userViewModel.checkInInterval / 3600)
                viewModel.checkInExpiration = userViewModel.checkInExpiration
            }
            .alert(isPresented: $viewModel.showCheckInConfirmation) {
                Alert(
                    title: Text("Confirm Check-in"),
                    message: Text("Are you sure you want to check in now? This will reset your timer."),
                    primaryButton: .default(Text("Check In")) {
                        // Update both view models
                        viewModel.updateLastCheckedIn()
                        userViewModel.checkIn()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }


}

#Preview {
    CheckInView()
        .environmentObject(UserViewModel())
}
