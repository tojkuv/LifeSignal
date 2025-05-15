import Foundation
import SwiftUI
import Combine

/// View model for the check-in feature
/// This class is designed to mirror the structure of CheckInFeature.State in the TCA implementation
class CheckInViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Whether the check-in confirmation is showing
    @Published var showCheckInConfirmation: Bool = false

    /// The time until the next check-in
    @Published var timeUntilNextCheckIn: String = ""

    /// The check-in interval in hours
    @Published var checkInInterval: Int = 24

    /// The last check-in date
    @Published var lastCheckedIn: Date = Date()

    /// The check-in expiration date
    @Published var checkInExpiration: Date = Date().addingTimeInterval(24 * 60 * 60)

    /// Whether notifications are enabled
    @Published var notificationsEnabled: Bool = true

    /// Whether to notify 30 minutes before check-in expiration
    @Published var notify30MinBefore: Bool = true

    /// Whether to notify 2 hours before check-in expiration
    @Published var notify2HoursBefore: Bool = true

    // MARK: - Private Properties

    /// Timer for updating the time until next check-in
    private var timer: Timer?

    // MARK: - Initialization

    init() {
        // Start the timer
        startTimer()
    }

    deinit {
        // Stop the timer
        stopTimer()
    }

    // MARK: - Methods

    /// Start the timer
    private func startTimer() {
        // Stop any existing timer
        stopTimer()

        // Create a new timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimeUntilNextCheckIn()
        }
    }

    /// Stop the timer
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Update the time until next check-in
    private func updateTimeUntilNextCheckIn() {
        // Calculate the time until next check-in
        let timeInterval = checkInExpiration.timeIntervalSince(Date())

        if timeInterval <= 0 {
            timeUntilNextCheckIn = "Overdue"
        } else {
            // Format the time interval
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.day, .hour, .minute, .second]
            formatter.unitsStyle = .abbreviated

            timeUntilNextCheckIn = formatter.string(from: timeInterval) ?? "Unknown"
        }
    }

    /// Calculate progress for the circle (0.0 to 1.0)
    func calculateProgress() -> CGFloat {
        let totalInterval = Double(checkInInterval * 3600) // Convert hours to seconds
        let elapsed = Date().timeIntervalSince(lastCheckedIn)
        let remaining = max(0, totalInterval - elapsed)
        return CGFloat(remaining / totalInterval)
    }

    /// Format the interval for display
    func formatInterval(_ hours: Int) -> String {
        let days = hours / 24

        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s")"
        } else {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
    }

    /// Format date for display
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Update the last check-in date
    func updateLastCheckedIn() {
        let now = Date()
        lastCheckedIn = now
        checkInExpiration = now.addingTimeInterval(Double(checkInInterval) * 3600)

        // Save to UserDefaults
        UserDefaults.standard.set(now, forKey: "lastCheckedIn")
        UserDefaults.standard.set(checkInExpiration, forKey: "checkInExpiration")

        // Show silent local notification
        showCheckInNotification()
    }

    /// Show a silent local notification for check-in
    private func showCheckInNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Check-in Completed"
        content.body = "You have successfully checked in."
        content.sound = .none

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}