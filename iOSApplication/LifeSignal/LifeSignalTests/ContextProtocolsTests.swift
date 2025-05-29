import XCTest
import ComposableArchitecture
import Dependencies
@testable import LifeSignal

@MainActor
final class ContextProtocolsTests: XCTestCase {
    
    // MARK: - Test Setup
    
    override func setUp() {
        super.setUp()
        // Clear mutation logs before each test
        TestClient.mutationLog.withValue { $0.removeAll() }
    }
    
    // MARK: - State Ownership Tests
    
    func testClientStateOwnership() throws {
        // Test that clients properly declare their state ownership
        XCTAssertTrue(AuthenticationClient.stateKey is any SharedReaderKey<AuthClientState>)
        XCTAssertTrue(ContactsClient.stateKey is any SharedReaderKey<ContactsClientState>)
        XCTAssertTrue(UserClient.stateKey is any SharedReaderKey<UserClientState>)
        XCTAssertTrue(NotificationClient.stateKey is any SharedReaderKey<NotificationClientState>)
    }
    
    func testClientContextValidation() throws {
        // Test that ContextValidator can validate client state ownership
        XCTAssertNoThrow(try ContextValidator.validateClientStateOwnership(AuthenticationClient.self))
        XCTAssertNoThrow(try ContextValidator.validateClientStateOwnership(ContactsClient.self))
        XCTAssertNoThrow(try ContextValidator.validateClientStateOwnership(UserClient.self))
    }
    
    // MARK: - Dependency Graph Tests
    
    func testClientDependencyGraphs() {
        // Test AuthenticationClient dependency graph
        XCTAssertTrue(AuthenticationClient.allowedPrimitives.contains { $0 == URLSession.self })
        XCTAssertTrue(AuthenticationClient.allowedPrimitives.contains { $0 == UserDefaults.self })
        XCTAssertTrue(AuthenticationClient.deniedClients.contains { $0 == ContactsClient.self })
        XCTAssertTrue(AuthenticationClient.deniedClients.contains { $0 == UserClient.self })
        
        // Test ContactsClient dependency graph
        XCTAssertTrue(ContactsClient.allowedPrimitives.contains { $0 == URLSession.self })
        XCTAssertTrue(ContactsClient.deniedClients.contains { $0 == AuthenticationClient.self })
        
        // Test UserClient dependency graph
        XCTAssertTrue(UserClient.allowedPrimitives.contains { $0 == URLSession.self })
        XCTAssertTrue(UserClient.deniedClients.contains { $0 == AuthenticationClient.self })
        XCTAssertTrue(UserClient.deniedClients.contains { $0 == ContactsClient.self })
    }
    
    func testDependencyValidation() {
        // Test primitive dependency validation
        XCTAssertTrue(AuthenticationClient.validatePrimitiveAccess(URLSession.self))
        XCTAssertTrue(AuthenticationClient.validatePrimitiveAccess(UserDefaults.self))
        XCTAssertFalse(AuthenticationClient.validatePrimitiveAccess(UIApplication.self)) // Not in allowlist
        
        // Test client dependency validation
        XCTAssertFalse(AuthenticationClient.validateClientAccess(ContactsClient.self)) // Explicitly denied
        XCTAssertFalse(AuthenticationClient.validateClientAccess(UserClient.self)) // Explicitly denied
    }
    
    // MARK: - State Mutation Tracking Tests
    
    func testStateMutationTracking() async {
        let testClient = TestClient()
        
        // Create a shared state for testing
        @Shared(.testInternalState) var testState
        
        // Perform an audited mutation
        $testState.auditedMutation(context: TestClient.self, operation: "testMutation") { state in
            state.value = "updated"
        }
        
        // Verify mutation was logged locally
        let localMutations = TestClient.mutationLog.value
        XCTAssertEqual(localMutations.count, 1)
        XCTAssertEqual(localMutations.first?.operation, "testMutation")
        XCTAssertEqual(localMutations.first?.mutator, "TestClient")
        
        // Verify mutation was logged globally
        let globalMutations = await StateMutationTracker.shared.getMutations(for: "TestClientState")
        XCTAssertEqual(globalMutations.count, 1)
        XCTAssertEqual(globalMutations.first?.operation, "testMutation")
    }
    
    func testContextAwareMutation() {
        @Shared(.testInternalState) var testState
        
        // Test context-aware mutation with logging
        $testState.withMutation(context: TestClient.self, operation: "contextTest") { state in
            state.value = "context-aware"
        }
        
        // Verify state was updated
        XCTAssertEqual(testState.value, "context-aware")
    }
    
    func testContextAwareReading() {
        @Shared(.testInternalState) var testState
        testState.value = "test-read"
        
        var readValue: String = ""
        $testState.withRead(context: TestFeature.self, operation: "testRead") { state in
            readValue = state.value
        }
        
        XCTAssertEqual(readValue, "test-read")
    }
    
    // MARK: - Feature Context Tests
    
    func testFeatureContextConformance() {
        // Test that features properly implement ReducerContext
        XCTAssertTrue(ApplicationFeature.self is any MultiStateReader.Type)
        XCTAssertTrue(SignInFeature.self is any ReducerContext.Type)
        
        // Test multi-state reader configuration
        let additionalStates = ApplicationFeature.additionalClientTypes
        XCTAssertTrue(additionalStates.contains("ContactsClient"))
        XCTAssertTrue(additionalStates.contains("UserClient"))
        XCTAssertTrue(additionalStates.contains("OnboardingClient"))
        XCTAssertTrue(additionalStates.contains("NetworkClient"))
    }
    
    func testFeatureStateAccess() throws {
        // Test that features can validate their state access
        XCTAssertNoThrow(try ContextValidator.validateFeatureStateAccess(
            ApplicationFeature.self,
            stateOwner: AuthenticationClient.self
        ))
        
        XCTAssertNoThrow(try ContextValidator.validateFeatureStateAccess(
            SignInFeature.self,
            stateOwner: AuthenticationClient.self
        ))
    }
    
    func testMultiStateReaderAccess() {
        // Test that ApplicationFeature can read from multiple clients
        XCTAssertTrue(ApplicationFeature.canReadFrom(clientType: "AuthenticationClient")) // Primary
        XCTAssertTrue(ApplicationFeature.canReadFrom(clientType: "ContactsClient")) // Additional
        XCTAssertTrue(ApplicationFeature.canReadFrom(clientType: "UserClient")) // Additional
        XCTAssertFalse(ApplicationFeature.canReadFrom(clientType: "UnknownClient")) // Not allowed
    }
    
    // MARK: - Integration Tests
    
    func testRealWorldScenario() async {
        // Test a real-world scenario: user authentication with state tracking
        @Shared(.authenticationInternalState) var authState
        
        // Clear initial state
        $authState.auditedMutation(context: AuthenticationClient.self, operation: "clearState") { state in
            state.authState = .unauthenticated
            state.authenticationToken = nil
        }
        
        // Simulate authentication
        $authState.auditedMutation(context: AuthenticationClient.self, operation: "authenticate") { state in
            state.authState = .authenticated
            state.authenticationToken = "test-token"
            state.internalAuthUID = "test-uid"
        }
        
        // Verify mutations were tracked
        let mutations = AuthenticationClient.mutationLog.value
        XCTAssertGreaterThanOrEqual(mutations.count, 2)
        XCTAssertTrue(mutations.contains { $0.operation == "clearState" })
        XCTAssertTrue(mutations.contains { $0.operation == "authenticate" })
        
        // Verify final state
        XCTAssertEqual(authState.authState, .authenticated)
        XCTAssertEqual(authState.authenticationToken, "test-token")
    }
    
    // MARK: - Performance Tests
    
    func testMutationTrackingPerformance() {
        @Shared(.testInternalState) var testState
        
        measure {
            // Measure performance of audited mutations
            for i in 0..<100 {
                $testState.auditedMutation(context: TestClient.self, operation: "perfTest\(i)") { state in
                    state.value = "iteration-\(i)"
                }
            }
        }
        
        // Verify all mutations were logged
        XCTAssertEqual(TestClient.mutationLog.value.count, 100)
    }
    
    // MARK: - Error Handling Tests
    
    func testValidationErrors() {
        // Test that validation errors are properly thrown
        do {
            try ContextValidator.validateFeatureStateAccess(
                TestFeature.self,
                stateOwner: TestClient.self
            )
        } catch let error as ContextValidationError {
            // This should potentially throw an error for unauthorized access
            // The exact behavior depends on implementation
            XCTAssertNotNil(error.errorDescription)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}

// MARK: - Test Helper Types

// Test client that implements all enhanced protocols
@DependencyClient
struct TestClient: ClientContext, ClientDependencyGraph, StateAuditor {
    static var stateKey: any SharedReaderKey<TestClientState> { .testInternalState }
    static let mutationLog: LockIsolated<[StateMutation]> = LockIsolated([])
    
    static var allowedPrimitives: [any PrimitiveDependency.Type] {
        [URLSession.self, JSONEncoder.self]
    }
    
    static var deniedClients: [any ClientContext.Type] {
        [ContactsClient.self]
    }
    
    var testFunction: @Sendable () async -> Void = { }
}

// Test feature that implements ReducerContext
@Reducer
struct TestFeature: ReducerContext {
    typealias ReadState = TestClientState
    typealias StateOwner = TestClient
    
    @ObservableState
    struct State: Equatable {
        @Shared(.testInternalState) var testState
    }
    
    enum Action {
        case test
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            .none
        }
    }
}

// Test state for validation
struct TestClientState: Codable, Equatable {
    var value: String = "initial"
}

// Test shared key
extension SharedReaderKey where Self == FileStorageKey<TestClientState>.Default {
    static var testInternalState: Self {
        Self[.fileStorage(.documentsDirectory.appending(component: "testInternalState.json")), default: TestClientState()]
    }
}

// Test dependency registration
extension TestClient: DependencyKey {
    static let liveValue = TestClient()
    static let testValue = TestClient()
    static let mockValue = TestClient()
}

extension DependencyValues {
    var testClient: TestClient {
        get { self[TestClient.self] }
        set { self[TestClient.self] = newValue }
    }
}