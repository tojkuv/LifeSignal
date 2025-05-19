# QRCodeFeature State

**Navigation:** [Back to QRCodeFeature](README.md) | [Actions](Actions.md) | [Effects](Effects.md)

---

## Overview

This document provides detailed information about the state of the QRCodeFeature in the LifeSignal iOS application. The state represents the current condition of the QR code functionality, including the QR code image, QR code data, and UI state.

## State Definition

```swift
@ObservableState
struct State: Equatable, Sendable {
    /// QR code data
    var qrCodeID: String = UUID().uuidString
    var qrCodeImage: UIImage? = nil
    var isGenerating: Bool = false
    var error: UserFacingError? = nil
    
    /// Child feature states
    var qrScanner: QRScannerFeature.State = .init()
    
    /// UI state
    var isShareSheetPresented: Bool = false
}
```

## State Properties

### QR Code Data

#### `qrCodeID: String`

A unique identifier for the QR code. This is used to generate the QR code image and is shared when the QR code is scanned.

#### `qrCodeImage: UIImage?`

The generated QR code image. This is displayed in the UI and can be shared with other users.

#### `isGenerating: Bool`

A boolean indicating whether the QR code is currently being generated. When true, UI elements should show loading indicators.

#### `error: UserFacingError?`

An optional error that should be displayed to the user. When non-nil, an error alert should be shown.

### Child Feature States

#### `qrScanner: QRScannerFeature.State`

The state of the QRScannerFeature, which is used to scan QR codes.

### UI State

#### `isShareSheetPresented: Bool`

A boolean indicating whether the share sheet is currently presented.

## QR Code Data

The QR code contains the following information encoded as a JSON string:

```swift
struct QRCodeData: Codable, Equatable, Sendable {
    let id: String
    let userID: String
    let timestamp: Date
    
    // Additional properties for debugging
    let appVersion: String
    let deviceModel: String
}
```

This data is encoded as a JSON string and then encoded into the QR code image.

## State Updates

The state is updated in response to actions dispatched to the feature's reducer. For detailed information on how the state is updated, see the [Actions](Actions.md) and [Effects](Effects.md) documents.

## State Persistence

The core state properties are persisted as follows:

- QR code ID is generated when needed and not persisted
- QR code image is generated on demand and not persisted
- UI state is not persisted and only exists in memory

## State Access

The state is accessed by the feature's view and by parent features that include the QRCodeFeature as a child feature.

Example of a parent feature accessing the QRCodeFeature state:

```swift
@Reducer
struct ProfileFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var qrCode: QRCodeFeature.State = .init()
        // Other state...
    }
    
    enum Action: Equatable, Sendable {
        case qrCode(QRCodeFeature.Action)
        // Other actions...
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.qrCode, action: \.qrCode) {
            QRCodeFeature()
        }
        
        Reduce { state, action in
            // Handle ProfileFeature-specific actions
            return .none
        }
    }
}
```

## Derived State

The QRCodeFeature uses derived state to present QR code data in different ways:

```swift
var qrCodeIDForDisplay: String {
    // Format the QR code ID for display (e.g., add hyphens)
    let id = qrCodeID
    guard id.count >= 32 else { return id }
    
    let index1 = id.index(id.startIndex, offsetBy: 8)
    let index2 = id.index(id.startIndex, offsetBy: 16)
    let index3 = id.index(id.startIndex, offsetBy: 24)
    
    let part1 = id[..<index1]
    let part2 = id[index1..<index2]
    let part3 = id[index2..<index3]
    let part4 = id[index3...]
    
    return "\(part1)-\(part2)-\(part3)-\(part4)"
}

var hasQRCode: Bool {
    qrCodeImage != nil
}
```

This derived state:
1. Formats the QR code ID for display with hyphens
2. Provides a boolean indicating whether a QR code image is available

## Best Practices

When working with the QRCodeFeature state, follow these best practices:

1. **Immutable Updates** - Always update state immutably through actions
2. **Computed Properties** - Use computed properties for derived state
3. **Child Feature Composition** - Use child features for complex functionality
4. **Error Handling** - Use the error property for user-facing errors
5. **Image Management** - Generate QR code images on demand and don't persist them
