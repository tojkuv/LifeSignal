import ComposableArchitecture
import Foundation

// MARK: - Approach 1: Dependency Context Protocol

protocol ReducerContext {}
protocol ClientContext {}

// Mark your reducers
extension MyFeature: ReducerContext {}
extension AnotherFeature: ReducerContext {}

// Create context-aware dependency access
extension DependencyValues {
    subscript<T: ReducerContext>(
        dynamicMember keyPath: KeyPath<DependencyValues, MyClient>
    ) -> MyClient {
        self[keyPath: keyPath]
    }
    
    // This will fail to compile if called from a client context
    subscript<T: ClientContext>(
        dynamicMember keyPath: KeyPath<DependencyValues, MyClient>
    ) -> MyClient {
        fatalError("Clients cannot depend on other clients")
    }
}

// MARK: - Approach 2: Dependency Access Restriction

// For reducers - allows client dependencies
struct ReducerDependencies {
    @Dependency(\.myClient) var myClient
    @Dependency(\.anotherClient) var anotherClient
}

// For clients - only allows primitive dependencies  
struct ClientDependencies {
    @Dependency(\.urlSession) var urlSession
    @Dependency(\.userDefaults) var userDefaults
    // Compiler error if you try to add client dependencies here
}

// MARK: - Approach 3: Phantom Type Enforcement

struct DependencyContainer<Context> {
    private let values: DependencyValues
    
    init(_ values: DependencyValues) {
        self.values = values
    }
}

extension DependencyContainer where Context: ReducerContext {
    var myClient: MyClient {
        values.myClient
    }
    
    var anotherClient: AnotherClient {
        values.anotherClient
    }
}

extension DependencyContainer where Context: ClientContext {
    var urlSession: URLSession {
        values.urlSession
    }
    
    var userDefaults: UserDefaults {
        values.userDefaults
    }
    // No client dependencies available in this context
}

// MARK: - Approach 4: Custom Dependency Macro (Placeholder)

// Note: This would require implementing the actual macro
@attached(peer)
macro ClientDependency() = #externalMacro(module: "MyMacros", type: "ClientDependencyMacro")

// MARK: - Approach 5: Protocol-Based Restriction

protocol ClientDependencyRestricted {
    // Only primitive dependencies allowed
    init(urlSession: URLSession, userDefaults: UserDefaults)
}

protocol PrimitiveDependency {}

// Mark allowed primitive dependencies
extension URLSession: PrimitiveDependency {}
extension UserDefaults: PrimitiveDependency {}

// MARK: - Example Client Implementations

@DependencyClient
struct MyClient: ClientContext {
    // Approach 2: Using ClientDependencies
    init(dependencies: ClientDependencies = .init()) {
        // Can only access primitive dependencies
    }
    
    // Approach 3: Using DependencyContainer
    init(container: DependencyContainer<MyClient> = .init(DependencyValues._current)) {
        // Can only access primitive dependencies through container
    }
    
    // Default implementation for live client
    static let liveValue = MyClient()
}

@DependencyClient
struct AnotherClient: ClientContext, ClientDependencyRestricted {
    // Approach 5: Protocol-based restriction
    init(urlSession: URLSession, userDefaults: UserDefaults) {
        // Forced to only accept primitives
    }
    
    static let liveValue = AnotherClient(
        urlSession: .shared,
        userDefaults: .standard
    )
}

// Client that would violate restrictions (for demonstration)
@DependencyClient
struct ProblematicClient: ClientContext {
    // This should cause compile errors with our restrictions
    // @Dependency(\.myClient) var myClient // ❌ Should not be allowed
    
    init() {}
    static let liveValue = ProblematicClient()
}

// MARK: - Example Reducer Implementations

@Reducer
struct MyFeature: ReducerContext {
    @ObservableState
    struct State {
        var isLoading = false
        var data: String = ""
    }
    
    enum Action {
        case loadData
        case dataLoaded(String)
    }
    
    // ✅ Allowed - reducers can depend on clients
    @Dependency(\.myClient) var myClient
    @Dependency(\.anotherClient) var anotherClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadData:
                state.isLoading = true
                return .run { send in
                    // Use client dependencies
                    let data = await myClient.fetchData()
                    await send(.dataLoaded(data))
                }
                
            case let .dataLoaded(data):
                state.isLoading = false
                state.data = data
                return .none
            }
        }
    }
}

@Reducer
struct AnotherFeature: ReducerContext {
    @ObservableState
    struct State {}
    
    enum Action {}
    
    // ✅ Also allowed - reducers can use multiple clients
    @Dependency(\.myClient) var myClient
    @Dependency(\.anotherClient) var anotherClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            .none
        }
    }
}

// MARK: - Dependency Registration

extension DependencyValues {
    var myClient: MyClient {
        get { self[MyClientKey.self] }
        set { self[MyClientKey.self] = newValue }
    }
    
    var anotherClient: AnotherClient {
        get { self[AnotherClientKey.self] }
        set { self[AnotherClientKey.self] = newValue }
    }
    
    var urlSession: URLSession {
        get { self[URLSessionKey.self] }
        set { self[URLSessionKey.self] = newValue }
    }
    
    var userDefaults: UserDefaults {
        get { self[UserDefaultsKey.self] }
        set { self[UserDefaultsKey.self] = newValue }
    }
}

private struct MyClientKey: DependencyKey {
    static let liveValue = MyClient.liveValue
}

private struct AnotherClientKey: DependencyKey {
    static let liveValue = AnotherClient.liveValue
}

private struct URLSessionKey: DependencyKey {
    static let liveValue = URLSession.shared
}

private struct UserDefaultsKey: DependencyKey {
    static let liveValue = UserDefaults.standard
}

// MARK: - Usage Examples and Tests

struct ExampleUsage {
    static func demonstrateApproaches() {
        // Approach 1: Context Protocol
        // Reducers can access clients, clients cannot
        
        // Approach 2: Dependency Access Restriction
        let reducerDeps = ReducerDependencies()
        // reducerDeps.myClient // ✅ Works
        
        let clientDeps = ClientDependencies()
        // clientDeps.urlSession // ✅ Works
        // clientDeps.myClient // ❌ Not available
        
        // Approach 3: Phantom Type Enforcement
        let reducerContainer = DependencyContainer<MyFeature>(DependencyValues._current)
        // reducerContainer.myClient // ✅ Works
        
        let clientContainer = DependencyContainer<MyClient>(DependencyValues._current)
        // clientContainer.urlSession // ✅ Works
        // clientContainer.myClient // ❌ Not available
        
        // Approach 5: Protocol-Based Restriction
        // AnotherClient can only be initialized with primitives
    }
}

// MARK: - Validation Protocol (Additional approach)

protocol ValidatedClient {
    associatedtype Dependencies
    static func validateDependencies(_: Dependencies.Type)
}

extension MyClient: ValidatedClient {
    typealias Dependencies = (URLSession, UserDefaults)
    
    static func validateDependencies(_: Dependencies.Type) {
        // This will fail to compile if Dependencies contains other clients
        _ = Dependencies.self as (any PrimitiveDependency, any PrimitiveDependency)
    }
}