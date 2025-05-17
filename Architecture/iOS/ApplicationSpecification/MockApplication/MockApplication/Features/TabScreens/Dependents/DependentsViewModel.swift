import Foundation
import SwiftUI
import Combine

/// View model for the dependents screen
class DependentsViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Whether the QR scanner is showing
    @Published var showQRScanner: Bool = false

    /// Whether the check-in confirmation is showing
    @Published var showCheckInConfirmation: Bool = false

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

    // MARK: - Private Properties

    /// The user view model
    private var userViewModel: UserViewModel?

    // MARK: - Initialization

    init() {
        // Initialize with default values
    }

    // MARK: - Methods

    /// Set the user view model
    /// - Parameter userViewModel: The user view model
    func setUserViewModel(_ userViewModel: UserViewModel) {
        self.userViewModel = userViewModel
    }

    /// Sort modes for the dependents list
    enum SortMode: String, CaseIterable, Identifiable {
        // Order matters for UI presentation
        case countdown = "Time Left"
        case alphabetical = "Name"
        case recentlyAdded = "Date Added"
        var id: String { self.rawValue }
    }

    /// Get sorted dependents based on the selected sort mode
    /// - Returns: An array of sorted dependents
    func getSortedDependents() -> [Contact] {
        guard let userViewModel = userViewModel else { return [] }

        let dependents = userViewModel.dependents

        // First, check for Sam Parker and update isNonResponsive if needed
        for (index, dependent) in dependents.enumerated() where dependent.name == "Sam Parker" {
            // Check if Sam Parker's check-in has expired
            if let lastCheckIn = dependent.lastCheckIn, let interval = dependent.checkInInterval {
                let isExpired = lastCheckIn.addingTimeInterval(interval) < Date()
                if isExpired && !dependent.isNonResponsive {
                    // Update Sam Parker to be non-responsive
                    userViewModel.updateContact(id: dependent.id) { contact in
                        contact.isNonResponsive = true
                    }
                }
            }
        }

        // Get updated dependents after potential changes
        let updatedDependents = userViewModel.dependents

        // First, separate dependents into categories
        let manualAlertDependents = updatedDependents.filter { $0.manualAlertActive }

        // Split manual alert dependents into pinged and non-pinged
        let manualAlertPinged = manualAlertDependents.filter { $0.hasOutgoingPing }
        let manualAlertNonPinged = manualAlertDependents.filter { !$0.hasOutgoingPing }

        let nonResponsiveDependents = updatedDependents.filter { !$0.manualAlertActive && $0.isNonResponsive }

        // Split non-responsive dependents into pinged and non-pinged
        let nonResponsivePinged = nonResponsiveDependents.filter { $0.hasOutgoingPing }
        let nonResponsiveNonPinged = nonResponsiveDependents.filter { !$0.hasOutgoingPing }

        // Regular dependents (not in alert or non-responsive)
        let regularDependents = updatedDependents.filter { !$0.manualAlertActive && !$0.isNonResponsive }

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
}