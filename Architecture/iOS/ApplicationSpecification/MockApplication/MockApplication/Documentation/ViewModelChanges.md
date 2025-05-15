# View Model Changes for TCA Migration

This document outlines the changes made to view models in the MockApplication to better support future migration to The Composable Architecture (TCA).

## General Principles

1. **State Separation**: View models now clearly separate state (published properties) from actions (methods).
2. **Dependency Injection**: View models accept dependencies through initializers rather than creating them internally.
3. **Weak Self References**: All closures use `[weak self]` to prevent retain cycles.
4. **Consistent Naming**: Method names follow a consistent pattern that will map well to TCA actions.
5. **Model Reuse**: Duplicate model definitions have been removed in favor of importing shared models.

## Specific Changes

### QRCodeShareView

- Created a dedicated `QRCodeShareView` that renders QR codes with additional information.
- This view will map directly to a TCA component in the future.

### Contact Model

- Removed duplicate `Contact` model definitions.
- Used module imports to reference the shared `Contact` model.
- This prepares for a future where models will be defined in a shared domain layer.

### HomeShareImage

- Consolidated duplicate `HomeShareImage` definitions.
- Changed from a struct to an enum with associated values for better type safety.
- This pattern aligns with TCA's preference for enums with associated values.

### QRCodeViewModel

- Updated the `generateQRCodeImage` static method to properly render SwiftUI views.
- This method now follows a more functional approach with completion handlers.

## Future TCA Migration Path

When migrating to TCA, the following transformations will be applied:

1. View model state properties → TCA `State` struct
2. View model methods → TCA `Action` enum cases
3. View model dependencies → TCA `@Dependency` properties
4. View model side effects → TCA `Effect` values

For example, the `HomeViewModel` would become:

```swift
@Reducer
struct HomeFeature {
    @ObservableState
    struct State {
        var showQRScanner: Bool = false
        var showIntervalPicker: Bool = false
        // ... other state properties
    }
    
    enum Action {
        case generateQRCodeImage
        case qrCodeImageGenerated(UIImage?)
        case shareQRCode
        // ... other actions
    }
    
    @Dependency(\.qrCodeClient) var qrCodeClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .generateQRCodeImage:
                // Implementation
                return .none
                
            // ... other action handlers
            }
        }
    }
}
```

This structure maintains the separation of concerns while providing a clear migration path to TCA.
