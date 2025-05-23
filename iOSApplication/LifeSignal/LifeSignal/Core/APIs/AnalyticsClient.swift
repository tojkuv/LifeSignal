import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation

enum AnalyticsEvent: Equatable {
    case userSignedIn(method: String)
    case verificationCodeSent(phoneNumber: String)
    case contactAdded(phoneNumber: String)
    case contactStatusChanged(from: Contact.Status, to: Contact.Status)
    case featureUsed(feature: String, context: [String: String])
    case notificationSent(type: Notification, title: String)
}

@DependencyClient
struct AnalyticsClient {
    var track: @Sendable (AnalyticsEvent) async -> Void
    var setUserProperties: @Sendable ([String: String]) async -> Void
}

extension AnalyticsClient: DependencyKey {
    static let liveValue = AnalyticsClient(
        track: { event in
            print("📊 Analytics: \(event)")
        },
        setUserProperties: { properties in
            print("👤 User Properties: \(properties)")
        }
    )
    
    static let testValue = AnalyticsClient()
}

extension DependencyValues {
    var analytics: AnalyticsClient {
        get { self[AnalyticsClient.self] }
        set { self[AnalyticsClient.self] = newValue }
    }
}