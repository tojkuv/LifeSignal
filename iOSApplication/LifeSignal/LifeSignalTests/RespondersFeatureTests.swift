import ComposableArchitecture
import XCTest
@testable import LifeSignal

@MainActor
final class RespondersFeatureTests: XCTestCase {
    func testBasicInitialization() async {
        let store = TestStore(initialState: RespondersFeature.State()) {
            RespondersFeature()
        }
        
        // Test that the feature initializes without errors
        XCTAssertEqual(store.state.isLoading, false)
        XCTAssertNil(store.state.errorMessage)
    }
    
    func testRefreshResponders() async {
        @Shared(.currentUser) var currentUser = User.mock
        
        let store = TestStore(initialState: RespondersFeature.State()) {
            RespondersFeature()
        } withDependencies: {
            $0.analytics = .noop
        }
        
        await store.send(.refreshResponders) {
            $0.isLoading = true
        }
        
        await store.receive(.binding(.set(\.$isLoading, false))) {
            $0.isLoading = false
        }
    }
}