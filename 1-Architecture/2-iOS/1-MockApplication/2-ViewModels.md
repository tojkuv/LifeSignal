# ViewModels

ViewModels in the iOS Mock Application serve as ObservableObject classes that embody the presentation layer within vanilla MVVM architecture. They manage UI state, handle user interactions, and provide reactive data binding between Views and business logic using simple state management patterns appropriate for rapid prototyping and development validation.

## Content Structure

### ViewModel Architecture
- **ObservableObject Protocol**: Enables automatic UI updates through objectWillChange publisher and reactive programming patterns
- **Single Responsibility**: Each ViewModel focuses on one specific view or feature with clear boundaries and focused functionality
- **Data Transformation**: Transform and format data for presentation without complex business logic
- **Lifecycle Management**: Proper memory management and resource cleanup with simple state patterns

### State Management
- **@Published Properties**: Automatic change notification system for UI-relevant state with efficient update cycles
- **Simple State Patterns**: Use basic state management appropriate for mock applications without complex flows
- **Type Safety**: Compile-time validation for published properties with explicit type declarations
- **Memory Management**: Proper subscription lifecycle management with automatic cleanup

### Data Binding
- **Property Wrapper Integration**: Use @StateObject for ViewModel ownership and @ObservedObject for observation
- **Reactive Updates**: Automatic UI invalidation triggered by @Published property changes
- **Two-way Binding**: Support for @Binding when parent-child communication is needed
- **Environment Objects**: Use @EnvironmentObject for shared state across view hierarchies when appropriate

### Mock Data Integration
- **Embedded Mock Data**: Self-contained mock data within ViewModels for independent development and testing
- **Realistic Content**: Production-like data structures and content for accurate development validation
- **Deterministic Behavior**: Predictable data states for reliable testing and development workflows
- **Type Safety**: Strongly-typed mock data with compile-time validation and error prevention

## Testing

### Unit Testing
- **ViewModel Logic Testing**: Isolated testing of ViewModel logic with mock dependencies and predictable data states
- **State Testing**: Validation of @Published property changes and state management patterns
- **Mock Data Testing**: Validation of embedded mock data consistency and realistic content generation
- **Memory Management Testing**: Subscription lifecycle validation and memory leak detection

### Integration Testing
- **View-ViewModel Integration**: End-to-end testing of ViewModel behavior with realistic data flows and user interactions
- **Data Binding Testing**: Validation that property changes correctly trigger UI updates
- **Navigation Testing**: Testing ViewModel behavior during view transitions and lifecycle events
- **State Synchronization Testing**: Testing consistent data flow across multiple views and contexts

### Development Testing
- **XCTest Framework**: Built-in testing framework for unit tests with comprehensive assertion capabilities
- **Mock Dependencies**: Test doubles for external services with predictable behavior and isolated testing
- **Preview Integration**: Testing ViewModels with SwiftUI previews for rapid development validation
- **Performance Testing**: Memory usage optimization and performance analysis for development debugging

### Combine Testing
- **Publisher Testing**: Testing reactive programming patterns with publisher/subscriber validation
- **Cancellable Management**: Testing proper subscription lifecycle with Set<AnyCancellable> for memory management
- **Async Operation Testing**: Testing asynchronous operations and data transformation patterns
- **Error Handling Testing**: Testing error propagation and recovery strategies

## Anti-patterns

### Architecture Violations
- **Massive ViewModels**: Creating ViewModels that handle multiple concerns and violate single responsibility principle
- **UI Manipulation**: Implementing direct UI manipulation within ViewModels instead of maintaining clear separation of concerns
- **Complex Business Logic**: Putting complex business logic directly in ViewModels instead of keeping them focused on presentation
- **ViewModel Dependencies**: Implementing ViewModels that directly depend on other ViewModels creating tight coupling

### State Management Issues
- **Overusing @Published**: Using @Published properties for non-UI-relevant state that creates unnecessary performance overhead
- **Complex State Patterns**: Implementing complex state management patterns inappropriate for mock applications
- **Memory Leaks**: Not implementing proper memory management leading to retain cycles and memory leaks
- **Synchronous Blocking**: Implementing synchronous operations that block the main thread and degrade user experience

### Testing Deficiencies
- **Insufficient Testing**: Not implementing comprehensive unit testing strategies for ViewModel logic and state management
- **Missing Mock Data**: Not providing realistic mock data for development and testing scenarios
- **Poor Dependency Injection**: Not leveraging dependency injection for external services reducing testability and modularity
- **Performance Ignorance**: Not testing memory usage and performance characteristics of ViewModels

### Framework Misuse
- **Fighting SwiftUI**: Implementing imperative ViewModel patterns that conflict with SwiftUI's declarative nature
- **Ignoring Combine**: Not leveraging Combine framework capabilities for reactive programming when appropriate
- **Unnecessary Complexity**: Creating unnecessary MVVM complexity for simple applications that don't require sophisticated patterns
- **Platform Ignorance**: Not following Swift and iOS development best practices for performance optimization

