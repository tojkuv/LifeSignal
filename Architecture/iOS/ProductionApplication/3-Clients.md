# Clients

The Composable Architecture implements a modern two-layer client architecture with platform clients handling infrastructure concerns and domain clients managing business operations. This separation provides clean abstraction boundaries, enhanced testability, and maintainable service integration using @Dependency and @DependencyClient patterns.

## Content Structure

### Modern Two-Layer Architecture
- **Platform Layer**: Infrastructure clients using @DependencyClient with live/preview/test implementations for external services
- **Domain Layer**: Business operation clients using plain structs with @Dependency injection for high-level operations
- **Feature Isolation**: Features depend exclusively on domain clients, never directly accessing platform layer clients
- **Clean Boundaries**: Platform layer handles protocols and networking; domain layer handles business logic and validation
- **Dependency Composition**: Domain clients compose multiple platform clients for complex business operations
- **Type Safety**: Both layers leverage Swift's type system and strict concurrency for compile-time safety

### Platform Client Layer
- **@DependencyClient Macro**: Use @DependencyClient for automatic test/preview implementation generation with unimplemented placeholders
- **Infrastructure Responsibilities**: Handle networking protocols, authentication headers, retry logic, and response decoding
- **Async/Await Patterns**: All network operations use async/await with proper Task cancellation and context propagation
- **Sendable Conformance**: All client types conform to Sendable for safe concurrent access across isolation boundaries
- **Protocol Definitions**: Clear interface contracts defining service capabilities without implementation details
- **Environment Variants**: Live implementations for production, preview implementations for design, test implementations for validation

### Domain Client Layer
- **Plain Struct Implementation**: Simple structs with closure properties injected through @Dependency for clean composition
- **Business Operation Focus**: Coordinate multiple platform clients to fulfill high-level business operations and user workflows
- **Model Transformation**: Handle mapping between platform data models and domain business models with validation
- **Error Translation**: Transform platform errors into domain-specific errors with appropriate user messaging and recovery
- **Async Composition**: Compose async operations from multiple platform clients with proper error handling and cancellation
- **Platform Independence**: Depend only on platform client protocols, not concrete implementations, for clean abstraction

### Modern Dependency Integration
- **@Dependency Registration**: Register both client layers through DependencyValues extensions with proper key conformance
- **Type-Safe Injection**: Use @Dependency property wrapper for automatic client injection with compile-time safety
- **Environment-Specific Variants**: Platform clients provide live/preview/test variants; domain clients compose these appropriately
- **Sendable Client Types**: All client implementations conform to Sendable for safe access across concurrency boundaries
- **withDependencies Testing**: Override client behavior in tests using withDependencies for controlled testing environments
- **Clean Dependency Keys**: Implement proper DependencyKey conformance for type-safe registration and lookup

## Error Handling

### Modern Error Categories
- **Platform Client Errors**: Network failures, authentication issues, and service unavailability at the infrastructure layer
- **Domain Client Errors**: Business logic validation failures and operation-specific error conditions
- **Dependency Injection Errors**: @DependencyClient initialization failures and missing dependency configurations
- **Concurrency Errors**: Swift strict concurrency violations and actor isolation boundary issues
- **Async Operation Errors**: Task cancellation, timeout failures, and context propagation issues
- **Client Composition Errors**: Failures when composing multiple platform clients in domain operations

### Modern Recovery Strategies
- **Action-Based Error Transformation**: Transform client errors into semantic actions for proper reducer processing
- **Dependency Fallback Systems**: Use test/preview client variants for graceful degradation during service failures
- **Async Error Propagation**: Proper async/await error handling with Task cancellation and context management
- **Client Error Mapping**: Map platform errors to domain errors with appropriate user messaging and recovery actions
- **Retry with Cancellation**: Implement retry mechanisms with proper Task cancellation and exponential backoff
- **Dependency Override Recovery**: Use withDependencies for error simulation and recovery testing scenarios
- **Concurrent Error Isolation**: Handle errors in concurrent client operations with proper isolation and cleanup
- **Client Health Monitoring**: Monitor client health and automatically switch to fallback implementations when needed

## Testing

### Modern Unit Testing
- **@DependencyClient Testing**: Test both platform and domain clients with @DependencyClient unimplemented variants
- **withDependencies Override**: Use withDependencies for complete client behavior control in isolated test environments
- **Async/Await Testing**: Test async client methods with proper Task lifecycle and cancellation context validation
- **Sendable Compliance Testing**: Validate client types conform to Sendable for safe concurrent access patterns
- **Client Contract Testing**: Verify platform client contracts match domain client expectations and business requirements
- **Error Scenario Testing**: Test comprehensive error scenarios using dependency overrides and controlled failure conditions

### Modern Integration Testing
- **Two-Layer Integration**: Test complete workflows through domain clients that compose multiple platform clients
- **Dependency Chain Testing**: Validate dependency injection chains from features through domain to platform clients
- **Async Operation Integration**: Test complex async workflows with proper cancellation propagation and cleanup
- **Client Composition Testing**: Test domain clients that coordinate multiple platform clients for business operations
- **Performance Integration**: Test client performance under realistic load with proper resource management
- **Concurrency Integration**: Test client behavior under concurrent access patterns and Swift strict concurrency

### Modern Error Testing
- **Dependency Error Simulation**: Use withDependencies to simulate various error conditions at both client layers
- **Client Fallback Testing**: Test automatic fallback to preview/test client implementations during failures
- **Async Error Propagation**: Test error propagation through async effect chains with proper cancellation handling
- **Client Error Mapping**: Test error transformation from platform errors to domain errors with proper messaging

### Modern Development Testing
- **Client Architecture Validation**: Test two-layer architecture boundaries and ensure proper separation of concerns
- **@Dependency Performance**: Profile dependency injection performance and client instantiation overhead
- **Async Task Management**: Test Task lifecycle management in client operations with proper cancellation and cleanup
- **Sendable Performance**: Profile Sendable conformance impact on client performance and memory usage
- **Client Memory Management**: Test for memory leaks in client implementations and dependency injection patterns
- **Concurrency Stress Testing**: Test clients under high-concurrency scenarios with proper isolation and safety

## Anti-patterns

### Dependency Management Issues
- **Global Singletons**: Using global singletons or hardcoded dependencies instead of dependency injection reducing testability and modularity
- **Missing Test Implementations**: Omitting test implementations leading to flaky, slow, and non-deterministic tests with external dependencies
- **Circular Dependencies**: Creating circular dependencies between clients causing initialization issues and architectural complexity
- **Poor Injection Patterns**: Not following TCA's dependency management patterns leading to unpredictable behavior and maintenance issues

### Architecture Violations
- **Business Logic in Clients**: Implementing complex business logic directly in client implementations instead of delegating to domain services
- **Business Logic in Effects**: Putting business logic in Effects instead of reducers violating TCA's architectural principles
- **Tight Coupling**: Creating tightly coupled client implementations that depend on internal details of other clients
- **Complex Protocol Hierarchies**: Using overly complex protocol hierarchies for simple clients when struct-based interfaces would be more ergonomic

### Error Handling Deficiencies
- **Poor Error Handling**: Not implementing proper error handling leading to poor user experience and difficult debugging
- **Missing Error Recovery**: Not implementing comprehensive error recovery strategies for robust user experience
- **Inadequate Error Testing**: Not testing all error conditions and recovery mechanisms comprehensively
- **Poor Error Communication**: Not providing clear error messaging and actionable recovery steps to users

### Testing and Performance Issues
- **Insufficient Testing**: Not implementing comprehensive testing for client behavior and dependency injection patterns
- **Performance Ignorance**: Ignoring performance considerations for client operations leading to poor user experience
- **Concurrency Issues**: Not following Swift and iOS development best practices for concurrency safety and resource management
- **Memory Leaks**: Not implementing proper resource management and cleanup for long-running services and connections
- **Poor Async Patterns**: Using outdated completion handler patterns instead of modern async/await
- **Missing Sendable**: Not conforming to Sendable protocol for types used across concurrency boundaries
- **Task Mismanagement**: Not properly managing Task lifecycle, leading to resource leaks and cancellation issues
