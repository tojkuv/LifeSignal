# ViewModels

ViewModels use `ObservableObject` with `@Published` properties to manage UI state for individual screens and features in the iOS mock application.

## Content Structure

### ViewModel Structure
- **ObservableObject**: Use `ObservableObject` with `@Published` properties for reactive state
- **One Per Screen**: Each ViewModel serves one screen/feature with focused responsibility
- **UI State Only**: Contain only UI state, no network or service logic
- **No Dependencies**: No dependency injection or abstractions for mock applications

### State Management
- **@Published Properties**: Use `@Published` for properties that trigger UI updates
- **Simple State**: Keep state simple and focused on UI presentation needs
- **Local Data**: Use hard-coded data and simple state transformations
- **Memory Management**: Proper cleanup and lifecycle management

### Data Sources
- **Hard-coded Data**: Use hard-coded structs, enums, or JSON literals for data
- **Async Simulation**: Simulate async operations with `DispatchQueue.main.asyncAfter`
- **No Persistence**: Data resets on app launch; no persistence layer
- **Realistic Content**: Use production-like data structures for validation

### Integration Patterns
- **@StateObject**: Use `@StateObject` for ViewModel ownership in views
- **@ObservedObject**: Use `@ObservedObject` for ViewModel observation
- **Simple Binding**: Keep data binding patterns simple and straightforward
- **No Complex Flow**: Avoid complex state flows or business logic

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

