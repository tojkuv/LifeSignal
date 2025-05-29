// The Swift Programming Language
// https://docs.swift.org/swift-book

/// LifeSignal Architecture Macros
/// 
/// This package provides compile-time validation and code generation for the LifeSignal architecture,
/// enforcing separation of concerns between Clients, Features, and Views.

// MARK: - Client Architecture Macro

/// Enforces client architectural constraints and generates development utilities.
///
/// Usage: Apply to client structs to validate:
/// - Proper naming convention (*Client)
/// - StateOwner implementation
/// - No client-to-client dependencies
/// - Primitive dependency access only
///
/// Generated utilities:
/// - Dependency registration helpers
/// - State mutation audit logging
/// - Performance monitoring hooks
/// - Architectural compliance validation
///
/// Example:
/// ```swift
/// @LifeSignalClient
/// struct AuthenticationClient: ClientContext {
///     static let stateKey = \.authenticationInternalState
///     // ... client implementation
/// }
/// ```
@attached(peer, names: named(validateArchitecture), named(registerDependencies), named(auditStateAccess))
public macro LifeSignalClient() = #externalMacro(module: "LifeSignalMacrosMacros", type: "LifeSignalClientMacro")

// MARK: - Feature Architecture Macro

/// Enforces feature architectural constraints and generates development utilities.
///
/// Usage: Apply to feature structs to validate:
/// - Proper naming convention (*Feature)
/// - StateReader/ClientOperator compliance
/// - No direct state mutations
/// - @Shared usage for read-only state access
/// - @Dependency usage for client access only
///
/// Generated utilities:
/// - State access helper methods
/// - Client interaction audit logging
/// - Performance tracking for client calls
/// - Architectural violation detection
/// - Safe state accessor computed properties
///
/// Example:
/// ```swift
/// @LifeSignalFeature
/// struct ContactDetailsFeature: FeatureContext {
///     @Shared(.authenticationInternalState) var authState
///     @Dependency(\.contactsClient) var contactsClient
///     // ... feature implementation
/// }
/// ```
@attached(peer, names: named(validateArchitecture), named(generateStateHelpers), named(auditClientInteractions))
public macro LifeSignalFeature() = #externalMacro(module: "LifeSignalMacrosMacros", type: "LifeSignalFeatureMacro")

// MARK: - View Architecture Macro

/// Enforces view architectural constraints and generates development utilities.
///
/// Usage: Apply to view structs to validate:
/// - Proper naming convention (*View)
/// - SwiftUI View conformance
/// - StoreOf<Feature> usage for state access
/// - store.send() pattern for actions
/// - No @Shared or @Dependency usage
///
/// Generated utilities:
/// - View binding helper methods
/// - Action dispatch audit logging
/// - Performance tracking for renders
/// - Accessibility support helpers
/// - State observation optimization
///
/// Example:
/// ```swift
/// @LifeSignalView
/// struct ContactDetailsView: View, ViewContext {
///     @Bindable var store: StoreOf<ContactDetailsFeature>
///     // ... view implementation
/// }
/// ```
@attached(peer, names: named(validateArchitecture), named(generateViewHelpers), named(auditActionDispatches))
public macro LifeSignalView() = #externalMacro(module: "LifeSignalMacrosMacros", type: "LifeSignalViewMacro")