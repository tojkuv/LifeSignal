import SwiftUI
import Foundation
import UIKit


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

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 16) {
        // Normal dependent
        DependentCardView(
            contact: Contact(
                id: "1",
                name: "John Smith",
                phone: "555-123-4567",
                qrCodeId: "qr123",
                lastCheckIn: Date(),
                note: "Regular dependent",
                manualAlertActive: false,
                isNonResponsive: false,
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                isResponder: false,
                isDependent: true,
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 24 * 60 * 60,
                manualAlertTimestamp: nil
            ),
            refreshID: UUID()
        )

        // Dependent with alert
        DependentCardView(
            contact: Contact(
                id: "2",
                name: "Jane Doe",
                phone: "555-987-6543",
                qrCodeId: "qr456",
                lastCheckIn: Date(),
                note: "Dependent with alert",
                manualAlertActive: true,
                isNonResponsive: false,
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                isResponder: false,
                isDependent: true,
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 24 * 60 * 60,
                manualAlertTimestamp: Date()
            ),
            refreshID: UUID()
        )

        // Non-responsive dependent
        DependentCardView(
            contact: Contact(
                id: "3",
                name: "Alex Johnson",
                phone: "555-555-5555",
                qrCodeId: "qr789",
                lastCheckIn: Date().addingTimeInterval(-48 * 60 * 60),
                note: "Non-responsive dependent",
                manualAlertActive: false,
                isNonResponsive: true,
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                isResponder: false,
                isDependent: true,
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 24 * 60 * 60,
                manualAlertTimestamp: nil
            ),
            refreshID: UUID()
        )

        // Dependent with ping
        DependentCardView(
            contact: Contact(
                id: "4",
                name: "Sam Wilson",
                phone: "555-111-2222",
                qrCodeId: "qr101",
                lastCheckIn: Date(),
                note: "Dependent with ping",
                manualAlertActive: false,
                isNonResponsive: false,
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                isResponder: false,
                isDependent: true,
                hasOutgoingPing: true,
                outgoingPingTimestamp: Date(),
                checkInInterval: 24 * 60 * 60,
                manualAlertTimestamp: nil
            ),
            refreshID: UUID()
        )

        // Dependent with both alert and ping
        DependentCardView(
            contact: Contact(
                id: "5",
                name: "Maria Garcia",
                phone: "555-444-3333",
                qrCodeId: "qr202",
                lastCheckIn: Date(),
                note: "Dependent with both alert and ping",
                manualAlertActive: true,
                isNonResponsive: false,
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                isResponder: false,
                isDependent: true,
                hasOutgoingPing: true,
                outgoingPingTimestamp: Date(),
                checkInInterval: 24 * 60 * 60,
                manualAlertTimestamp: Date()
            ),
            refreshID: UUID()
        )
    }
    .padding()
    .environmentObject(UserViewModel())
}