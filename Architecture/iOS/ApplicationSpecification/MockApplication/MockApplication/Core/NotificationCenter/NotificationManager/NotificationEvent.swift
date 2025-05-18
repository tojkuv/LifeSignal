import Foundation
import SwiftUI
import Combine

/// A notification event
struct NotificationEvent: Identifiable, Equatable {
    /// The notification ID
    var id: String

    /// The notification timestamp
    var timestamp: Date

    /// The notification type
    var type: NotificationType

    /// The notification title
    var title: String

    /// The notification body
    var body: String
}