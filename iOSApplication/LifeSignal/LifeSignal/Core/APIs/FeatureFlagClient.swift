import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation

enum FeatureFlag: String, CaseIterable {
    case realTimeContactUpdates = "real_time_contact_updates"
    case optimisticUpdates = "optimistic_updates"
    case advancedSearch = "advanced_search"
}

@DependencyClient
struct FeatureFlagClient {
    var isEnabled: @Sendable (FeatureFlag) async -> Bool = { _ in false }
    var getVariant: @Sendable (FeatureFlag, Any.Type) async -> Any? = { _, _ in nil }
    var track: @Sendable (FeatureFlag, String) async -> Void = { _, _ in }
}

extension FeatureFlagClient: DependencyKey {
    static let liveValue = FeatureFlagClient(
        isEnabled: { flag in
            // Mock implementation - in real app would check remote config
            switch flag {
            case .realTimeContactUpdates: return true
            case .optimisticUpdates: return true
            case .advancedSearch: return false
            }
        },
        getVariant: { flag, type in
            nil // Mock implementation
        },
        track: { flag, event in
            print("🏁 Feature Flag \(flag.rawValue): \(event)")
        }
    )
    
    static let testValue = FeatureFlagClient(
        isEnabled: { _ in false },
        getVariant: { _, _ in nil },
        track: { _, _ in }
    )
}

extension DependencyValues {
    var featureFlags: FeatureFlagClient {
        get { self[FeatureFlagClient.self] }
        set { self[FeatureFlagClient.self] = newValue }
    }
}