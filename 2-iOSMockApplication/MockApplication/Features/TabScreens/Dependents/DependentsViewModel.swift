import Foundation
import SwiftUI
import Combine
import UIKit
import AVFoundation

/// View model for the dependents screen
class DependentsViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Whether the QR scanner is showing
    @Published var showQRScanner: Bool = false

    /// Whether the camera denied alert is showing
    @Published var showCameraDeniedAlert: Bool = false

    /// The new contact
    @Published var newContact: Contact? = nil

    /// The pending scanned code
    @Published var pendingScannedCode: String? = nil

    /// Whether the contact added alert is showing
    @Published var showContactAddedAlert: Bool = false

    /// A UUID used to force refresh the view
    @Published var refreshID = UUID()

    /// The selected sort mode
    @Published var selectedSortMode: SortMode = .countdown

    /// Sort mode for the dependents list in the view
    @Published var displaySortMode: String = "Time Left"

    /// Mock dependents data
    @Published var dependents: [Contact] = []

    /// Selected contact for detail sheet
    @Published var selectedContact: Contact? = nil

    /// Show ping alert
    @Published var showPingAlert: Bool = false

    /// Is ping confirmation
    @Published var isPingConfirmation: Bool = false

    /// Current contact for ping operations
    @Published var currentPingContact: Contact? = nil

    // MARK: - Initialization

    init() {
        // Initialize with mock data
        self.dependents = Contact.mockContacts().filter { $0.isDependent }
        self.selectedSortMode = .countdown
        self.displaySortMode = "Time Left"
    }

    /// Sort modes for the dependents list
    enum SortMode: String, CaseIterable, Identifiable {
        // Order matters for UI presentation
        case countdown = "Time Left"
        case alphabetical = "Name"
        case recentlyAdded = "Date Added"
        var id: String { self.rawValue }
    }

    // MARK: - Methods

    /// Get sorted dependents based on the selected sort mode
    /// - Returns: An array of sorted dependents
    func getSortedDependents() -> [Contact] {
        // First, check for Sam Parker and update isNonResponsive if needed
        for (index, dependent) in dependents.enumerated() where dependent.name == "Sam Parker" {
            // Check if Sam Parker's check-in has expired
            if let lastCheckIn = dependent.lastCheckIn, let interval = dependent.checkInInterval {
                let isExpired = lastCheckIn.addingTimeInterval(interval) < Date()
                if isExpired && !dependent.isNonResponsive {
                    // Update Sam Parker to be non-responsive
                    dependents[index].isNonResponsive = true
                }
            }
        }

        // First, separate dependents into categories
        let manualAlertDependents = dependents.filter { $0.manualAlertActive }

        // Split manual alert dependents into pinged and non-pinged
        let manualAlertPinged = manualAlertDependents.filter { $0.hasOutgoingPing }
        let manualAlertNonPinged = manualAlertDependents.filter { !$0.hasOutgoingPing }

        let nonResponsiveDependents = dependents.filter { !$0.manualAlertActive && $0.isNonResponsive }

        // Split non-responsive dependents into pinged and non-pinged
        let nonResponsivePinged = nonResponsiveDependents.filter { $0.hasOutgoingPing }
        let nonResponsiveNonPinged = nonResponsiveDependents.filter { !$0.hasOutgoingPing }

        // Regular dependents (not in alert or non-responsive)
        let regularDependents = dependents.filter { !$0.manualAlertActive && !$0.isNonResponsive }

        // Split regular dependents into pinged and non-pinged
        let regularPinged = regularDependents.filter { $0.hasOutgoingPing }
        let regularNonPinged = regularDependents.filter { !$0.hasOutgoingPing }

        // For manual alert category, combine pinged and non-pinged, then sort
        let manualAlertCombined = manualAlertPinged + manualAlertNonPinged
        let sortedManualAlert = sortDependentsWithPingedFirst(manualAlertCombined)

        // For non-responsive category, combine pinged and non-pinged, then sort
        let nonResponsiveCombined = nonResponsivePinged + nonResponsiveNonPinged
        let sortedNonResponsive = sortDependentsWithPingedFirst(nonResponsiveCombined)

        // For regular category, combine pinged and non-pinged, then sort
        let regularCombined = regularPinged + regularNonPinged
        let sortedRegular = sortDependentsWithPingedFirst(regularCombined)

        // Combine all sorted groups with priority:
        // 1. manual alert (with pinged at top)
        // 2. non-responsive (with pinged at top)
        // 3. regular (with pinged at top)
        return sortedManualAlert + sortedNonResponsive + sortedRegular
    }

    /// Sort dependents with pinged contacts at the top, then by the selected sort mode
    /// - Parameter dependents: The dependents to sort
    /// - Returns: An array of sorted dependents with pinged contacts at the top
    private func sortDependentsWithPingedFirst(_ dependents: [Contact]) -> [Contact] {
        // First separate pinged and non-pinged
        let (pinged, nonPinged) = dependents.partitioned { $0.hasOutgoingPing }

        // Sort each group by the selected sort mode
        let sortedPinged = sortDependents(pinged)
        let sortedNonPinged = sortDependents(nonPinged)

        // Return pinged first, then non-pinged
        return sortedPinged + sortedNonPinged
    }

    /// Sort dependents based on the selected sort mode
    /// - Parameter dependents: The dependents to sort
    /// - Returns: An array of sorted dependents
    private func sortDependents(_ dependents: [Contact]) -> [Contact] {
        switch selectedSortMode {
        case .countdown:
            return dependents.sorted { (a, b) -> Bool in
                guard let aInterval = a.checkInInterval, let bInterval = b.checkInInterval else { return false }
                guard let aLastCheckIn = a.lastCheckIn, let bLastCheckIn = b.lastCheckIn else { return false }
                let aExpiration = aLastCheckIn.addingTimeInterval(aInterval)
                let bExpiration = bLastCheckIn.addingTimeInterval(bInterval)
                return aExpiration < bExpiration
            }
        case .recentlyAdded:
            // In a real app, we would sort by the date the contact was added
            // For the mock app, we'll just use the ID as a proxy for recency
            return dependents.sorted { $0.id > $1.id }
        case .alphabetical:
            return dependents.sorted { $0.name < $1.name }
        }
    }

    /// Force refresh the view
    func forceRefresh() {
        refreshID = UUID()
    }

    /// Update the sort mode
    /// - Parameter mode: The new sort mode
    func updateSortMode(_ mode: String) {
        // Update the display sort mode
        displaySortMode = mode

        // Convert to view model's sort mode
        switch mode {
        case "Time Left":
            selectedSortMode = .countdown
        case "Name":
            selectedSortMode = .alphabetical
        case "Date Added":
            selectedSortMode = .recentlyAdded
        default:
            selectedSortMode = .countdown
        }

        // Force refresh
        forceRefresh()
    }

    /// Ping a dependent
    /// - Parameter contact: The dependent to ping
    func pingDependent(_ contact: Contact) {
        if let index = dependents.firstIndex(where: { $0.id == contact.id }) {
            dependents[index].hasOutgoingPing = true
            dependents[index].outgoingPingTimestamp = Date()

            // Force refresh
            forceRefresh()

            // Set current ping contact
            currentPingContact = dependents[index]
        }
    }

    /// Clear a ping for a contact
    /// - Parameter contact: The contact to clear the ping for
    func clearPing(for contact: Contact) {
        if let index = dependents.firstIndex(where: { $0.id == contact.id }) {
            dependents[index].hasOutgoingPing = false
            dependents[index].outgoingPingTimestamp = nil

            // Force refresh
            forceRefresh()

            // Set current ping contact
            currentPingContact = dependents[index]
        }
    }

    /// Check if a contact's check-in is expired
    /// - Parameter contact: The contact to check
    /// - Returns: Whether the contact's check-in is expired
    func isCheckInExpired(_ contact: Contact) -> Bool {
        guard let lastCheckIn = contact.lastCheckIn, let interval = contact.checkInInterval else {
            return false
        }
        return lastCheckIn.addingTimeInterval(interval) < Date()
    }

    /// Get the status color for a contact
    /// - Parameter contact: The contact to get the status color for
    /// - Returns: The status color
    func statusColor(for contact: Contact) -> Color {
        if contact.manualAlertActive {
            return .red
        } else if contact.isNonResponsive || isCheckInExpired(contact) {
            return Environment(\.colorScheme).wrappedValue == .light ? Color(UIColor.systemOrange) : .yellow
        } else {
            return .secondary
        }
    }

    /// Get the status text for a contact
    /// - Parameter contact: The contact to get the status text for
    /// - Returns: The status text
    func statusText(for contact: Contact) -> String {
        if contact.manualAlertActive {
            return "Alert Active"
        } else if contact.isNonResponsive || isCheckInExpired(contact) {
            return "Not responsive"
        } else {
            return contact.formattedTimeRemaining
        }
    }

    /// Get the card background for a contact
    /// - Parameter contact: The contact to get the card background for
    /// - Returns: The card background color
    func cardBackground(for contact: Contact) -> Color {
        if contact.manualAlertActive {
            return Color.red.opacity(0.1)
        } else if contact.isNonResponsive || isCheckInExpired(contact) {
            return Environment(\.colorScheme).wrappedValue == .light ?
                Color.orange.opacity(0.15) : Color.yellow.opacity(0.15)
        } else {
            return Color(UIColor.secondarySystemGroupedBackground)
        }
    }

    /// Show the ping alert for a contact
    /// - Parameter contact: The contact to show the ping alert for
    func showPingAlertFor(_ contact: Contact) {
        currentPingContact = contact
        isPingConfirmation = false
        showPingAlert = true
    }

    /// Make the appropriate alert based on the current state
    /// - Returns: The alert to show
    func makeAlert() -> Alert {
        guard let contact = currentPingContact else {
            return Alert(title: Text("Error"), message: Text("No contact selected"), dismissButton: .default(Text("OK")))
        }

        if isPingConfirmation {
            return Alert(
                title: Text("Ping Sent"),
                message: Text("The contact was successfully pinged."),
                dismissButton: .default(Text("OK"))
            )
        } else if contact.hasOutgoingPing {
            return makeClearPingAlert(for: contact)
        } else {
            return makeSendPingAlert(for: contact)
        }
    }

    /// Make an alert for clearing a ping
    /// - Parameter contact: The contact to clear the ping for
    /// - Returns: The alert to show
    private func makeClearPingAlert(for contact: Contact) -> Alert {
        Alert(
            title: Text("Clear Ping"),
            message: Text("Do you want to clear the pending ping to this contact?"),
            primaryButton: .default(Text("Clear")) {
                self.clearPing(for: contact)
                print("Clearing ping for contact: \(contact.name)")
            },
            secondaryButton: .cancel()
        )
    }

    /// Make an alert for sending a ping
    /// - Parameter contact: The contact to send a ping to
    /// - Returns: The alert to show
    private func makeSendPingAlert(for contact: Contact) -> Alert {
        Alert(
            title: Text("Send Ping"),
            message: Text("Are you sure you want to ping this contact?"),
            primaryButton: .default(Text("Ping")) {
                self.pingDependent(contact)
                print("Setting ping for contact: \(contact.name)")

                // Show confirmation alert
                self.isPingConfirmation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.showPingAlert = true
                }
            },
            secondaryButton: .cancel()
        )
    }
}