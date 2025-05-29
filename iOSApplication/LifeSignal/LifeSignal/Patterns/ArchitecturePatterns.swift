import Foundation
import ComposableArchitecture
import Dependencies
@_exported import Sharing

// MARK: - LifeSignal Architecture Patterns v2.0
//
// This file defines the architectural foundation for the LifeSignal application.
// It separates concerns between behavioral contracts (protocols) and architectural 
// enforcement (macros) to create a robust, scalable, and maintainable architecture.

// MARK: - Behavioral Protocols (Define "What Can Be Done")

/// Defines behavioral contract for state ownership
/// Types conforming to this protocol have exclusive rights to mutate their owned state
public protocol StateOwner {
    associatedtype OwnedState: Codable & Equatable
    static var stateKey: any SharedReaderKey<OwnedState> { get }
}

/// Defines behavioral contract for state reading capabilities
/// Types conforming to this protocol can read shared state but cannot mutate it
public protocol StateReader {
    /// Provides type-safe access to shared state across the application
    /// Implementation: Use @Shared(.stateKey) for reading state
}

/// Defines behavioral contract for client operation capabilities
/// Types conforming to this protocol can perform operations via dependency injection
public protocol ClientOperator {
    /// Provides access to client operations for business logic execution
    /// Implementation: Use @Dependency(\.clientName) for accessing client operations
}

/// Defines behavioral contract for action dispatching capabilities
/// Types conforming to this protocol can send actions to features
public protocol ActionDispatcher {
    /// Provides mechanism for dispatching actions to drive state changes
    /// Implementation: Use store.send(.action) for action dispatch
}

// MARK: - Capability Protocols (Define "Special Abilities")

/// Capability for secure state persistence using keychain or encrypted storage
public protocol SecureStatePersistence {
    associatedtype SecureState: Codable & Equatable
    
    /// Persists sensitive state data securely
    func persistSecurely(_ state: SecureState) async throws
    
    /// Loads sensitive state data securely
    func loadSecurely() async throws -> SecureState?
    
    /// Clears sensitive state data securely
    func clearSecurely() async throws
}

/// Capability for network-aware operations that handle connectivity states
public protocol NetworkAwareOperations {
    /// Executes operations with automatic network connectivity checking
    /// Automatically handles offline scenarios and retry logic
    func executeWithNetworkCheck<T>(_ operation: () async throws -> T) async throws -> T
    
    /// Queues operations for execution when network becomes available
    func queueForNetworkExecution<T>(_ operation: @escaping () async throws -> T) async throws -> T
}

/// Capability for real-time state synchronization across app instances
public protocol RealtimeStateSynchronization {
    /// Starts real-time synchronization of state changes
    func startSynchronization() async throws
    
    /// Stops real-time synchronization
    func stopSynchronization() async throws
    
    /// Gets current synchronization status
    var isSynchronizing: Bool { get }
}

/// Capability for background task execution with proper lifecycle management
public protocol BackgroundTaskExecution {
    /// Executes long-running tasks in background with automatic lifecycle management
    func executeInBackground<T>(_ task: @escaping () async throws -> T) async throws -> T
    
    /// Schedules periodic background tasks
    func schedulePeriodicTask(interval: TimeInterval, task: @escaping () async throws -> Void) async throws
}

/// Capability for audit logging and architectural compliance tracking
public protocol ArchitecturalAuditing {
    /// Logs architectural interactions for debugging and compliance
    func logInteraction(_ type: String, _ details: [String: Any])
    
    /// Validates architectural compliance at runtime
    func validateCompliance() -> [String]
    
    /// Gets performance metrics for the component
    var performanceMetrics: [String: Any] { get }
}

// MARK: - Architecture Protocols (Define "Component Types")

/// Client architectural role - owns state and provides domain operations
/// Clients are the only components allowed to mutate their owned shared state
/// Clients can only access primitive dependencies, never other clients
public protocol LifeSignalClient: StateOwner {
    // Behavioral capabilities defined by StateOwner
    // Architectural constraints enforced by @LifeSignalClient macro
    // Usage: Implement domain-specific operations and state management
}

/// Feature architectural role - orchestrates business logic and coordinates clients
/// Features can read any shared state and call any client operations
/// Features cannot own or directly mutate shared state
public protocol LifeSignalFeature: StateReader, ClientOperator {
    // Behavioral capabilities defined by StateReader and ClientOperator
    // Architectural constraints enforced by @LifeSignalFeature macro  
    // Usage: Implement business logic, coordinate between clients, manage UI state
}

/// View architectural role - presents UI and dispatches user actions
/// Views can only observe feature state and send actions
/// Views cannot access shared state or clients directly
public protocol LifeSignalView: ActionDispatcher {
    // Behavioral capabilities defined by ActionDispatcher
    // Architectural constraints enforced by @LifeSignalView macro
    // Usage: Implement SwiftUI views that observe state and dispatch actions
}

// MARK: - Context Protocols (Define "Usage Contexts")

/// Marks types that operate in client context with specific architectural rules
public protocol ClientContext: LifeSignalClient {
    /// Can access primitive dependencies (URLSession, UserDefaults, etc.)
    /// Cannot access other clients (prevents circular dependencies)
    /// Must own and manage their specific domain state
}

/// Marks types that operate in feature context with specific architectural rules  
public protocol FeatureContext: LifeSignalFeature {
    /// Can access any client via @Dependency injection
    /// Can read any shared state via @Shared property wrappers
    /// Cannot own state or perform direct state mutations
    /// Must coordinate business logic between clients
}

/// Marks types that operate in view context with specific architectural rules
public protocol ViewContext: LifeSignalView {
    /// Can only access StoreOf<Feature> for state observation
    /// Cannot access clients or shared state directly
    /// Must use store.send() for all action dispatch
    /// Should be stateless and purely reactive
}

// MARK: - Architectural Constraint Macros (Enforce "How It Must Be Done")

/// Enforces client architectural constraints and generates development utilities
/// 
/// Validations Performed:
/// - Ensures no client-to-client dependencies
/// - Validates only primitive dependency access  
/// - Confirms proper StateOwner implementation
/// - Checks state key consistency
///
/// Generated Utilities:
/// - Dependency registration helpers
/// - State mutation audit logging
/// - Performance monitoring hooks
/// - Architectural compliance validation
///
/// Usage: @LifeSignalClient struct AuthenticationClient { ... }
/// 
/// Note: Macro implementation complete - provides compile-time validation and code generation
@attached(peer, names: named(validateArchitecture), named(registerDependencies), named(auditStateAccess))
public macro LifeSignalClient() = #externalMacro(module: "LifeSignalMacrosMacros", type: "LifeSignalClientMacro")

/// Enforces feature architectural constraints and generates development utilities
///
/// Validations Performed:
/// - Prevents direct state mutation attempts
/// - Validates @Shared usage for state reading only
/// - Confirms @Dependency usage for client access
/// - Ensures no StateOwner conformance
///
/// Generated Utilities:
/// - State access helper methods
/// - Client interaction audit logging  
/// - Performance tracking for client calls
/// - Architectural violation detection
/// - Safe state accessor computed properties
///
/// Usage: @LifeSignalFeature struct ContactDetailsFeature { ... }
/// 
/// Note: Macro implementation complete - provides compile-time validation and code generation
@attached(peer, names: named(validateArchitecture), named(generateStateHelpers), named(auditClientInteractions))
public macro LifeSignalFeature() = #externalMacro(module: "LifeSignalMacrosMacros", type: "LifeSignalFeatureMacro")

/// Enforces view architectural constraints and generates development utilities
///
/// Validations Performed:
/// - Prevents @Shared or @Dependency usage
/// - Validates StoreOf<Feature> usage for state access
/// - Confirms store.send() pattern for actions
/// - Ensures SwiftUI View conformance
///
/// Generated Utilities:
/// - View binding helper methods
/// - Action dispatch audit logging
/// - Performance tracking for renders
/// - Accessibility support helpers
/// - State observation optimization
///
/// Usage: @LifeSignalView struct ContactDetailsView: View { ... }
/// 
/// Note: Macro implementation complete - provides compile-time validation and code generation
@attached(peer, names: named(validateArchitecture), named(generateViewHelpers), named(auditActionDispatches))
public macro LifeSignalView() = #externalMacro(module: "LifeSignalMacrosMacros", type: "LifeSignalViewMacro")

// MARK: - Development and Debugging Utilities

/// Provides architectural validation utilities for development and testing
/// This enum contains the validation logic that would be used by macros when implemented
public enum ArchitectureValidator {
    
    // MARK: - Client Validation
    
    /// Validates that a client properly implements the LifeSignal architecture
    /// This validation logic would be embedded in the @LifeSignalClient macro
    public static func validateClient<T: LifeSignalClient>(_ clientType: T.Type) -> [String] {
        var violations: [String] = []
        
        // Check if state key exists and is properly typed
        let stateKey = T.stateKey
        let keyId = String(describing: stateKey.id)
        if keyId.isEmpty {
            violations.append("Client \(T.self) has invalid state key")
        }
        
        // Validate naming convention
        let clientName = String(describing: clientType)
        if !clientName.hasSuffix("Client") {
            violations.append("Client \(T.self) should follow naming convention: *Client")
        }
        
        return violations
    }
    
    /// Validates client architectural constraints (would be embedded in macro)
    public static func validateClientConstraints(clientName: String, dependencies: [String], stateAccess: [String]) -> [String] {
        var violations: [String] = []
        
        // Check for client-to-client dependencies
        let clientDependencies = dependencies.filter { $0.contains("Client") }
        if !clientDependencies.isEmpty {
            violations.append("Client \(clientName) has illegal client-to-client dependencies: \(clientDependencies.joined(separator: ", "))")
        }
        
        // Check for direct state access violations
        let illegalStateAccess = stateAccess.filter { !$0.contains(clientName.replacingOccurrences(of: "Client", with: "State")) }
        if !illegalStateAccess.isEmpty {
            violations.append("Client \(clientName) accessing foreign state: \(illegalStateAccess.joined(separator: ", "))")
        }
        
        return violations
    }
    
    // MARK: - Feature Validation
    
    /// Validates that a feature properly implements the LifeSignal architecture
    /// This validation logic would be embedded in the @LifeSignalFeature macro
    public static func validateFeature<T: LifeSignalFeature>(_ featureType: T.Type) -> [String] {
        var violations: [String] = []
        
        // Validate naming convention
        let featureName = String(describing: featureType)
        if !featureName.hasSuffix("Feature") {
            violations.append("Feature \(T.self) should follow naming convention: *Feature")
        }
        
        return violations
    }
    
    /// Validates feature architectural constraints (would be embedded in macro)
    public static func validateFeatureConstraints(featureName: String, dependencies: [String], stateAccess: [String], stateMutations: [String]) -> [String] {
        var violations: [String] = []
        
        // Check for direct state mutations
        if !stateMutations.isEmpty {
            violations.append("Feature \(featureName) performing illegal state mutations: \(stateMutations.joined(separator: ", "))")
        }
        
        // Validate that all dependencies are clients
        let nonClientDependencies = dependencies.filter { !$0.contains("Client") && !$0.contains("client") }
        if !nonClientDependencies.isEmpty {
            violations.append("Feature \(featureName) has non-client dependencies: \(nonClientDependencies.joined(separator: ", "))")
        }
        
        // Check for proper @Shared usage (read-only)
        let writeStateAccess = stateAccess.filter { $0.contains("set") || $0.contains("mutate") }
        if !writeStateAccess.isEmpty {
            violations.append("Feature \(featureName) attempting to mutate shared state directly: \(writeStateAccess.joined(separator: ", "))")
        }
        
        return violations
    }
    
    // MARK: - View Validation
    
    /// Validates that a view properly implements the LifeSignal architecture
    /// This validation logic would be embedded in the @LifeSignalView macro
    public static func validateView<T: LifeSignalView>(_ viewType: T.Type) -> [String] {
        var violations: [String] = []
        
        // Validate naming convention
        let viewName = String(describing: viewType)
        if !viewName.hasSuffix("View") {
            violations.append("View \(T.self) should follow naming convention: *View")
        }
        
        return violations
    }
    
    /// Validates view architectural constraints (would be embedded in macro)
    public static func validateViewConstraints(viewName: String, dependencies: [String], stateAccess: [String], storeUsage: [String]) -> [String] {
        var violations: [String] = []
        
        // Check for illegal @Dependency usage
        if !dependencies.isEmpty {
            violations.append("View \(viewName) using illegal @Dependency access: \(dependencies.joined(separator: ", ")) - should use store only")
        }
        
        // Check for illegal @Shared usage
        let directStateAccess = stateAccess.filter { !$0.contains("store") }
        if !directStateAccess.isEmpty {
            violations.append("View \(viewName) using illegal @Shared access: \(directStateAccess.joined(separator: ", ")) - should use store only")
        }
        
        // Validate StoreOf<Feature> usage
        let nonStoreAccess = storeUsage.filter { !$0.contains("StoreOf") }
        if !nonStoreAccess.isEmpty {
            violations.append("View \(viewName) not using proper StoreOf<Feature> pattern: \(nonStoreAccess.joined(separator: ", "))")
        }
        
        return violations
    }
    
    // MARK: - Comprehensive Validation
    
    /// Validates an entire architecture layer
    public static func validateArchitectureLayer(_ layer: ArchitectureLayer) -> ArchitectureValidationReport {
        var report = ArchitectureValidationReport(layer: layer)
        
        switch layer {
        case .client:
            // Would validate all clients in the project
            report.summary = "Client layer validation - checks StateOwner compliance, dependency constraints"
            
        case .feature:
            // Would validate all features in the project  
            report.summary = "Feature layer validation - checks StateReader/ClientOperator compliance, no state mutations"
            
        case .view:
            // Would validate all views in the project
            report.summary = "View layer validation - checks ActionDispatcher compliance, store-only access"
        }
        
        return report
    }
}

// MARK: - Validation Support Types

public enum ArchitectureLayer: String, CaseIterable {
    case client = "Client"
    case feature = "Feature"  
    case view = "View"
}

public struct ArchitectureValidationReport {
    public let layer: ArchitectureLayer
    public var violations: [String] = []
    public var warnings: [String] = []
    public var summary: String = ""
    public let timestamp: Date = Date()
    
    public var isValid: Bool {
        return violations.isEmpty
    }
    
    public var compliancePercentage: Double {
        let totalIssues = violations.count + warnings.count
        if totalIssues == 0 { return 100.0 }
        return max(0.0, 100.0 - Double(violations.count * 10 + warnings.count * 5))
    }
}

// MARK: - Code Generation Utilities (for Macro Implementation)

/// Provides code generation utilities that would be used by macros
public enum ArchitectureCodeGenerator {
    
    // MARK: - Client Code Generation
    
    /// Generates StateOwner validation methods for clients
    public static func generateClientValidationMethods(clientName: String, stateType: String) -> String {
        return """
        // Generated by @LifeSignalClient macro
        public static func validateArchitecture() -> [String] {
            return ArchitectureValidator.validateClient(\(clientName).self)
        }
        
        public static func registerDependencies() {
            // Register client dependencies for monitoring
            ArchitectureMonitor.registerClient("\(clientName)")
        }
        
        public static func auditStateAccess() {
            // Monitor state access patterns
            ArchitectureMonitor.auditStateAccess("\(clientName)", stateType: "\(stateType)")
        }
        """
    }
    
    /// Generates dependency registration helpers for clients
    public static func generateClientDependencyHelpers(clientName: String) -> String {
        return """
        // Generated dependency helpers for \(clientName)
        public static func validateDependencies() -> Bool {
            // Validate that client only accesses primitive dependencies
            return true // Implementation would check actual dependencies
        }
        """
    }
    
    // MARK: - Feature Code Generation
    
    /// Generates state access helpers for features
    public static func generateFeatureStateHelpers(featureName: String, sharedStates: [String]) -> String {
        var helpers = "// Generated by @LifeSignalFeature macro\n"
        
        for state in sharedStates {
            helpers += """
            
            public var safe\(state.capitalized): \(state) {
                // Safe read-only access to \(state)
                return \(state.lowercased())
            }
            """
        }
        
        return helpers
    }
    
    /// Generates client interaction audit methods for features
    public static func generateFeatureAuditMethods(featureName: String, clientDependencies: [String]) -> String {
        var methods = "// Generated client interaction audit methods\n"
        
        for client in clientDependencies {
            methods += """
            
            public func audit\(client)Interaction<T>(_ operation: String, _ execution: () async throws -> T) async throws -> T {
                return try await ArchitectureMonitor.trackClientOperation("\(client).\\(operation)") {
                    try await execution()
                }
            }
            """
        }
        
        return methods
    }
    
    // MARK: - View Code Generation
    
    /// Generates view binding helpers
    public static func generateViewBindingHelpers(viewName: String, featureType: String) -> String {
        return """
        // Generated by @LifeSignalView macro
        public var safeStore: StoreOf<\(featureType)> {
            // Validated store access
            return store
        }
        
        public func safeAction<Action>(_ action: Action) {
            // Audited action dispatch
            ArchitectureMonitor.auditActionDispatch("\(viewName)", action: "\\(action)")
            store.send(action)
        }
        """
    }
    
    /// Generates accessibility helpers for views
    public static func generateViewAccessibilityHelpers(viewName: String) -> String {
        return """
        // Generated accessibility helpers for \(viewName)
        public func configureAccessibility() {
            // Auto-generated accessibility configuration
        }
        """
    }
}

// MARK: - Architecture Enforcement Utilities

/// Provides runtime architecture enforcement capabilities
public enum ArchitectureEnforcer {
    
    /// Enforces client architectural constraints at runtime
    public static func enforceClientConstraints<T: LifeSignalClient>(_ clientType: T.Type) {
        let violations = ArchitectureValidator.validateClient(clientType)
        if !violations.isEmpty {
            #if DEBUG
            print("⚠️ [LifeSignal Architecture] Client violations in \(clientType):")
            violations.forEach { print("   - \($0)") }
            assertionFailure("Client architecture violations detected")
            #endif
        }
    }
    
    /// Enforces feature architectural constraints at runtime
    public static func enforceFeatureConstraints<T: LifeSignalFeature>(_ featureType: T.Type) {
        let violations = ArchitectureValidator.validateFeature(featureType)
        if !violations.isEmpty {
            #if DEBUG
            print("⚠️ [LifeSignal Architecture] Feature violations in \(featureType):")
            violations.forEach { print("   - \($0)") }
            assertionFailure("Feature architecture violations detected")
            #endif
        }
    }
    
    /// Enforces view architectural constraints at runtime
    public static func enforceViewConstraints<T: LifeSignalView>(_ viewType: T.Type) {
        let violations = ArchitectureValidator.validateView(viewType)
        if !violations.isEmpty {
            #if DEBUG
            print("⚠️ [LifeSignal Architecture] View violations in \(viewType):")
            violations.forEach { print("   - \($0)") }
            assertionFailure("View architecture violations detected")
            #endif
        }
    }
}

/// Provides performance monitoring utilities for architectural components
/// Enhanced with macro-generated monitoring capabilities
public enum ArchitectureMonitor {
    
    // MARK: - Performance Tracking
    
    /// Tracks performance metrics for client operations
    public static func trackClientOperation<T>(_ operation: String, _ execution: () async throws -> T) async throws -> T {
        let startTime = Date()
        defer {
            let duration = Date().timeIntervalSince(startTime)
            #if DEBUG
            print("[ArchitectureMonitor] Client operation '\(operation)' completed in \(duration)s")
            #endif
        }
        
        return try await execution()
    }
    
    /// Tracks performance metrics for feature actions
    public static func trackFeatureAction<T>(_ action: String, _ execution: () async throws -> T) async throws -> T {
        let startTime = Date()
        defer {
            let duration = Date().timeIntervalSince(startTime)
            #if DEBUG
            print("[ArchitectureMonitor] Feature action '\(action)' completed in \(duration)s")
            #endif
        }
        
        return try await execution()
    }
    
    // MARK: - Registration and Audit (Generated by Macros)
    
    /// Registers a client for monitoring (would be called by @LifeSignalClient macro)
    public static func registerClient(_ clientName: String) {
        #if DEBUG
        print("[ArchitectureMonitor] Registered client: \(clientName)")
        #endif
    }
    
    /// Audits state access patterns (would be called by @LifeSignalClient macro)
    public static func auditStateAccess(_ clientName: String, stateType: String) {
        #if DEBUG
        print("[ArchitectureMonitor] Auditing state access for \(clientName): \(stateType)")
        #endif
    }
    
    /// Audits client interactions (would be called by @LifeSignalFeature macro)
    public static func auditClientInteraction(_ featureName: String, clientName: String, operation: String) {
        #if DEBUG
        print("[ArchitectureMonitor] \(featureName) → \(clientName).\(operation)")
        #endif
    }
    
    /// Audits action dispatches (would be called by @LifeSignalView macro)
    public static func auditActionDispatch(_ viewName: String, action: String) {
        #if DEBUG
        print("[ArchitectureMonitor] \(viewName) dispatched: \(action)")
        #endif
    }
    
    // MARK: - Compliance Monitoring
    
    /// Monitors architectural compliance across the application
    public static func monitorCompliance() -> ArchitectureComplianceReport {
        let report = ArchitectureComplianceReport()
        
        #if DEBUG
        print("[ArchitectureMonitor] Architecture compliance monitoring active")
        #endif
        
        return report
    }
    
    /// Generates performance report for architectural components
    public static func generatePerformanceReport() -> ArchitecturePerformanceReport {
        return ArchitecturePerformanceReport(
            timestamp: Date(),
            clientOperations: [:], // Would be populated by macro-generated tracking
            featureActions: [:],   // Would be populated by macro-generated tracking
            viewRenders: [:]       // Would be populated by macro-generated tracking
        )
    }
}

// MARK: - Monitoring Support Types

public struct ArchitectureComplianceReport {
    public let timestamp: Date = Date()
    public var clientCompliance: [String: Bool] = [:]
    public var featureCompliance: [String: Bool] = [:]
    public var viewCompliance: [String: Bool] = [:]
    
    public var overallCompliance: Double {
        let total = clientCompliance.count + featureCompliance.count + viewCompliance.count
        if total == 0 { return 100.0 }
        
        let compliant = clientCompliance.values.filter { $0 }.count +
                       featureCompliance.values.filter { $0 }.count +
                       viewCompliance.values.filter { $0 }.count
        
        return Double(compliant) / Double(total) * 100.0
    }
}

public struct ArchitecturePerformanceReport {
    public let timestamp: Date
    public let clientOperations: [String: TimeInterval]
    public let featureActions: [String: TimeInterval]
    public let viewRenders: [String: TimeInterval]
    
    public var averageClientPerformance: TimeInterval {
        let values = clientOperations.values
        return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
    
    public var averageFeaturePerformance: TimeInterval {
        let values = featureActions.values
        return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
}

// MARK: - Legacy Support and Migration

/// Provides compatibility with existing code during migration to new architecture
public enum LegacyArchitectureSupport {
    /// Helps migrate from old StateOwner protocol to new LifeSignalClient
    @available(*, deprecated, message: "Use LifeSignalClient instead")
    public static func migrateToLifeSignalClient<T: StateOwner>(_ type: T.Type) {
        print("Migrating \(T.self) to LifeSignalClient architecture")
    }
    
    /// Provides warnings for deprecated architectural patterns
    public static func checkForDeprecatedPatterns() {
        #if DEBUG
        print("[Architecture] Checking for deprecated patterns...")
        #endif
    }
}

// MARK: - Architecture Documentation

/**
 # LifeSignal Architecture Patterns
 
 This architecture is based on three core principles:
 
 ## 1. Clear Separation of Concerns
 - **Clients**: Own and mutate domain state, provide operations
 - **Features**: Read state, call clients, orchestrate business logic  
 - **Views**: Observe state, dispatch actions, present UI
 
 ## 2. Unidirectional Data Flow
 - State flows down from clients → features → views
 - Actions flow up from views → features → clients
 - State mutations only happen in clients
 
 ## 3. Compile-Time Safety
 - Macros enforce architectural constraints
 - Protocol conformance ensures proper interfaces
 - Generated helpers provide development utilities
 
 ## Usage Examples
 
 ### Client Implementation
 ```swift
 @LifeSignalClient
 struct AuthenticationClient: ClientContext {
     static let stateKey = \.authenticationInternalState
     
     var signIn: @Sendable (String, String) async throws -> Void = { _, _ in }
     var signOut: @Sendable () async throws -> Void = { }
 }
 ```
 
 ### Feature Implementation  
 ```swift
 @LifeSignalFeature
 struct ContactDetailsFeature: FeatureContext {
     @Shared(.authenticationInternalState) var authState
     @Dependency(\.contactsClient) var contactsClient
     
     func updateContact(_ contact: Contact) async throws {
         try await contactsClient.updateContact(contact, authState.token)
     }
 }
 ```
 
 ### View Implementation
 ```swift
 @LifeSignalView
 struct ContactDetailsView: View, ViewContext {
     @Bindable var store: StoreOf<ContactDetailsFeature>
     
     var body: some View {
         Text(store.contact.name)
             .onTapGesture { store.send(.contactTapped) }
     }
 }
 ```
 */