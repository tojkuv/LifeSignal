import Foundation
import ComposableArchitecture
import Dependencies
import DependenciesMacros

// MARK: - Test PureUtilityClient

/// Test implementation of a pure utility client with no state dependencies
/// This should compile successfully as it follows PureUtilityClient architectural rules
@DependencyClient
struct TestPureUtilityClient: PureUtilityClient, Sendable {
    
    /// Pure utility function - formats timestamp
    var formatTimestamp: @Sendable (Date) -> String = { date in
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Pure utility function - validates email format
    var validateEmail: @Sendable (String) -> Bool = { email in
        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailPattern)
        return emailPredicate.evaluate(with: email)
    }
    
    /// Pure utility function - generates UUID string
    var generateID: @Sendable () -> String = {
        UUID().uuidString
    }
    
    /// Pure utility function - network reachability check
    var isNetworkReachable: @Sendable () async -> Bool = {
        // Mock implementation - in real app would check network status
        try? await Task.sleep(for: .milliseconds(100))
        return true
    }
}

// MARK: - Dependency Registration

extension TestPureUtilityClient: DependencyKey {
    static let liveValue = TestPureUtilityClient()
    static let testValue = TestPureUtilityClient(
        formatTimestamp: { _ in "Test Date" },
        validateEmail: { _ in true },
        generateID: { "test-id" },
        isNetworkReachable: { true }
    )
}

extension DependencyValues {
    var testPureUtilityClient: TestPureUtilityClient {
        get { self[TestPureUtilityClient.self] }
        set { self[TestPureUtilityClient.self] = newValue }
    }
}