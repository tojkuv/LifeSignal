import Foundation
import UserNotifications
import SwiftUI

/// A manager for handling local notifications
class NotificationManager {
    // MARK: - Shared Instance

    /// The shared instance of the notification manager
    static let shared = NotificationManager()

    // MARK: - Properties

    /// Whether notifications are authorized
    private var isAuthorized = false

    /// Notification center for posting local notifications
    private let notificationCenter = NotificationCenter.default

    // MARK: - Initialization

    /// Private initializer to enforce singleton pattern
    private init() {
        // Check authorization status
        checkAuthorizationStatus()

        // Print debug info
        print("NotificationManager initialized")
    }

    // MARK: - Methods

    /// Check the authorization status for notifications
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
                print("Notification authorization status: \(settings.authorizationStatus.rawValue)")
            }
        }
    }

    /// Request authorization for notifications
    /// - Parameter completion: Completion handler with a boolean indicating success
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                print("Notification authorization request result: \(granted)")
                if let error = error {
                    print("Notification authorization error: \(error.localizedDescription)")
                }
                completion(granted)
            }
        }
    }

    /// Show a local notification
    /// - Parameters:
    ///   - title: The notification title
    ///   - body: The notification body
    ///   - sound: The notification sound (nil for silent)
    ///   - delay: The delay before showing the notification
    ///   - completion: Completion handler with an optional error
    func showLocalNotification(
        title: String,
        body: String,
        sound: UNNotificationSound? = UNNotificationSound.default,
        delay: TimeInterval = 0.1,
        completion: ((Error?) -> Void)? = nil
    ) {
        // Check if authorized
        if !isAuthorized {
            // Request authorization if not authorized
            requestAuthorization { granted in
                if granted {
                    self.scheduleNotification(title: title, body: body, sound: sound, delay: delay, completion: completion)
                } else {
                    print("Notification authorization denied")
                    completion?(NSError(domain: "NotificationManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Notification authorization denied"]))
                }
            }
        } else {
            // Schedule the notification
            scheduleNotification(title: title, body: body, sound: sound, delay: delay, completion: completion)
        }
    }

    /// Show a silent local notification that appears as a toast message but doesn't persist in the system notification center
    /// This notification will be tracked in the notification center
    /// - Parameters:
    ///   - title: The notification title
    ///   - body: The notification body
    ///   - type: The notification type
    ///   - delay: The delay before showing the notification
    ///   - completion: Completion handler with an optional error
    func showSilentLocalNotification(
        title: String,
        body: String,
        type: NotificationType,
        delay: TimeInterval = 0.1,
        completion: ((Error?) -> Void)? = nil
    ) {
        // Check if authorized
        if !isAuthorized {
            // Request authorization if not authorized
            requestAuthorization { granted in
                if granted {
                    self.scheduleSilentNotification(title: title, body: body, type: type, delay: delay, trackInCenter: true, completion: completion)
                } else {
                    print("Notification authorization denied")
                    completion?(NSError(domain: "NotificationManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Notification authorization denied"]))
                }
            }
        } else {
            // Schedule the silent notification
            scheduleSilentNotification(title: title, body: body, type: type, delay: delay, trackInCenter: true, completion: completion)
        }
    }

    /// Show a feedback-only silent notification that appears as a toast message but isn't tracked in the notification center
    /// - Parameters:
    ///   - title: The notification title
    ///   - body: The notification body
    ///   - delay: The delay before showing the notification
    ///   - completion: Completion handler with an optional error
    func showFeedbackNotification(
        title: String,
        body: String,
        delay: TimeInterval = 0.1,
        completion: ((Error?) -> Void)? = nil
    ) {
        // Check if authorized
        if !isAuthorized {
            // Request authorization if not authorized
            requestAuthorization { granted in
                if granted {
                    self.scheduleSilentNotification(title: title, body: body, type: .pingNotification, delay: delay, trackInCenter: false, completion: completion)
                } else {
                    print("Notification authorization denied")
                    completion?(NSError(domain: "NotificationManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Notification authorization denied"]))
                }
            }
        } else {
            // Schedule the silent notification without tracking
            scheduleSilentNotification(title: title, body: body, type: .pingNotification, delay: delay, trackInCenter: false, completion: completion)
        }
    }

    /// Schedule a silent notification that will be removed from the notification center after being displayed
    /// - Parameters:
    ///   - title: The notification title
    ///   - body: The notification body
    ///   - type: The notification type
    ///   - delay: The delay before showing the notification
    ///   - trackInCenter: Whether to track this notification in the notification center
    ///   - completion: Completion handler with an optional error
    private func scheduleSilentNotification(
        title: String,
        body: String,
        type: NotificationType,
        delay: TimeInterval,
        trackInCenter: Bool = true,
        completion: ((Error?) -> Void)?
    ) {
        // Create the notification content
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        // No sound for silent notifications

        // Create the trigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)

        // Create a unique identifier
        let identifier = UUID().uuidString

        // Create the request
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        // Add the request to the notification center
        UNUserNotificationCenter.current().add(request) { error in
            // Trigger haptic feedback
            HapticFeedback.notificationFeedback()

            // Call the completion handler
            completion?(error)

            // Post a notification to update the notification center if tracking is enabled
            if trackInCenter {
                self.notificationCenter.post(
                    name: NSNotification.Name("NewNotification"),
                    object: nil,
                    userInfo: [
                        "title": title,
                        "body": body,
                        "type": type.rawValue
                    ]
                )
            }

            // Remove the notification from the notification center after a short delay
            // This ensures it doesn't stay in the system notification center
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
            }
        }
    }

    /// Schedule a notification
    /// - Parameters:
    ///   - title: The notification title
    ///   - body: The notification body
    ///   - sound: The notification sound
    ///   - delay: The delay before showing the notification
    ///   - completion: Completion handler with an optional error
    private func scheduleNotification(
        title: String,
        body: String,
        sound: UNNotificationSound?,
        delay: TimeInterval,
        completion: ((Error?) -> Void)?
    ) {
        // Create the notification content
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let sound = sound {
            content.sound = sound
        }

        // Create the trigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)

        // Create the request with a unique identifier
        let identifier = UUID().uuidString
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        print("Scheduling notification with ID: \(identifier), title: \(title)")

        // Add the request to the notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            } else {
                print("Successfully scheduled notification with ID: \(identifier)")
            }
            completion?(error)
        }
    }

    /// Clear all pending notifications
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Clear all delivered notifications
    func clearAllDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    // MARK: - Specialized Notification Methods

    /// Show a notification for contact role toggle
    /// - Parameters:
    ///   - contactName: The name of the contact
    ///   - isResponder: Whether the contact is now a responder
    ///   - isDependent: Whether the contact is now a dependent
    ///   - wasResponder: Whether the contact was previously a responder
    ///   - wasDependent: Whether the contact was previously a dependent
    func showContactRoleToggleNotification(
        contactName: String,
        isResponder: Bool,
        isDependent: Bool,
        wasResponder: Bool = false,
        wasDependent: Bool = false
    ) {
        // Determine which role changed
        let responderChanged = isResponder != wasResponder
        let dependentChanged = isDependent != wasDependent

        // Create appropriate message based on the specific role change
        var title = "Contact Role Updated"
        var body = ""

        if responderChanged && dependentChanged {
            // Both roles changed
            if isResponder && isDependent {
                body = "\(contactName) is now both a responder and a dependent."
            } else if !isResponder && !isDependent {
                body = "\(contactName) is no longer a responder or a dependent."
            } else {
                // This shouldn't happen in normal usage (toggling both roles in opposite directions)
                body = "\(contactName)'s roles have been updated."
            }
        } else if responderChanged {
            // Only responder role changed
            if isResponder {
                title = "Responder Added"
                body = "\(contactName) can now respond to your alerts."
            } else {
                title = "Responder Removed"
                body = "\(contactName) will no longer respond to your alerts."
            }
        } else if dependentChanged {
            // Only dependent role changed
            if isDependent {
                title = "Dependent Added"
                body = "You can now check on \(contactName)."
            } else {
                title = "Dependent Removed"
                body = "You will no longer check on \(contactName)."
            }
        } else {
            // No role actually changed (shouldn't happen)
            body = "\(contactName)'s roles remain unchanged."
        }

        showSilentLocalNotification(
            title: title,
            body: body,
            type: .contactRoleChanged
        )
    }

    /// Show a notification for a ping action
    /// - Parameter contactName: The name of the contact being pinged
    func showPingNotification(contactName: String) {
        showSilentLocalNotification(
            title: "Ping Sent",
            body: "You pinged \(contactName).",
            type: .pingNotification
        )
    }

    /// Show a notification for a check-in action
    func showCheckInNotification() {
        showSilentLocalNotification(
            title: "Check-in Completed",
            body: "You have successfully checked in.",
            type: .checkInReminder
        )
    }

    /// Show a notification for alert activation
    func showAlertActivationNotification() {
        showSilentLocalNotification(
            title: "Alert Activated",
            body: "You have activated an alert. Your responders have been notified.",
            type: .manualAlert
        )
    }

    /// Show a notification for alert deactivation
    func showAlertDeactivationNotification() {
        showSilentLocalNotification(
            title: "Alert Deactivated",
            body: "You have deactivated your alert.",
            type: .manualAlert
        )
    }

    /// Show a notification when all pings are cleared
    func showAllPingsClearedNotification() {
        showSilentLocalNotification(
            title: "All Pings Cleared",
            body: "You have cleared all pending pings.",
            type: .pingNotification
        )
    }

    /// Show a notification when QR code ID is copied
    func showQRCodeCopiedNotification() {
        showFeedbackNotification(
            title: "QR Code ID Copied",
            body: "Your QR code ID has been copied to the clipboard."
        )
    }

    /// Show a notification when QR code is reset
    func showQRCodeResetNotification() {
        showFeedbackNotification(
            title: "QR Code Reset",
            body: "Your QR code has been reset. Previous QR codes are no longer valid."
        )
    }

    /// Show a notification when phone number is changed
    func showPhoneNumberChangedNotification() {
        showFeedbackNotification(
            title: "Phone Number Updated",
            body: "Your phone number has been successfully updated."
        )
    }

    /// Show a notification when notification settings are updated
    func showNotificationSettingsUpdatedNotification() {
        showFeedbackNotification(
            title: "Notification Settings Updated",
            body: "Your notification settings have been successfully updated."
        )
    }

    /// Show a notification for adding a contact
    /// - Parameter contactName: The name of the contact being added
    func showContactAddedNotification(contactName: String) {
        showSilentLocalNotification(
            title: "Contact Added",
            body: "You have added \(contactName) to your contacts.",
            type: .contactAdded
        )
    }

    /// Show a notification for removing a contact
    /// - Parameter contactName: The name of the contact being removed
    func showContactRemovedNotification(contactName: String) {
        showSilentLocalNotification(
            title: "Contact Removed",
            body: "You have removed \(contactName) from your contacts.",
            type: .contactRemoved
        )
    }
}