# Views

TCA-compliant SwiftUI Views integrate with The Composable Architecture using Store patterns and ViewStore management while maintaining UI/UX parity with the mock application.

## Content Structure

### UI/UX Parity
- **Same Components**: Same component hierarchy and styling as the mock application
- **Design System**: Use identical design tokens and visual styling
- **User Experience**: Maintain identical user flows and interactions
- **Only Data Flow Changes**: Only data flow and side effects change from mock version

### Modern TCA Integration
- **@ObservableState**: Use `@ObservableState` macro for automatic SwiftUI observation without ViewStore
- **Direct Store Access**: Access store state and actions directly in SwiftUI without WithViewStore wrapper
- **Sendable Conformance**: Ensure all state types conform to Sendable for Swift's strict concurrency model
- **Async/Await Effects**: Use async/await patterns in effects with proper context.Context cancellation
- **Store Scoping**: Leverage Store scoping for modular feature composition and clean boundaries
- **Type-Safe Actions**: Use case key paths and @CasePathable for type-safe action handling

### View Architecture
- **Presentation Focus**: Views exclusively handle UI presentation with zero business logic
- **Declarative UI**: Use SwiftUI's declarative patterns with modern TCA observation
- **Action-Driven**: Send semantic actions for all user interactions and lifecycle events
- **Store Observation**: Directly observe Store state with @ObservableState automatic updates
- **Concurrency Safe**: All view interactions respect Swift's strict concurrency requirements
- **Accessibility First**: Build accessibility support into all view components from the start

## Error Handling

### Error Categories
- **Effect Errors**: Async operation failures in effects with proper error action transformation and context cancellation
- **Concurrency Errors**: Swift concurrency violations, actor isolation issues, and sendable compliance failures
- **Navigation Errors**: Stack and tree navigation state inconsistencies with automatic recovery mechanisms
- **Dependency Errors**: @Dependency injection failures and client unavailability with graceful degradation patterns
- **State Consistency Errors**: Invalid state transitions and concurrent modification conflicts with atomic updates
- **Action Handling Errors**: Malformed actions, missing reducer cases, and action dispatch failures

### Recovery Strategies
- **Action-Based Error Flow**: Transform errors into semantic actions maintaining unidirectional data flow with async/await
- **State-Driven Recovery**: Reflect error states in reducer state for automatic UI updates and recovery options
- **Effect Cancellation**: Implement proper Task cancellation with cancellation IDs for resource cleanup and error recovery
- **Dependency Fallbacks**: Use test/preview dependency variants for graceful degradation during service failures
- **Structured Error Actions**: Use structured error actions with associated values for detailed error information
- **Context Propagation**: Propagate cancellation context through async effect chains for proper cleanup
- **Sendable Error Types**: Ensure all error types conform to Sendable for safe concurrent error handling
- **@Dependency Testing**: Leverage dependency injection for comprehensive error scenario testing and validation

## Testing

### Modern Reducer Testing
- **TestStore Exhaustivity**: Use exhaustive TestStore testing with modern async/await and Sendable patterns
- **Dependency Override**: Test with @Dependency overrides using withDependencies for controlled environments
- **Async Effect Testing**: Test async effects with proper Task cancellation and context propagation
- **Concurrency Compliance**: Validate Sendable conformance and strict concurrency requirements in all tests
- **State Assertion**: Use trailing closures in TestStore.send for comprehensive state change validation
- **Action Key Paths**: Leverage case key paths for simplified action dispatching and receiving in tests

### View Integration Testing
- **Direct Store Testing**: Test views with direct Store integration using @ObservableState patterns
- **Navigation Testing**: Test stack and tree-based navigation with proper store scoping and state isolation
- **Accessibility Testing**: Validate accessibility integration with TCA state management and action dispatching
- **Concurrency Integration**: Test view-store integration under Swift's strict concurrency requirements
- **Action Flow Testing**: Validate complete action flows from user interaction through reducer to state update
- **Store Scoping Validation**: Test parent-child store relationships and proper state isolation boundaries

### Preview and Visual Testing
- **TCA Preview Integration**: Use Store previews with @ObservableState for real-time design validation
- **Dependency Preview Overrides**: Override @Dependency values in previews for different UI state scenarios
- **State Scenario Previews**: Create comprehensive previews showing all possible state combinations
- **Accessibility Preview Testing**: Preview with accessibility features enabled for inclusive design validation
- **Cross-Device Preview Testing**: Test responsive design across different device sizes in previews
- **Error State Previews**: Preview error states and recovery scenarios using controlled dependency failures

### Development Testing
- **Dependency Client Testing**: Test both platform and domain client layers with proper mock implementations
- **Effect Lifecycle Testing**: Test complete effect lifecycles including cancellation and cleanup with async/await
- **Performance Profiling**: Profile @ObservableState performance and Store update patterns for optimization
- **Memory Leak Detection**: Test for memory leaks in Store lifecycle and effect management with async patterns
- **Integration Flow Testing**: Test complete user flows through multiple features with proper state isolation
- **Concurrency Stress Testing**: Test Store behavior under concurrent access patterns and high-frequency updates

## Anti-patterns

### Architecture Violations
- **Business Logic in Views**: Implementing complex business logic directly in SwiftUI views instead of delegating to reducers
- **State Mutation**: Mutating state outside of reducers bypassing unidirectional data flow and predictable state management
- **Action Misuse**: Using actions as methods for sharing logic instead of representing events that occurred
- **Side Effects in Reducers**: Implementing side effects directly in reducers instead of using Effects for asynchronous operations
- **Missing Sendable**: Not conforming state types to Sendable for concurrency safety
- **Poor Store Scoping**: Not using Store scoping for child features creating tight coupling

### Performance Issues
- **Over-observing State**: Over-observing state in views leading to unnecessary re-renders and performance degradation
- **High-frequency Actions**: Sending high-frequency actions directly to reducers without debouncing or throttling mechanisms
- **Synchronous Action Chains**: Creating synchronous action chains that immediately trigger other actions leading to complex debugging
- **Memory Leaks**: Not properly managing Store lifecycle and subscriptions leading to memory issues
- **Poor Task Management**: Not properly managing Task lifecycle in effects leading to resource leaks
- **Missing Effect Cancellation**: Not canceling long-running effects when features are dismissed

### Testing Deficiencies
- **Missing Testing**: Not implementing comprehensive testing for reducers and effects missing TCA's testability advantages
- **Poor Dependency Management**: Ignoring TCA's dependency management system for external services reducing testability and modularity
- **Insufficient Coverage**: Not testing all state transitions, error conditions, and edge cases in features
- **Integration Gaps**: Not testing view-store integration and user interaction flows comprehensively
- **Missing Async Testing**: Not properly testing async/await effects and Task lifecycle
- **Poor Concurrency Testing**: Not testing Sendable conformance and thread safety

### Design Problems
- **Monolithic Features**: Creating monolithic features that violate single responsibility principle and reduce composability
- **Poor Store Scoping**: Not using Store scoping for child features creating tight coupling and state management complexity
- **Architectural Inconsistency**: Not following TCA's architectural patterns leading to unpredictable behavior and maintenance issues
- **Complex View Logic**: Creating complex view logic that should be handled in reducers or effects
- **Missing Type Safety**: Not leveraging Swift's type system for compile-time safety in TCA integration
- **Outdated Async Patterns**: Using completion handlers instead of modern async/await in effects