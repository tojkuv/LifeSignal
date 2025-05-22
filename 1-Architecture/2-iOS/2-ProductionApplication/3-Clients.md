# Clients

TCA domain clients and platform clients implement a two-tier client architecture using @DependencyClient for platform clients and plain structs for domain clients, providing modular and testable service integration.

## Content Structure

### Two-Tier Architecture
- **Platform Clients**: Low-level wrappers (Fly.io gRPC/HTTP, Supabase DB, Supabase Storage, Keychain, etc.)
- **Domain Clients**: High-level operations like `createAccount`, `uploadProfileImage`
- **Feature Dependencies**: Features should depend only on domain clients, never directly on platform clients
- **Clear Separation**: Platform clients handle infrastructure, domain clients handle business operations

### Platform Clients
- **@DependencyClient**: Implemented as `@DependencyClient` with `live`, `preview`, `test` variants
- **Infrastructure Focus**: Handle auth headers, retries, decoding with async/await patterns
- **No Business Logic**: No business logic, only infrastructure concerns
- **Protocol-Based**: Define clear interfaces for external service interactions
- **Async/Await Integration**: Use modern Swift concurrency for all network operations
- **Type Safety**: Leverage Swift's type system for compile-time safety and error prevention

### Domain Clients
- **Plain Structs**: Implemented as plain structs injected via `DependencyValues`
- **Business Operations**: Compose multiple platform clients for business operations with async/await
- **Validation and Mapping**: Perform validation and mapping between platform and domain models
- **Platform Client Dependencies**: Depend only on platform client protocols
- **Concurrency Safety**: Follow Swift's strict concurrency requirements for thread safety
- **Error Handling**: Implement comprehensive error handling with Swift's Result and async throws patterns

### Dependency Registration
- **DependencyValues**: Register clients through `DependencyValues` extension
- **Client Protocols**: Define clear interfaces for both platform and domain clients
- **Injection Pattern**: Use `@Dependency` property wrapper for client injection
- **Test Variants**: Provide test implementations for all client types
- **Sendable Conformance**: Ensure all client types conform to Sendable for concurrency safety
- **Dependency Keys**: Use proper DependencyKey implementations for type-safe dependency registration

## Error Handling

### Error Categories
- **Network Errors**: API failures, connectivity issues, timeout errors, and service unavailability with retry mechanisms
- **Authentication Errors**: Token expiration, permission denials, and authentication failures with re-authentication flows
- **Validation Errors**: Input validation failures, business rule violations, and data format issues with contextual messaging
- **Service Errors**: External service failures, rate limiting, and integration issues with graceful degradation
- **Platform Errors**: iOS system framework errors, device capability failures, and permission denials
- **Dependency Errors**: Client initialization failures, configuration errors, and service unavailability

### Recovery Strategies
- **Effect-Based Error Flow**: Errors captured in Effects and transformed into actions maintaining unidirectional data flow
- **Result Type Integration**: Structured error handling through Result types and action-based error communication
- **Retry Mechanisms**: Automatic and user-initiated retry patterns for transient failures with exponential backoff
- **Graceful Degradation**: Fallback functionality and limited feature sets during error conditions
- **User Feedback**: Clear error messaging with actionable recovery steps and contextual information
- **Error Logging**: Comprehensive error tracking and analytics for debugging and system improvement
- **Async Error Handling**: Use async/await with proper error propagation and cancellation support
- **Task Cancellation**: Implement proper Task cancellation for network operations and long-running processes

## Testing

### Unit Testing
- **TestStore Framework**: Built-in TCA testing framework for exhaustive client and dependency validation
- **Mock Dependencies**: Controlled dependency implementations for deterministic testing scenarios and isolation
- **Dependency Testing**: Comprehensive validation of dependency injection patterns and service substitution mechanisms
- **Contract Testing**: Interface contract validation ensuring compatibility between client abstractions and implementations
- **Async Testing**: Test async/await client methods with proper Task and cancellation handling
- **Concurrency Testing**: Validate Sendable conformance and thread safety in concurrent environments

### Integration Testing
- **End-to-End Testing**: Client behavior testing with realistic service interactions and error scenarios
- **Service Integration Testing**: Testing client behavior with actual external services in controlled environments
- **Multi-Client Testing**: Testing complex workflows that involve multiple client interactions
- **Performance Testing**: Client performance analysis and optimization for production workloads and scalability
- **Async Integration**: Test async workflows and proper error propagation across client boundaries
- **Cancellation Testing**: Test Task cancellation behavior and resource cleanup in integration scenarios

### Error Handling Testing
- **Error Simulation**: Comprehensive error condition simulation for robust error handling testing
- **Recovery Testing**: Testing error recovery mechanisms and graceful degradation patterns
- **Retry Logic Testing**: Testing automatic and user-initiated retry patterns with various failure scenarios
- **Timeout Testing**: Testing client behavior under various timeout and connectivity conditions

### Development Testing
- **Dependency Injection Testing**: Test-friendly dependency substitution enabling comprehensive client testing and validation
- **Performance Profiling**: Client performance analysis and optimization tools for development debugging and validation
- **Memory Testing**: Testing proper memory management and resource cleanup in client implementations
- **Concurrency Testing**: Testing client behavior under concurrent access and Swift's strict concurrency requirements
- **Async Performance**: Profile async/await performance and identify potential bottlenecks in client operations
- **Task Lifecycle Testing**: Test proper Task creation, execution, and cancellation throughout client lifecycles

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
