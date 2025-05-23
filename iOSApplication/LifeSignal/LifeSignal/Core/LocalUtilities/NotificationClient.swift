import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation
import UserNotifications

// MARK: - Notification Client

@DependencyClient
struct NotificationClient {
    var showQRCodeResetNotification: @Sendable () async -> Void
    var showNotificationSettingsUpdatedNotification: @Sendable () async -> Void
    var showCheckInNotification: @Sendable () async -> Void
    var showAlertActivationNotification: @Sendable () async -> Void
    var showAlertDeactivationNotification: @Sendable () async -> Void
    var showPingNotification: @Sendable (String) async -> Void
    var showContactAddedNotification: @Sendable (String) async -> Void
    var showContactRemovedNotification: @Sendable (String) async -> Void
    var showContactRoleToggleNotification: @Sendable (String, Bool, Bool, Bool, Bool) async -> Void
    var showQRCodeCopiedNotification: @Sendable () async -> Void
    var showPhoneNumberChangedNotification: @Sendable () async -> Void
    var showAllPingsClearedNotification: @Sendable () async -> Void
    var loadNotifications: @Sendable () async -> [NotificationItem]
    var markAsRead: @Sendable (String) async -> Void
    var clearAll: @Sendable () async -> Void
    
    // Core notification functionality (previously in UserNotificationClient)
    var scheduleLocalNotification: @Sendable (String, String, Notification, Bool) async -> Void
    var requestPermission: @Sendable () async -> Bool
    var removeAllDeliveredNotifications: @Sendable () async -> Void
}

extension NotificationClient: DependencyKey {
    static let liveValue: NotificationClient = {
        @Dependency(\.analytics) var analytics
        
        return NotificationClient(
            showQRCodeResetNotification: {
                await scheduleLocalNotificationImplementation(
                    title: "QR Code Reset",
                    body: "Your QR code has been reset. Previous QR codes are no longer valid.",
                    type: .qrCodeNotification,
                    trackInCenter: false
                )
            },
            showNotificationSettingsUpdatedNotification: {
                await scheduleLocalNotificationImplementation(
                    title: "Notification Settings Updated",
                    body: "Your notification settings have been successfully updated.",
                    type: .system,
                    trackInCenter: false
                )
            },
            showCheckInNotification: {
                await scheduleLocalNotificationImplementation(
                    title: "Check-in Completed",
                    body: "You have successfully checked in.",
                    type: .checkInReminder,
                    trackInCenter: true
                )
            },
            showAlertActivationNotification: {
                await scheduleLocalNotificationImplementation(
                    title: "Alert Activated",
                    body: "You have activated an alert. Your responders have been notified.",
                    type: .manualAlert,
                    trackInCenter: true
                )
            },
            showAlertDeactivationNotification: {
                await scheduleLocalNotificationImplementation(
                    title: "Alert Deactivated",
                    body: "You have deactivated your alert.",
                    type: .manualAlert,
                    trackInCenter: true
                )
            },
            showPingNotification: { contactName in
                await scheduleLocalNotificationImplementation(
                    title: "Ping Sent",
                    body: "You pinged \(contactName).",
                    type: .pingNotification,
                    trackInCenter: true
                )
            },
            showContactAddedNotification: { contactName in
                await scheduleLocalNotificationImplementation(
                    title: "Contact Added",
                    body: "You have added \(contactName) to your contacts.",
                    type: .contactAdded,
                    trackInCenter: true
                )
            },
            showContactRemovedNotification: { contactName in
                await scheduleLocalNotificationImplementation(
                    title: "Contact Removed",
                    body: "You have removed \(contactName) from your contacts.",
                    type: .contactRemoved,
                    trackInCenter: true
                )
            },
            showContactRoleToggleNotification: { contactName, isResponder, isDependent, wasResponder, wasDependent in
                let responderChanged = isResponder != wasResponder
                let dependentChanged = isDependent != wasDependent
                
                var title = "Contact Role Updated"
                var body = ""
                
                if responderChanged && dependentChanged {
                    if isResponder && isDependent {
                        body = "\(contactName) is now both a responder and a dependent."
                    } else if !isResponder && !isDependent {
                        body = "\(contactName) is no longer a responder or a dependent."
                    } else {
                        body = "\(contactName)'s roles have been updated."
                    }
                } else if responderChanged {
                    if isResponder {
                        title = "Responder Added"
                        body = "\(contactName) can now respond to your alerts."
                    } else {
                        title = "Responder Removed"
                        body = "\(contactName) will no longer respond to your alerts."
                    }
                } else if dependentChanged {
                    if isDependent {
                        title = "Dependent Added"
                        body = "You can now check on \(contactName)."
                    } else {
                        title = "Dependent Removed"
                        body = "You will no longer check on \(contactName)."
                    }
                } else {
                    body = "\(contactName)'s roles remain unchanged."
                }
                
                await scheduleLocalNotificationImplementation(
                    title: title,
                    body: body,
                    type: .contactRoleChanged,
                    trackInCenter: true
                )
            },
            showQRCodeCopiedNotification: {
                await scheduleLocalNotificationImplementation(
                    title: "QR Code ID Copied",
                    body: "Your QR code ID has been copied to the clipboard.",
                    type: .qrCodeNotification,
                    trackInCenter: false
                )
            },
            showPhoneNumberChangedNotification: {
                await scheduleLocalNotificationImplementation(
                    title: "Phone Number Updated",
                    body: "Your phone number has been successfully updated.",
                    type: .system,
                    trackInCenter: false
                )
            },
            showAllPingsClearedNotification: {
                await scheduleLocalNotificationImplementation(
                    title: "All Pings Cleared",
                    body: "You have cleared all pending pings.",
                    type: .pingNotification,
                    trackInCenter: true
                )
            },
            loadNotifications: {
                // Mock notifications for now - will be replaced with actual implementation
                return [
                    NotificationItem(
                        type: .checkIn,
                        title: "Check-in Reminder",
                        message: "Time for your check-in!",
                        isRead: false,
                        timestamp: Date().addingTimeInterval(-3600)
                    ),
                    NotificationItem(
                        type: .alert,
                        title: "Alert",
                        message: "Contact needs assistance",
                        isRead: true,
                        timestamp: Date().addingTimeInterval(-7200)
                    )
                ]
            },
            markAsRead: { _ in
                // Mock implementation
            },
            clearAll: {
                // Mock implementation
            },
            
            // Core notification functionality
            scheduleLocalNotification: { title, body, type, trackInCenter in
                await scheduleLocalNotificationImplementation(
                    title: title,
                    body: body,
                    type: type,
                    trackInCenter: trackInCenter
                )
            },
            requestPermission: {
                return await withCheckedContinuation { continuation in
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                        continuation.resume(returning: granted)
                    }
                }
            },
            removeAllDeliveredNotifications: {
                UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            }
        )
    }()
    
    static let testValue = NotificationClient(
        showQRCodeResetNotification: {},
        showNotificationSettingsUpdatedNotification: {},
        showCheckInNotification: {},
        showAlertActivationNotification: {},
        showAlertDeactivationNotification: {},
        showPingNotification: { _ in },
        showContactAddedNotification: { _ in },
        showContactRemovedNotification: { _ in },
        showContactRoleToggleNotification: { _, _, _, _, _ in },
        showQRCodeCopiedNotification: {},
        showPhoneNumberChangedNotification: {},
        showAllPingsClearedNotification: {},
        loadNotifications: { [] },
        markAsRead: { _ in },
        clearAll: {},
        scheduleLocalNotification: { _, _, _, _ in },
        requestPermission: { false },
        removeAllDeliveredNotifications: {}
    )
}

extension DependencyValues {
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}

// MARK: - Private Implementation

@Sendable private func scheduleLocalNotificationImplementation(
    title: String,
    body: String,
    type: NotificationType,
    trackInCenter: Bool
) async {
    @Dependency(\.notificationRepository) var notificationRepository
    
    // Create and schedule the system notification
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    
    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil // Immediate delivery
    )
    
    do {
        try await UNUserNotificationCenter.current().add(request)
    } catch {
        // Handle error silently for now
    }
    
    // Track in notification center if requested
    if trackInCenter {
        let item = NotificationItem(
            type: type,
            title: title,
            message: body,
            isRead: false,
            timestamp: Date()
        )
        await notificationRepository.addNotification(item)
    }
}