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
        case recentlyAdded = "Recently Added"
        case alphabetical = "Alphabetical"
        var id: String { self.rawValue }
    }

    /// Get sorted dependents based on the selected sort mode
    /// - Returns: An array of sorted dependents
    func getSortedDependents() -> [Contact] {
        guard let userViewModel = userViewModel else { return [] }

        let dependents = userViewModel.dependents

        // First, separate dependents into categories
        let manualAlertDependents = dependents.filter { $0.manualAlertActive }
        let nonResponsiveDependents = dependents.filter { !$0.manualAlertActive && $0.isNonResponsive }
        let pingedDependents = dependents.filter { !$0.manualAlertActive && !$0.isNonResponsive && $0.hasOutgoingPing }
        let responsiveDependents = dependents.filter { !$0.manualAlertActive && !$0.isNonResponsive && !$0.hasOutgoingPing }

        // Sort each category based on the selected sort mode
        let sortedManualAlert = sortDependents(manualAlertDependents)
        let sortedNonResponsive = sortDependents(nonResponsiveDependents)
        let sortedPinged = sortDependents(pingedDependents)
        let sortedResponsive = sortDependents(responsiveDependents)

        // Combine all sorted groups with priority: manual alert > non-responsive > pinged > responsive
        return sortedManualAlert + sortedNonResponsive + sortedPinged + sortedResponsive
    }

    /// Sort dependents based on the selected sort mode
    /// - Parameter dependents: The dependents to sort
    /// - Returns: An array of sorted dependents
    private func sortDependents(_ dependents: [Contact]) -> [Contact] {
        switch selectedSortMode {
        case .countdown:
            return dependents.sorted { (a, b) -> Bool in
                guard let aInterval = a.checkInInterval, let bInterval = b.checkInInterval else { return false }
                let aExpiration = a.lastCheckIn.addingTimeInterval(aInterval)
                let bExpiration = b.lastCheckIn.addingTimeInterval(bInterval)
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