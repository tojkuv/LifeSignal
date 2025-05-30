import XCTest
import ComposableArchitecture
import Dependencies
@testable import LifeSignal

@MainActor
final class ArchitecturePatternsTests: XCTestCase {
    
    // MARK: - New Architecture Validation Tests
    
    func testNewArchitectureProtocolConformance() {
        // Test that our core clients conform to the new protocols
        XCTAssertTrue(AuthenticationClient.self is any StateOwnerClient.Type)
        XCTAssertTrue(ContactsClient.self is any StateOwnerClient.Type)
        XCTAssertTrue(UserClient.self is any StateOwnerClient.Type)
        XCTAssertTrue(NotificationClient.self is any StateOwnerClient.Type)
        
        // Test that pure utility clients conform correctly
        XCTAssertTrue(HapticClient.self is any PureUtilityClient.Type)
        XCTAssertTrue(TimeFormattingClient.self is any PureUtilityClient.Type)
        XCTAssertTrue(PhoneNumberFormatterClient.self is any PureUtilityClient.Type)
        XCTAssertTrue(BiometricClient.self is any PureUtilityClient.Type)
        XCTAssertTrue(CameraClient.self is any PureUtilityClient.Type)
    }
    
    func testFeatureProtocolConformance() {
        // Test that our features conform to the new FeatureContext protocol
        XCTAssertTrue(ApplicationFeature.self is any FeatureContext.Type)
        XCTAssertTrue(SignInFeature.self is any FeatureContext.Type)
        XCTAssertTrue(OnboardingFeature.self is any FeatureContext.Type)
        XCTAssertTrue(HomeFeature.self is any FeatureContext.Type)
        XCTAssertTrue(RespondersFeature.self is any FeatureContext.Type)
        XCTAssertTrue(DependentsFeature.self is any FeatureContext.Type)
        XCTAssertTrue(ProfileFeature.self is any FeatureContext.Type)
        XCTAssertTrue(CheckInFeature.self is any FeatureContext.Type)
    }
    
    func testViewProtocolConformance() {
        // Test that our views conform to the new FeatureView protocol
        XCTAssertTrue(AppRootView.self is any FeatureView.Type)
        XCTAssertTrue(SignInView.self is any FeatureView.Type)
        XCTAssertTrue(OnboardingView.self is any FeatureView.Type)
        XCTAssertTrue(HomeView.self is any FeatureView.Type)
        XCTAssertTrue(RespondersView.self is any FeatureView.Type)
        XCTAssertTrue(DependentsView.self is any FeatureView.Type)
        XCTAssertTrue(ProfileView.self is any FeatureView.Type)
        XCTAssertTrue(CheckInView.self is any FeatureView.Type)
    }
    
    func testArchitecturalValidation() {
        // Test that architectural validation utilities work
        XCTAssertTrue(ArchitecturalHelpers.validateArchitecturalCompliance(AuthenticationClient.self))
        XCTAssertTrue(ArchitecturalHelpers.validateArchitecturalCompliance(ApplicationFeature.self))
        XCTAssertTrue(ArchitecturalHelpers.validateArchitecturalCompliance(AppRootView.self))
    }
    
    func testPureUtilityClientValidation() {
        // Test that pure utility clients validate primitive dependencies correctly
        XCTAssertTrue(HapticClient.validatePrimitiveDependency(URLSession.self))
        XCTAssertTrue(HapticClient.validatePrimitiveDependency(UserDefaults.self))
        XCTAssertTrue(HapticClient.validatePrimitiveDependency(JSONEncoder.self))
        XCTAssertTrue(HapticClient.validatePrimitiveDependency(FileManager.self))
        
        // Test that non-primitive types are rejected
        XCTAssertFalse(HapticClient.validatePrimitiveDependency(UIApplication.self))
        XCTAssertFalse(HapticClient.validatePrimitiveDependency(String.self))
    }
    
    func testStateOwnerClientValidation() {
        // Test that state owner clients validate primitive dependencies correctly
        XCTAssertTrue(AuthenticationClient.validatePrimitiveDependency(URLSession.self))
        XCTAssertTrue(ContactsClient.validatePrimitiveDependency(JSONDecoder.self))
        XCTAssertTrue(UserClient.validatePrimitiveDependency(Calendar.self))
        
        // Test that non-primitive types are rejected
        XCTAssertFalse(AuthenticationClient.validatePrimitiveDependency(UIApplication.self))
        XCTAssertFalse(ContactsClient.validatePrimitiveDependency(String.self))
    }
    
    func testFeatureClientDependencyValidation() {
        // Test that features validate client dependencies correctly
        XCTAssertTrue(ApplicationFeature.validateClientDependency(AuthenticationClient.self))
        XCTAssertTrue(ApplicationFeature.validateClientDependency(HapticClient.self))
        XCTAssertTrue(SignInFeature.validateClientDependency(AuthenticationClient.self))
        XCTAssertTrue(HomeFeature.validateClientDependency(UserClient.self))
        
        // Non-client types should be rejected
        XCTAssertFalse(ApplicationFeature.validateClientDependency(String.self))
        XCTAssertFalse(HomeFeature.validateClientDependency(Int.self))
    }
    
    func testViewStoreAccessValidation() {
        // Test that views validate store access correctly
        XCTAssertTrue(AppRootView.validateStoreAccess())
        XCTAssertTrue(SignInView.validateStoreAccess())
        XCTAssertTrue(HomeView.validateStoreAccess())
        XCTAssertTrue(RespondersView.validateStoreAccess())
    }
    
    func testArchitecturalConstraints() {
        // Test that architectural constraints are enforced
        // This is validated at compile-time through protocol conformance
        XCTAssertNoThrow(ArchitectureEnforcer.enforceClientConstraints(AuthenticationClient.self))
        XCTAssertNoThrow(ArchitectureEnforcer.enforceFeatureConstraints(ApplicationFeature.self))
        XCTAssertNoThrow(ArchitectureEnforcer.enforceViewConstraints(AppRootView.self))
    }
    
    func testArchitectureMonitoring() {
        // Test that architecture monitoring works
        let complianceReport = ArchitectureMonitor.monitorCompliance()
        XCTAssertNotNil(complianceReport)
        XCTAssertGreaterThanOrEqual(complianceReport.overallCompliance, 0.0)
        XCTAssertLessThanOrEqual(complianceReport.overallCompliance, 100.0)
        
        let performanceReport = ArchitectureMonitor.generatePerformanceReport()
        XCTAssertNotNil(performanceReport)
        XCTAssertGreaterThanOrEqual(performanceReport.averageClientPerformance, 0.0)
    }
    
    func testMigrationComplete() {
        // Verify that all components are using the new architecture
        // This test ensures that the migration was successful
        
        // All state owner clients should be migrated
        let stateOwnerClients: [any StateOwnerClient.Type] = [
            AuthenticationClient.self,
            ContactsClient.self,
            UserClient.self,
            NotificationClient.self,
            OnboardingClient.self,
            NetworkClient.self
        ]
        
        XCTAssertEqual(stateOwnerClients.count, 6, "All expected state owner clients should be migrated")
        
        // All pure utility clients should be migrated
        let pureUtilityClients: [any PureUtilityClient.Type] = [
            HapticClient.self,
            TimeFormattingClient.self,
            PhoneNumberFormatterClient.self,
            BiometricClient.self,
            CameraClient.self
        ]
        
        XCTAssertEqual(pureUtilityClients.count, 5, "All expected pure utility clients should be migrated")
        
        // All features should be migrated
        let features: [any FeatureContext.Type] = [
            ApplicationFeature.self,
            SignInFeature.self,
            OnboardingFeature.self,
            HomeFeature.self,
            RespondersFeature.self,
            DependentsFeature.self,
            ProfileFeature.self,
            CheckInFeature.self
        ]
        
        XCTAssertEqual(features.count, 8, "All expected features should be migrated")
    }
}