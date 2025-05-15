import SwiftUI

/// A view for the alert feature
struct AlertView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @StateObject private var viewModel: AlertViewModel

    init() {
        // Create the view model with the user view model from the environment
        _viewModel = StateObject(wrappedValue: AlertViewModel())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Alert status card
                    VStack(spacing: 16) {
                        HStack {
                            Text("Alert Status")
                                .font(.headline)
                            Spacer()
                        }

                        HStack {
                            Image(systemName: viewModel.isAlertActive ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundColor(viewModel.isAlertActive ? .red : .green)
                                .font(.system(size: 24))

                            Text(viewModel.isAlertActive ? "Alert Active" : "No Active Alerts")
                                .font(.title3)
                                .foregroundColor(viewModel.isAlertActive ? .red : .green)

                            Spacer()

                            if viewModel.isAlertActive {
                                Button(action: {
                                    viewModel.clearAlert()
                                }) {
                                    Text("Clear")
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.blue)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Trigger alert button
                    Button(action: {
                        viewModel.showAlertConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 20))
                            Text("Trigger Manual Alert")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(viewModel.isTriggering ? Color.gray : Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    .disabled(viewModel.isTriggering || viewModel.isAlertActive)

                    // Alert history
                    VStack(spacing: 16) {
                        HStack {
                            Text("Alert History")
                                .font(.headline)
                            Spacer()
                        }

                        if viewModel.alertHistory.isEmpty {
                            Text("No alert history")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(viewModel.alertHistory) { alert in
                                AlertHistoryRow(alert: alert)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Alert")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Update the view model with the user view model from the environment
                viewModel.updateUserViewModel(userViewModel)
            }
            .alert(isPresented: $viewModel.showAlertConfirmation) {
                Alert(
                    title: Text("Confirm Alert"),
                    message: Text("Are you sure you want to trigger a manual alert? This will notify all your responders."),
                    primaryButton: .destructive(Text("Trigger Alert")) {
                        viewModel.triggerAlert(type: .manual)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}

/// A row for displaying an alert history item
struct AlertHistoryRow: View {
    let alert: AlertEvent

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.type.rawValue)
                    .font(.headline)

                Text(formatDate(alert.timestamp))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(alert.resolved ? "Resolved" : "Active")
                .font(.subheadline)
                .foregroundColor(alert.resolved ? .green : .red)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(alert.resolved ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                )
        }
        .padding(.vertical, 8)
    }

    /// Format a date for display
    /// - Parameter date: The date to format
    /// - Returns: A formatted string representation of the date
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    AlertView()
        .environmentObject(UserViewModel())
}
