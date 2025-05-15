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
                // Alert to Responders button
                Button(action: {
                    // Show alert confirmation
                    userViewModel.showAlertConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 18))
                        Text("Alert to Responders")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 40)
                }
                .padding(.top, 20)

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
                    Text("Check-in Now")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 20)

                // Removed interval information section as per requirements

                Spacer()
            }
            .padding()
            .navigationTitle("Check-In")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            // Show check-in history
                            // This would be implemented in a real app
                        }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.primary)
                        }

                        Button(action: {
                            // Show QR code sharing sheet
                            userViewModel.showQRCodeSheet = true
                        }) {
                            Image(systemName: "qrcode")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
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
            .alert(isPresented: $userViewModel.showAlertConfirmation) {
                Alert(
                    title: Text("Confirm Alert"),
                    message: Text("Are you sure you want to send an alert to your responders?"),
                    primaryButton: .destructive(Text("Send Alert")) {
                        userViewModel.triggerAlert()
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
