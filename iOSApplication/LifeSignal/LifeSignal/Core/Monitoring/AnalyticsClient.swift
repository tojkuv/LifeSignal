import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation

// MARK: - Analytics Events

enum AnalyticsEvent: Equatable {
    // Authentication events
    case userSignedIn(method: String)
    case userSignedOut(userId: String)
    case verificationCodeSent(phoneNumber: String)
    case userAccountDeleted(userId: String)

    // User profile events
    case userProfileUpdated(userId: String)
    case avatarUploaded(userId: String, size: Int)

    // Contact events
    case contactAdded(phoneNumber: String)
    case contactUpdated(contactId: UUID, changeDescription: String)
    case contactResponderStatusChanged(contactId: UUID, isResponder: Bool)
    case contactDependentStatusChanged(contactId: UUID, isDependent: Bool)
    case contactPingStatusChanged(contactId: UUID, hasIncoming: Bool, hasOutgoing: Bool)
    case contactManualAlertToggled(contactId: UUID, isActive: Bool)
    case contactCheckInRecorded(contactId: UUID, timestamp: Date)
    case contactIntervalChanged(contactId: UUID, newInterval: TimeInterval)
    case contactsLoaded(count: Int)

    // Feature usage events
    case featureUsed(feature: String, context: [String: String])

    // Notification events
    case notificationSent(type: String, title: String, contactId: UUID?)
    case notificationOpened(type: String, notificationId: UUID)
    case notificationDismissed(type: String, notificationId: UUID)

    // Check-in events
    case checkInCompleted(userId: String, method: String)
    case checkInMissed(userId: String, interval: TimeInterval)
    case checkInReminderShown(userId: String, minutesBefore: Int)

    // Emergency events
    case emergencyAlertTriggered(userId: String, location: String?)
    case emergencyAlertCancelled(userId: String, duration: TimeInterval)
    case sosActivated(userId: String, contactCount: Int)

    // App lifecycle events
    case appLaunched
    case appBackgrounded
    case appForegrounded

    // Error events
    case errorOccurred(domain: String, code: String, description: String)
    case networkError(endpoint: String, statusCode: Int?, error: String)

    // Performance events
    case screenViewed(screen: String, loadTime: TimeInterval?)
    case actionCompleted(action: String, duration: TimeInterval)

    // Onboarding events
    case onboardingStarted
    case onboardingCompleted(step: String)
    case onboardingSkipped(step: String)

    // Settings events
    case settingsChanged(setting: String, oldValue: String, newValue: String)
    case permissionRequested(permission: String)
    case permissionGranted(permission: String)
    case permissionDenied(permission: String)
}

// MARK: - Analytics Client (MVP Mock Implementation)

@DependencyClient
struct AnalyticsClient {
    var track: @Sendable (AnalyticsEvent) async -> Void = { _ in }
    var setUserProperties: @Sendable ([String: String]) async -> Void = { _ in }
    var setUserId: @Sendable (String) async -> Void = { _ in }
    var clearUserData: @Sendable () async -> Void = { }
    var incrementCounter: @Sendable (String) async -> Void = { _ in }
    var recordTiming: @Sendable (String, TimeInterval) async -> Void = { _, _ in }
    var setCustomDimension: @Sendable (String, String) async -> Void = { _, _ in }
}

extension AnalyticsClient: DependencyKey {
    static let liveValue = AnalyticsClient.mockValue
    static let testValue = AnalyticsClient.mockValue
    
    static let mockValue = AnalyticsClient(
        track: { event in
            // Mock implementation for MVP - simple console logging
            print("📊 [MOCK] Analytics: \(event.eventName)")
            let params = event.parameters
            if !params.isEmpty {
                print("   Parameters: \(params)")
            }
        },

        setUserProperties: { properties in
            print("👤 [MOCK] User Properties: \(properties)")
        },

        setUserId: { userId in
            print("🆔 [MOCK] User ID: \(userId)")
        },

        clearUserData: {
            print("🧹 [MOCK] Analytics: Cleared user data")
        },

        incrementCounter: { counterName in
            print("🔢 [MOCK] Analytics: Incremented \(counterName)")
        },

        recordTiming: { eventName, duration in
            print("⏱️ [MOCK] Analytics: \(eventName) took \(String(format: "%.2f", duration))s")
        },

        setCustomDimension: { key, value in
            print("🏷️ [MOCK] Custom Dimension: \(key) = \(value)")
        }
    )
}

extension DependencyValues {
    var analytics: AnalyticsClient {
        get { self[AnalyticsClient.self] }
        set { self[AnalyticsClient.self] = newValue }
    }
}

// MARK: - Event Property Extensions

extension AnalyticsEvent {
    /// Get the event name for tracking purposes
    var eventName: String {
        switch self {
        case .userSignedIn: return "user_signed_in"
        case .userSignedOut: return "user_signed_out"
        case .verificationCodeSent: return "verification_code_sent"
        case .userAccountDeleted: return "user_account_deleted"
        case .userProfileUpdated: return "user_profile_updated"
        case .avatarUploaded: return "avatar_uploaded"
        case .contactAdded: return "contact_added"
        case .contactUpdated: return "contact_updated"
        case .contactResponderStatusChanged: return "contact_responder_status_changed"
        case .contactDependentStatusChanged: return "contact_dependent_status_changed"
        case .contactPingStatusChanged: return "contact_ping_status_changed"
        case .contactManualAlertToggled: return "contact_manual_alert_toggled"
        case .contactCheckInRecorded: return "contact_check_in_recorded"
        case .contactIntervalChanged: return "contact_interval_changed"
        case .contactsLoaded: return "contacts_loaded"
        case .featureUsed: return "feature_used"
        case .notificationSent: return "notification_sent"
        case .notificationOpened: return "notification_opened"
        case .notificationDismissed: return "notification_dismissed"
        case .checkInCompleted: return "check_in_completed"
        case .checkInMissed: return "check_in_missed"
        case .checkInReminderShown: return "check_in_reminder_shown"
        case .emergencyAlertTriggered: return "emergency_alert_triggered"
        case .emergencyAlertCancelled: return "emergency_alert_cancelled"
        case .sosActivated: return "sos_activated"
        case .appLaunched: return "app_launched"
        case .appBackgrounded: return "app_backgrounded"
        case .appForegrounded: return "app_foregrounded"
        case .errorOccurred: return "error_occurred"
        case .networkError: return "network_error"
        case .screenViewed: return "screen_viewed"
        case .actionCompleted: return "action_completed"
        case .onboardingStarted: return "onboarding_started"
        case .onboardingCompleted: return "onboarding_completed"
        case .onboardingSkipped: return "onboarding_skipped"
        case .settingsChanged: return "settings_changed"
        case .permissionRequested: return "permission_requested"
        case .permissionGranted: return "permission_granted"
        case .permissionDenied: return "permission_denied"
        }
    }

    /// Get the event parameters for tracking - all values converted to strings for consistency
    var parameters: [String: String] {
        switch self {
        case .userSignedIn(let method):
            return ["method": method]
        case .userSignedOut(let userId):
            return ["user_id": userId]
        case .verificationCodeSent(let phoneNumber):
            return ["phone_number": phoneNumber]
        case .userAccountDeleted(let userId):
            return ["user_id": userId]
        case .userProfileUpdated(let userId):
            return ["user_id": userId]
        case .avatarUploaded(let userId, let size):
            return ["user_id": userId, "size": String(size)]
        case .contactAdded(let phoneNumber):
            return ["phone_number": phoneNumber]
        case .contactUpdated(let contactId, let changeDescription):
            return ["contact_id": contactId.uuidString, "change_description": changeDescription]
        case .contactResponderStatusChanged(let contactId, let isResponder):
            return ["contact_id": contactId.uuidString, "is_responder": String(isResponder)]
        case .contactDependentStatusChanged(let contactId, let isDependent):
            return ["contact_id": contactId.uuidString, "is_dependent": String(isDependent)]
        case .contactPingStatusChanged(let contactId, let hasIncoming, let hasOutgoing):
            return [
                "contact_id": contactId.uuidString,
                "has_incoming": String(hasIncoming),
                "has_outgoing": String(hasOutgoing)
            ]
        case .contactManualAlertToggled(let contactId, let isActive):
            return ["contact_id": contactId.uuidString, "is_active": String(isActive)]
        case .contactCheckInRecorded(let contactId, let timestamp):
            return [
                "contact_id": contactId.uuidString,
                "timestamp": String(timestamp.timeIntervalSince1970)
            ]
        case .contactIntervalChanged(let contactId, let newInterval):
            return ["contact_id": contactId.uuidString, "new_interval": String(newInterval)]
        case .contactsLoaded(let count):
            return ["count": String(count)]
        case .featureUsed(let feature, let context):
            var params = ["feature": feature]
            params.merge(context) { _, new in new }
            return params
        case .notificationSent(let type, let title, let contactId):
            var params = ["type": type, "title": title]
            if let contactId = contactId {
                params["contact_id"] = contactId.uuidString
            }
            return params
        case .notificationOpened(let type, let notificationId):
            return ["type": type, "notification_id": notificationId.uuidString]
        case .notificationDismissed(let type, let notificationId):
            return ["type": type, "notification_id": notificationId.uuidString]
        case .checkInCompleted(let userId, let method):
            return ["user_id": userId, "method": method]
        case .checkInMissed(let userId, let interval):
            return ["user_id": userId, "interval": String(interval)]
        case .checkInReminderShown(let userId, let minutesBefore):
            return ["user_id": userId, "minutes_before": String(minutesBefore)]
        case .emergencyAlertTriggered(let userId, let location):
            var params = ["user_id": userId]
            if let location = location {
                params["location"] = location
            }
            return params
        case .emergencyAlertCancelled(let userId, let duration):
            return ["user_id": userId, "duration": String(duration)]
        case .sosActivated(let userId, let contactCount):
            return ["user_id": userId, "contact_count": String(contactCount)]
        case .appLaunched, .appBackgrounded, .appForegrounded:
            return [:]
        case .errorOccurred(let domain, let code, let description):
            return ["domain": domain, "code": code, "description": description]
        case .networkError(let endpoint, let statusCode, let error):
            var params = ["endpoint": endpoint, "error": error]
            if let statusCode = statusCode {
                params["status_code"] = String(statusCode)
            }
            return params
        case .screenViewed(let screen, let loadTime):
            var params = ["screen": screen]
            if let loadTime = loadTime {
                params["load_time"] = String(loadTime)
            }
            return params
        case .actionCompleted(let action, let duration):
            return ["action": action, "duration": String(duration)]
        case .onboardingStarted:
            return [:]
        case .onboardingCompleted(let step):
            return ["step": step]
        case .onboardingSkipped(let step):
            return ["step": step]
        case .settingsChanged(let setting, let oldValue, let newValue):
            return ["setting": setting, "old_value": oldValue, "new_value": newValue]
        case .permissionRequested(let permission):
            return ["permission": permission]
        case .permissionGranted(let permission):
            return ["permission": permission]
        case .permissionDenied(let permission):
            return ["permission": permission]
        }
    }
}

// MARK: - Convenience Extensions

extension AnalyticsClient {
    /// Track a screen view with optional load time
    func trackScreenView(_ screenName: String, loadTime: TimeInterval? = nil) async {
        await track(.screenViewed(screen: screenName, loadTime: loadTime))
    }

    /// Track an error with domain, code, and description
    func trackError(domain: String, code: String, description: String) async {
        await track(.errorOccurred(domain: domain, code: code, description: description))
    }

    /// Track a network error
    func trackNetworkError(endpoint: String, statusCode: Int? = nil, error: String) async {
        await track(.networkError(endpoint: endpoint, statusCode: statusCode, error: error))
    }

    /// Track a timed action
    func trackTimedAction<T>(_ actionName: String, operation: () async throws -> T) async rethrows -> T {
        let startTime = Date()
        let result = try await operation()
        let duration = Date().timeIntervalSince(startTime)
        await track(.actionCompleted(action: actionName, duration: duration))
        return result
    }
}