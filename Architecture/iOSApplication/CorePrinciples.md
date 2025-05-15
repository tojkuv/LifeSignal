# Core Architecture Principles

**Navigation:** [Back to iOS Architecture](README.md) | [TCA Implementation](TCAImplementation.md) | [Modern TCA Architecture](ComposableArchitecture.md) | [Feature Architecture](FeatureArchitecture.md)

---

> **Note:** As this is an MVP, these principles may evolve as the project matures.

## Fundamental Principles

### 1. Infrastructure Agnosticism

- All application code should be independent of specific backend technologies
- No Firebase (or other backend) types should leak into feature code
- Use infrastructure-agnostic protocols and adapters to abstract backend details
- Enable switching between different backends (Firebase, Supabase, etc.) without changing application code

### 2. Type Safety

- All interfaces between layers should use strongly-typed Swift types
- Avoid using `Any` or optional types when possible
- Use enums with associated values for representing different states
- Ensure all types are `Equatable` and `Sendable`
- Use property wrappers for validation and transformation

### 3. Concurrency Safety

- Use structured concurrency (`async/await`) for all asynchronous code
- Ensure all shared state is thread-safe
- Use actors for state that needs synchronization
- Implement proper cancellation for long-running tasks
- Use task groups for parallel operations
- Avoid blocking the main thread

### 4. Separation of Concerns

- Separate domain logic from infrastructure concerns
- Separate UI logic from business logic
- Separate state management from side effects
- Use clear boundaries between different layers of the application
- Follow the single responsibility principle

### 5. Testability

- Design all components to be testable in isolation
- Use dependency injection for all external dependencies
- Provide test implementations for all dependencies
- Test both success and failure paths
- Use TCA's `TestStore` for predictable state testing

### 6. Vertical Slice Architecture

- Organize code by feature rather than by technical layer
- Each feature should be self-contained and independent
- Features should communicate through well-defined interfaces
- Features should depend on infrastructure clients, not directly on infrastructure
- Features should be composable with other features

## Design Patterns

### 1. Dependency Injection

- Use `@Dependency` property wrapper for all dependencies
- Define dependencies as protocols or struct-based clients with closure properties
- Use `@DependencyClient` macro for client definitions
- Provide default values for non-throwing closures in client definitions
- Register dependencies with `DependencyValues` extension

### 2. Adapter Pattern

- Use adapters to connect infrastructure-agnostic interfaces to specific backend implementations
- Implement adapter interfaces for each backend
- Use mappers to convert between domain models and backend-specific types
- Handle backend-specific error mapping
- Provide proper resource cleanup

### 3. Repository Pattern

- Use repositories to abstract data access
- Repositories should use infrastructure-agnostic interfaces
- Repositories should return domain models, not DTOs
- Repositories should handle caching and offline access
- Repositories should provide real-time updates when needed

### 4. Mapper Pattern

- Use mappers to convert between domain models and DTOs
- Mappers should be pure functions
- Mappers should handle validation and transformation
- Mappers should be testable in isolation
- Mappers should handle error cases gracefully

### 5. Factory Pattern

- Use factories to create complex objects
- Factories should use dependency injection
- Factories should be testable in isolation
- Factories should handle error cases gracefully
- Factories should provide default values when appropriate

## Implementation Guidelines

### 1. Domain Models

- Domain models should be pure Swift types with no infrastructure dependencies
- Use value types (`struct`) for all models
- Ensure all types are `Sendable` and `Equatable`
- Never use `Any` or `nil` in model definitions - prefer strongly typed enums with associated values
- Use property wrappers for validation and transformation
- Implement custom `Codable` conformance when needed for complex types

### 2. Infrastructure Interfaces

- Define clear, infrastructure-agnostic interfaces
- Use domain models and DTOs, not backend-specific types
- Include proper error handling and concurrency support
- Use protocol composition for specialized capabilities
- Define clear lifecycle methods (initialize, terminate)
- Support configuration through dependency injection
- Provide monitoring and logging hooks

### 3. Error Handling

- Define domain-specific error types
- Map infrastructure errors to domain errors
- Use structured error handling with `Result` and `throws`
- Provide clear error messages and recovery suggestions
- Log errors appropriately
- Implement retry strategies for transient errors
- Handle offline scenarios gracefully

### 4. Logging and Monitoring

- Use structured logging
- Log at appropriate levels (debug, info, warning, error)
- Include context in log messages
- Use correlation IDs for tracking requests
- Monitor performance and errors
- Implement proper error reporting
- Use analytics for user behavior tracking
