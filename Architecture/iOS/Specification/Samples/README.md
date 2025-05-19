# LifeSignal iOS Sample Implementations

**Navigation:** [Back to Application Specification](../README.md)

---

## Overview

This directory contains sample implementations of various components of the LifeSignal iOS application using The Composable Architecture (TCA). These samples serve as reference implementations and starting points for developers working on the application.

## Sample Types

### Feature Samples

The [FeatureSamples.swift](FeatureSamples.swift) file contains sample implementations of TCA features, including:

- State definitions
- Action definitions
- Reducer implementations
- Effect handling
- Dependency usage

### Client Samples

The [ClientSamples.swift](ClientSamples.swift) file contains sample implementations of client interfaces, including:

- Client interface definitions
- Live implementations
- Test implementations
- Preview implementations
- Dependency registration

### View Samples

The [ViewSamples.swift](ViewSamples.swift) file contains sample implementations of SwiftUI views using TCA, including:

- Store binding
- View composition
- Navigation and presentation
- UI components

## Usage Guidelines

These samples should be used as starting points when implementing new components for the LifeSignal iOS application. They demonstrate the recommended patterns and practices for using TCA in the context of the LifeSignal application.

When implementing a new component, start by reviewing the relevant sample and adapt it to your specific needs. This will ensure consistency across the codebase and adherence to the established architectural patterns.

## Implementation Notes

### Feature Implementation

Features should follow the TCA pattern:

```swift
@Reducer
struct FeatureName {
    @ObservableState
    struct State: Equatable, Sendable {
        // State properties
    }
    
    enum Action: Equatable, Sendable {
        // Actions
    }
    
    // Dependencies
    @Dependency(\.dependencyName) var dependencyName
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            // Action handlers
            }
        }
    }
}
```

### Client Implementation

Clients should follow the dependency injection pattern:

```swift
struct ClientName: Sendable {
    var functionName: @Sendable (Parameters) async throws -> ReturnType
    
    // Other functions
}

extension ClientName: DependencyKey {
    static var liveValue: Self {
        Self(
            functionName: { parameters in
                // Live implementation
            }
        )
    }
    
    static var testValue: Self {
        Self(
            functionName: { parameters in
                // Test implementation
            }
        )
    }
    
    static var previewValue: Self {
        Self(
            functionName: { parameters in
                // Preview implementation
            }
        )
    }
}

extension DependencyValues {
    var clientName: ClientName {
        get { self[ClientName.self] }
        set { self[ClientName.self] = newValue }
    }
}
```

### View Implementation

Views should follow the TCA pattern:

```swift
struct FeatureNameView: View {
    @Bindable var store: StoreOf<FeatureName>
    
    var body: some View {
        // View implementation
    }
}
```

## Related Documentation

For more detailed information about the LifeSignal iOS application architecture, see the following documents:

- [Architecture Overview](../ArchitectureOverview.md)
- [Project Structure](../ProjectStructure.md)
- [Feature List](../FeatureList.md)
- [Mock to Production Migration](../MockToProductionMigration.md)
- [Domain Models](../Domain/README.md)
- [Infrastructure Layer](../Infrastructure/README.md)
- [UI Guidelines](../UI/UIGuidelines.md)
