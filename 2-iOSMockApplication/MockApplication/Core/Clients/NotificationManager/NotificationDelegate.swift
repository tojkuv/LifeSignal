import Foundation
import UserNotifications

/// A delegate for handling user notifications
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    
    /// Shared instance
    static let shared = NotificationDelegate()
    
    /// Private initializer to enforce singleton pattern
    private override init() {
        super.init()
    }
    
    /// Called when a notification is about to be presented while the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Always show the notification when the app is in the foreground
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge, .list])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
        
        // Log for debugging
        print("Notification will present: \(notification.request.content.title)")
    }
    
    /// Called when the user interacts with a notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle the notification response
        let userInfo = response.notification.request.content.userInfo
        
        // Log for debugging
        print("Notification response received: \(response.notification.request.content.title)")
        print("Notification userInfo: \(userInfo)")
        
        // Post a notification to update the notification center
        NotificationCenter.default.post(
            name: NSNotification.Name("NotificationInteraction"),
            object: nil,
            userInfo: [
                "title": response.notification.request.content.title,
                "body": response.notification.request.content.body,
                "userInfo": userInfo
            ]
        )
        
        // Complete the handling
        completionHandler()
    }
}
