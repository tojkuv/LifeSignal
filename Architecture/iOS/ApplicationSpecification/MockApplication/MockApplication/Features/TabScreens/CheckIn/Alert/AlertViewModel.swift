import Foundation
import SwiftUI
import Combine

/// View model for the alert feature
class AlertViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The user view model
    private var userViewModel: UserViewModel

    /// Whether the alert is active
    @Published var isAlertActive: Bool = false

    /// The alert history
    @Published var alertHistory: [AlertEvent] = []

    /// Whether the alert confirmation is showing
    @Published var showAlertConfirmation: Bool = false

    /// Whether the alert is being triggered
    @Published var isTriggering: Bool = false

    // MARK: - Initialization

    init(userViewModel: UserViewModel = UserViewModel()) {
        self.userViewModel = userViewModel
        self.isAlertActive = userViewModel.isAlertActive

        // Generate mock alert history
        alertHistory = [
            AlertEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-86400 * 3),
                type: .manual,
                resolved: true
            ),
            AlertEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-86400 * 7),
                type: .checkInExpired,
                resolved: true
            )
        ]
    }

    // MARK: - Methods

    /// Trigger an alert
    /// - Parameter type: The type of alert
    func triggerAlert(type: AlertType) {
        showAlertConfirmation = false
        isTriggering = true

        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isTriggering = false
            self.isAlertActive = true
            self.userViewModel.isAlertActive = true

            // Add to history
            self.alertHistory.insert(
                AlertEvent(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    type: type,
                    resolved: false
                ),
                at: 0
            )
        }
    }

    /// Clear the active alert
    func clearAlert() {
        isAlertActive = false
        userViewModel.isAlertActive = false

        // Mark the most recent alert as resolved
        if !alertHistory.isEmpty {
            alertHistory[0].resolved = true
        }
    }

    /// Update the user view model
    /// - Parameter userViewModel: The user view model
    func updateUserViewModel(_ userViewModel: UserViewModel) {
        self.userViewModel = userViewModel
        self.isAlertActive = userViewModel.isAlertActive
    }
}

/// An alert event
struct AlertEvent: Identifiable, Equatable {
    /// The alert ID
    var id: String

    /// The alert timestamp
    var timestamp: Date

    /// The alert type
    var type: AlertType

    /// Whether the alert has been resolved
    var resolved: Bool
}

/// Alert types
enum AlertType: String, CaseIterable, Identifiable {
    /// A manual alert
    case manual = "Manual Alert"

    /// A check-in expired alert
    case checkInExpired = "Check-in Expired"

    /// The alert ID
    var id: String { self.rawValue }
}
