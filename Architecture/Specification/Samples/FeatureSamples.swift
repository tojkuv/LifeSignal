// FeatureSamples.swift
// Sample implementations of TCA features for the LifeSignal iOS application

import Foundation
import ComposableArchitecture

// MARK: - Sample Feature

/// A sample feature that demonstrates the TCA pattern
@Reducer
struct SampleFeature {
    /// The state of the feature
    @ObservableState
    struct State: Equatable, Sendable {
        /// The user's name
        var name: String = ""
        
        /// Whether the feature is loading
        var isLoading: Bool = false
        
        /// Any error that occurred
        var error: String?
        
        /// The count value
        var count: Int = 0
        
        /// Presentation state for the detail feature
        @Presents var destination: Destination.State?
        
        /// Possible destinations for navigation
        enum Destination: Equatable, Sendable {
            /// Detail feature
            case detail(DetailFeature.State)
        }
    }
    
    /// The actions that can be performed on the feature
    enum Action: Equatable, Sendable {
        /// User actions
        case nameChanged(String)
        case incrementButtonTapped
        case decrementButtonTapped
        case resetButtonTapped
        case detailButtonTapped
        
        /// Effect responses
        case loadResponse(TaskResult<Int>)
        
        /// Presentation actions
        case destination(PresentationAction<Destination.Action>)
        
        /// Error handling
        case setError(String?)
        case dismissError
    }
    
    /// Dependencies
    @Dependency(\.sampleClient) var sampleClient
    
    /// The reducer for the feature
    var body: some ReducerOf<Self> {
        // Main reducer
        Reduce { state, action in
            switch action {
            case let .nameChanged(name):
                state.name = name
                return .none
                
            case .incrementButtonTapped:
                state.count += 1
                return .none
                
            case .decrementButtonTapped:
                state.count -= 1
                return .none
                
            case .resetButtonTapped:
                state.isLoading = true
                return .run { send in
                    do {
                        let count = try await sampleClient.loadCount()
                        await send(.loadResponse(.success(count)))
                    } catch {
                        await send(.loadResponse(.failure(error)))
                    }
                }
                
            case let .loadResponse(.success(count)):
                state.isLoading = false
                state.count = count
                return .none
                
            case let .loadResponse(.failure(error)):
                state.isLoading = false
                return .send(.setError(error.localizedDescription))
                
            case .detailButtonTapped:
                state.destination = .detail(
                    DetailFeature.State(
                        name: state.name,
                        count: state.count
                    )
                )
                return .none
                
            case .destination(.presented(.detail(.delegate(.detailSaved(let count))))):
                state.destination = nil
                state.count = count
                return .none
                
            case .destination:
                return .none
                
            case let .setError(error):
                state.error = error
                return .none
                
            case .dismissError:
                state.error = nil
                return .none
            }
        }
    }
}

// MARK: - Detail Feature

/// A detail feature that demonstrates child features
@Reducer
struct DetailFeature {
    /// The state of the feature
    @ObservableState
    struct State: Equatable, Sendable {
        /// The user's name
        var name: String
        
        /// The count value
        var count: Int
        
        /// Whether the feature is in edit mode
        var isEditing: Bool = false
    }
    
    /// The actions that can be performed on the feature
    enum Action: Equatable, Sendable {
        /// User actions
        case editButtonTapped
        case incrementButtonTapped
        case decrementButtonTapped
        case saveButtonTapped
        case cancelButtonTapped
        
        /// Delegate actions
        case delegate(DelegateAction)
        
        /// Delegate action types
        enum DelegateAction: Equatable, Sendable {
            /// The detail was saved with a new count
            case detailSaved(Int)
        }
    }
    
    /// The reducer for the feature
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .editButtonTapped:
                state.isEditing = true
                return .none
                
            case .incrementButtonTapped:
                state.count += 1
                return .none
                
            case .decrementButtonTapped:
                state.count -= 1
                return .none
                
            case .saveButtonTapped:
                state.isEditing = false
                return .send(.delegate(.detailSaved(state.count)))
                
            case .cancelButtonTapped:
                state.isEditing = false
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Sample Client

/// A sample client that demonstrates the client interface pattern
struct SampleClient: Sendable {
    /// Load a count value
    var loadCount: @Sendable () async throws -> Int
    
    /// Save a count value
    var saveCount: @Sendable (Int) async throws -> Void
}

/// Sample client dependency key
extension SampleClient: DependencyKey {
    /// Live implementation
    static var liveValue: Self {
        Self(
            loadCount: {
                // Simulate network request
                try await Task.sleep(for: .seconds(1))
                return 0
            },
            saveCount: { count in
                // Simulate network request
                try await Task.sleep(for: .seconds(1))
            }
        )
    }
    
    /// Test implementation
    static var testValue: Self {
        Self(
            loadCount: {
                return 0
            },
            saveCount: { _ in
                // No-op in test
            }
        )
    }
    
    /// Preview implementation
    static var previewValue: Self {
        Self(
            loadCount: {
                return 42
            },
            saveCount: { _ in
                // No-op in preview
            }
        )
    }
}

/// Sample client dependency values extension
extension DependencyValues {
    /// Sample client dependency
    var sampleClient: SampleClient {
        get { self[SampleClient.self] }
        set { self[SampleClient.self] = newValue }
    }
}

// MARK: - Sample Feature Tests

/// Sample tests for the sample feature
@MainActor
final class SampleFeatureTests {
    /// Test incrementing the count
    func testIncrement() async {
        let store = TestStore(
            initialState: SampleFeature.State(),
            reducer: { SampleFeature() }
        )
        
        await store.send(.incrementButtonTapped) {
            $0.count = 1
        }
    }
    
    /// Test decrementing the count
    func testDecrement() async {
        let store = TestStore(
            initialState: SampleFeature.State(count: 1),
            reducer: { SampleFeature() }
        )
        
        await store.send(.decrementButtonTapped) {
            $0.count = 0
        }
    }
    
    /// Test resetting the count
    func testReset() async {
        let store = TestStore(
            initialState: SampleFeature.State(count: 10),
            reducer: { SampleFeature() }
        )
        
        // Override dependencies
        store.dependencies.sampleClient.loadCount = {
            return 0
        }
        
        await store.send(.resetButtonTapped) {
            $0.isLoading = true
        }
        
        await store.receive(.loadResponse(.success(0))) {
            $0.isLoading = false
            $0.count = 0
        }
    }
    
    /// Test error handling
    func testError() async {
        let store = TestStore(
            initialState: SampleFeature.State(),
            reducer: { SampleFeature() }
        )
        
        // Override dependencies
        store.dependencies.sampleClient.loadCount = {
            struct SampleError: Error {}
            throw SampleError()
        }
        
        await store.send(.resetButtonTapped) {
            $0.isLoading = true
        }
        
        await store.receive(.loadResponse(.failure(SampleError()))) {
            $0.isLoading = false
        }
        
        await store.receive(.setError("The operation couldn't be completed. (FeatureSamples.SampleFeatureTests.(unknown context at $10d9b8e98).(unknown context at $10d9b8ea0).SampleError error 1.)")) {
            $0.error = "The operation couldn't be completed. (FeatureSamples.SampleFeatureTests.(unknown context at $10d9b8e98).(unknown context at $10d9b8ea0).SampleError error 1.)"
        }
    }
}
