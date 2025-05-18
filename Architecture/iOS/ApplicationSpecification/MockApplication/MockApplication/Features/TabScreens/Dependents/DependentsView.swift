import SwiftUI
import Foundation
import UIKit
import AVFoundation
import PhotosUI

/// Sort mode for the dependents list
enum SortMode: String, CaseIterable, Identifiable {
    case timeLeft = "Time Left"
    case name = "Name"
    case dateAdded = "Date Added"

    var id: String { self.rawValue }
}

struct DependentsView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @StateObject private var viewModel = DependentsViewModel()

    // State variables
    @State private var refreshID = UUID()
    @State private var showCheckInConfirmation = false
    @State private var sortMode: SortMode = .timeLeft

    // Debug state to track dependent count
    @State private var dependentCount: Int = 0

    // MARK: - Lifecycle

    init() {
        // Create a view model
        let viewModel = DependentsViewModel()
        // Set initial sort mode
        viewModel.selectedSortMode = .countdown
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    /// Computed property to get sorted dependents from the view model
    private var sortedDependents: [Contact] {
        // This will be recalculated when the view model's refreshID changes
        return viewModel.getSortedDependents()
    }

    /// Convert between the view's SortMode and the view model's SortMode
    private func convertSortMode(_ mode: SortMode) -> DependentsViewModel.SortMode {
        switch mode {
        case .timeLeft:
            return .countdown
        case .name:
            return .alphabetical
        case .dateAdded:
            return .recentlyAdded
        }
    }

    var body: some View {
        // Simplified scrollable view with direct LazyVStack
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 12) {
                if userViewModel.dependents.isEmpty {
                    Text("No dependents yet")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else {
                    ForEach(sortedDependents) { dependent in
                        DependentCardView(contact: dependent, refreshID: viewModel.refreshID)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            // Add observer for refresh notifications
            NotificationCenter.default.addObserver(forName: NSNotification.Name("RefreshDependentsView"), object: nil, queue: .main) { _ in
                refreshID = UUID()
            }

            // Set the user view model to ensure data is loaded
            viewModel.setUserViewModel(userViewModel)

            // Force refresh when view appears to ensure sort is applied
            refreshID = UUID()
            viewModel.forceRefresh()
            print("DependentsView appeared with sort mode: \(sortMode.rawValue)")
            print("DependentsView has \(userViewModel.dependents.count) dependents")

            // Debug: print all dependents
            for (index, dependent) in userViewModel.dependents.enumerated() {
                print("Dependent \(index+1): \(dependent.name) (isDependent: \(dependent.isDependent))")
            }
        }
        .onChange(of: userViewModel.dependents) { _, _ in
            // Refresh when dependents change
            viewModel.forceRefresh()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    ForEach(SortMode.allCases) { mode in
                        Button(action: {
                            HapticFeedback.selectionFeedback()
                            sortMode = mode
                            // Update view model's sort mode
                            viewModel.selectedSortMode = convertSortMode(mode)
                            // Force refresh when sort mode changes
                            refreshID = UUID()
                            viewModel.forceRefresh()
                            print("Sort mode changed to: \(mode.rawValue)")
                        }) {
                            Label(mode.rawValue, systemImage: sortMode == mode ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(sortMode.rawValue)
                            .font(.caption)
                    }
                }
                .accessibilityLabel("Sort Dependents")
                .hapticFeedback(style: .light)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: NotificationCenterView()) {
                    Image(systemName: "square.fill.text.grid.1x2")
                }
                .hapticFeedback(style: .light)
            }
        }


        .alert(isPresented: $showCheckInConfirmation) {
            Alert(
                title: Text("Confirm Check-in"),
                message: Text("Are you sure you want to check in now? This will reset your timer."),
                primaryButton: .default(Text("Check In")) {
                    userViewModel.checkIn()
                },
                secondaryButton: .cancel()
            )
        }

        .onAppear {
            // Sync view model with user view model
            viewModel.setUserViewModel(userViewModel)
        }
    }
}

/// A view modifier that creates a flashing animation
struct FlashingAnimation: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? 0.5 : 1.0)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

/// A view modifier that creates a flashing animation for the entire card
struct CardFlashingAnimation: ViewModifier {
    let isActive: Bool
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(isAnimating && isActive ? 0.2 : 0.1))
            )
            .onAppear {
                if isActive {
                    withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                }
            }
    }
}

struct DependentCardView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    let contact: Contact
    let refreshID: UUID // Used to force refresh when ping state changes

    // Use @State for alert control
    @State private var showPingAlert = false
    @State private var isPingConfirmation = false
    @State private var selectedContactID: ContactID?

    // Debug state
    @State private var hasLogged = false

    var statusColor: Color {
        if contact.manualAlertActive {
            // Match ContactDetailsSheet exactly
            return .red
        } else if contact.isNonResponsive || isCheckInExpired(contact) {
            // Match ContactDetailsSheet exactly
            return Environment(\.colorScheme).wrappedValue == .light ? Color(UIColor.systemOrange) : .yellow
        } else {
            return .secondary
        }
    }

    var statusText: String {
        if contact.manualAlertActive {
            return "Alert Active"
        } else if contact.isNonResponsive || isCheckInExpired(contact) {
            return "Not responsive"
        } else {
            return contact.formattedTimeRemaining
        }
    }

    var body: some View {
        cardContent
            .padding()
            .background(cardBackground)
            .overlay(cardBorder)
            .cornerRadius(12)
            .modifier(CardFlashingAnimation(isActive: contact.manualAlertActive))
            .onTapGesture {
                HapticFeedback.triggerHaptic()
                selectedContactID = ContactID(id: contact.id)
            }
            .sheet(item: $selectedContactID) { id in
                if let contact = userViewModel.contacts.first(where: { $0.id == id.id }) {
                    ContactDetailsSheet(contact: contact)
                }
            }
            .alert(isPresented: $showPingAlert) {
                makeAlert()
            }
    }

    /// The main content of the card
    private var cardContent: some View {
        HStack(spacing: 12) {
            // Avatar with badge - positioned exactly like ResponderCardView
            avatarView

            // Name and status - positioned exactly like ResponderCardView
            infoView

            Spacer()
        }
    }

    /// Avatar view with ping badge
    private var avatarView: some View {
        ZStack(alignment: .topTrailing) {
            // Avatar circle - match ResponderCardView exactly
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(contact.name.prefix(1)))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                )

            // Ping badge (only for ping status)
            if contact.hasOutgoingPing {
                pingBadge
            }
        }
    }

    /// Ping badge view
    private var pingBadge: some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 20, height: 20)
            .overlay(
                Image(systemName: "bell.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
            )
            .offset(x: 5, y: -5)
    }

    /// Contact info view
    private var infoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(contact.name)
                    .font(.body)
                    .foregroundColor(.primary)
            }

            if !statusText.isEmpty {
                Text(statusText)
                    .font(.footnote)
                    .foregroundColor(statusColor)
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }

    /// Card background based on contact status
    @ViewBuilder
    private var cardBackground: some View {
        if contact.manualAlertActive {
            // Match ContactDetailsSheet exactly
            Color.red.opacity(0.1)
        } else if contact.isNonResponsive || isCheckInExpired(contact) {
            // Match ContactDetailsSheet exactly
            Environment(\.colorScheme).wrappedValue == .light ?
                Color.orange.opacity(0.15) : Color.yellow.opacity(0.15)
        } else {
            Color(UIColor.secondarySystemGroupedBackground)
        }
    }

    /// Check if the contact's check-in is expired
    private func isCheckInExpired(_ contact: Contact) -> Bool {
        guard let lastCheckIn = contact.lastCheckIn, let interval = contact.checkInInterval else {
            return false
        }
        return lastCheckIn.addingTimeInterval(interval) < Date()
    }

    /// Card border
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.clear, lineWidth: 0)
    }

    /// Creates the appropriate alert based on the current state
    private func makeAlert() -> Alert {
        if isPingConfirmation {
            return Alert(
                title: Text("Ping Sent"),
                message: Text("The contact was successfully pinged."),
                dismissButton: .default(Text("OK"))
            )
        } else if contact.hasOutgoingPing {
            return makeClearPingAlert()
        } else {
            return makeSendPingAlert()
        }
    }

    /// Creates an alert for clearing a ping
    private func makeClearPingAlert() -> Alert {
        Alert(
            title: Text("Clear Ping"),
            message: Text("Do you want to clear the pending ping to this contact?"),
            primaryButton: .default(Text("Clear")) {
                // Use the view model to clear the ping
                userViewModel.clearPing(for: contact)

                // Debug print
                print("Clearing ping for contact: \(contact.name)")

                // Force refresh immediately
                NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
            },
            secondaryButton: .cancel()
        )
    }

    /// Creates an alert for sending a ping
    private func makeSendPingAlert() -> Alert {
        Alert(
            title: Text("Send Ping"),
            message: Text("Are you sure you want to ping this contact?"),
            primaryButton: .default(Text("Ping")) {
                // Use the view model to ping the dependent
                userViewModel.pingDependent(contact)

                // Debug print
                print("Setting ping for contact: \(contact.name)")

                // Force refresh immediately
                NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)

                // Show confirmation alert
                isPingConfirmation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showPingAlert = true
                }
            },
            secondaryButton: .cancel()
        )
    }
}