import Foundation
import ComposableArchitecture
import Dependencies
import DependenciesMacros
@_exported import Sharing

// MARK: - Test State Definition

struct TestClientState: Equatable, Codable {
    var counter: Int
    var lastUpdated: Date?
    var isActive: Bool
    
    init(counter: Int = 0, lastUpdated: Date? = nil, isActive: Bool = false) {
        self.counter = counter
        self.lastUpdated = lastUpdated
        self.isActive = isActive
    }
}

// MARK: - Shared State Key

extension SharedReaderKey where Self == FileStorageKey<TestClientState>.Default {
    static var testClientState: Self {
        Self[.fileStorage(.documentsDirectory.appending(component: "testClientState.json")), default: TestClientState()]
    }
}

// MARK: - Test StateOwnerClient

/// Test implementation of a StateOwnerClient that owns TestClientState
/// This should compile successfully demonstrating state ownership with associated type
@DependencyClient  
struct TestStateOwnerClient: StateOwnerClient, Sendable {
    
    /// The specific state type this client owns (associatedtype requirement)
    typealias OwnedState = TestClientState
    
    // MARK: - State Mutation Operations
    
    /// Increments the counter in owned state
    var incrementCounter: @Sendable () async -> Void = { }
    
    /// Decrements the counter in owned state  
    var decrementCounter: @Sendable () async -> Void = { }
    
    /// Sets the active status in owned state
    var setActiveStatus: @Sendable (Bool) async -> Void = { _ in }
    
    /// Resets the state to default values
    var resetState: @Sendable () async -> Void = { }
    
    // MARK: - State Reading Operations
    
    /// Gets current counter value
    var getCurrentCounter: @Sendable () -> Int = { 0 }
    
    /// Gets current active status
    var getActiveStatus: @Sendable () -> Bool = { false }
    
    /// Gets last updated timestamp
    var getLastUpdated: @Sendable () -> Date? = { nil }
}

// MARK: - Dependency Registration

extension TestStateOwnerClient: DependencyKey {
    static let liveValue = TestStateOwnerClient(
        incrementCounter: {
            @Shared(.testClientState) var state
            $state.withLock { state in
                state.counter += 1
                state.lastUpdated = Date()
            }
        },
        
        decrementCounter: {
            @Shared(.testClientState) var state  
            $state.withLock { state in
                state.counter -= 1
                state.lastUpdated = Date()
            }
        },
        
        setActiveStatus: { isActive in
            @Shared(.testClientState) var state
            $state.withLock { state in
                state.isActive = isActive
                state.lastUpdated = Date()
            }
        },
        
        resetState: {
            @Shared(.testClientState) var state
            $state.withLock { state in
                state.counter = 0
                state.isActive = false
                state.lastUpdated = Date()
            }
        },
        
        getCurrentCounter: {
            @Shared(.testClientState) var state
            return state.counter
        },
        
        getActiveStatus: {
            @Shared(.testClientState) var state
            return state.isActive  
        },
        
        getLastUpdated: {
            @Shared(.testClientState) var state
            return state.lastUpdated
        }
    )
    
    static let testValue = TestStateOwnerClient(
        incrementCounter: { },
        decrementCounter: { },
        setActiveStatus: { _ in },
        resetState: { },
        getCurrentCounter: { 42 },
        getActiveStatus: { true },
        getLastUpdated: { Date() }
    )
}

extension DependencyValues {
    var testStateOwnerClient: TestStateOwnerClient {
        get { self[TestStateOwnerClient.self] }
        set { self[TestStateOwnerClient.self] = newValue }
    }
}