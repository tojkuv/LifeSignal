# TCA Migration Guide for MockApplication

This document provides guidance for migrating the MockApplication from vanilla Swift to The Composable Architecture (TCA).

## Current Structure

The MockApplication currently uses a traditional MVVM architecture with:

1. **View Models**: ObservableObject classes with @Published properties
2. **Views**: SwiftUI views that use @EnvironmentObject or @StateObject to reference view models
3. **Models**: Simple structs for data representation

## View Model Updates

We've updated the view models to better align with TCA patterns:

1. **AppViewModel** (formerly AppState): Mirrors the structure of AppFeature.State in TCA
2. **UserViewModel**: Mirrors the structure of UserFeature.State in TCA
3. **CheckInViewModel**: Mirrors the structure of CheckInFeature.State in TCA
4. **MainTabViewModel**: Mirrors the structure of TabFeature.State in TCA

## Migration Steps

### 1. Convert View Models to TCA State

For each view model, create a corresponding TCA feature with a State struct:

```swift
@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var isAuthenticated: Bool = false
        var needsOnboarding: Bool = false
        var isActive: Bool = true
        var error: String? = nil
        var isLoading: Bool = false
        
        @Presents var contactDetails: ContactDetailsSheetViewFeature.State?
    }
    
    // ...
}
```

### 2. Convert Methods to TCA Actions

For each method in a view model, create a corresponding TCA action:

```swift
enum Action: Equatable, Sendable {
    case signIn
    case completeOnboarding
    case signOut
    case setError(String?)
    case setLoading(Bool)
    case contactDetails(PresentationAction<ContactDetailsSheetViewFeature.Action>)
}
```

### 3. Implement Reducers

Implement the reducer logic for each feature:

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .signIn:
            state.isAuthenticated = true
            state.needsOnboarding = true
            return .none
            
        case .completeOnboarding:
            state.needsOnboarding = false
            return .none
            
        case .signOut:
            state.isAuthenticated = false
            state.needsOnboarding = false
            return .none
            
        case let .setError(error):
            state.error = error
            return .none
            
        case let .setLoading(isLoading):
            state.isLoading = isLoading
            return .none
            
        case .contactDetails:
            return .none
        }
    }
}
```

### 4. Update Views to Use TCA Store

Update each view to use a TCA store instead of view models:

```swift
struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>
    
    var body: some View {
        Group {
            if !store.isAuthenticated {
                SignInView(
                    store: store.scope(
                        state: \.signIn,
                        action: \.signIn
                    )
                )
            } else if store.needsOnboarding {
                OnboardingView(
                    store: store.scope(
                        state: \.onboarding,
                        action: \.onboarding
                    )
                )
            } else {
                ContentView(
                    store: store.scope(
                        state: \.content,
                        action: \.content
                    )
                )
            }
        }
    }
}
```

### 5. Add Dependencies

Replace direct service calls with TCA dependencies:

```swift
@Dependency(\.userClient) var userClient
@Dependency(\.authClient) var authClient

// In reducer:
case .signIn:
    state.isLoading = true
    return .run { send in
        do {
            let result = try await authClient.signIn()
            await send(.signInResponse(.success(result)))
        } catch {
            await send(.signInResponse(.failure(error)))
        }
    }
```

## Best Practices

1. **State Management**: Use @ObservableState for all state structs
2. **Presentation**: Use @Presents for presentation state
3. **Shared State**: Use @Shared for state that needs to be shared across features
4. **Dependencies**: Use @Dependency for all external dependencies
5. **Testing**: Write tests for each reducer to ensure correct behavior

## Migration Order

1. Start with core domain models and clients
2. Implement infrastructure layer with dependencies
3. Create base features (AppFeature, UserFeature)
4. Implement child features (TabFeatures, etc.)
5. Update views to use TCA stores

## Resources

- [TCA Documentation](https://github.com/pointfreeco/swift-composable-architecture)
- [TCA Dependencies](https://github.com/pointfreeco/swift-dependencies)
- [TCA Best Practices](https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/bestpractices)
