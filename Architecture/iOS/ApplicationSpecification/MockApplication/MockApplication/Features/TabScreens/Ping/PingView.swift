import SwiftUI

/// A view for the ping feature
struct PingView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @StateObject private var viewModel: PingViewModel

    init() {
        // Create the view model with the user view model from the environment
        _viewModel = StateObject(wrappedValue: PingViewModel())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Ping history
                    VStack(spacing: 16) {
                        HStack {
                            Text("Ping History")
                                .font(.headline)
                            Spacer()
                        }

                        if viewModel.pingHistory.isEmpty {
                            Text("No ping history")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(viewModel.pingHistory) { ping in
                                PingHistoryRow(ping: ping)
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
            .navigationTitle("Pings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Update the view model with the user view model from the environment
                viewModel.updateUserViewModel(userViewModel)
            }
            .alert(isPresented: $viewModel.showPingConfirmation) {
                Alert(
                    title: Text("Confirm Ping"),
                    message: Text("Are you sure you want to ping \(viewModel.contactToPing?.name ?? "this contact")? They will receive a notification."),
                    primaryButton: .default(Text("Send Ping")) {
                        if let contact = viewModel.contactToPing {
                            viewModel.sendPing(to: contact)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}

/// A row for displaying a ping history item
struct PingHistoryRow: View {
    let ping: PingEvent

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ping.contactName)
                    .font(.headline)

                Text(formatDate(ping.timestamp))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(ping.direction.rawValue)
                    .font(.subheadline)
                    .foregroundColor(ping.direction == .outgoing ? .blue : .green)

                Text(ping.status.rawValue)
                    .font(.subheadline)
                    .foregroundColor(ping.status == .pending ? .orange : .green)
            }
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
    PingView()
        .environmentObject(UserViewModel())
}
