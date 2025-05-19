# AuthFeature State

**Navigation:** [Back to AuthFeature](README.md) | [Actions](Actions.md) | [Effects](Effects.md)

---

## Overview

This document provides detailed information about the state of the AuthFeature in the LifeSignal iOS application. The state represents the current condition of the authentication process, including the user's authentication status, phone number, verification status, and any error conditions.

## State Definition

```swift
@ObservableState
struct State: Equatable, Sendable {
    // Core state
    var isAuthenticated: Bool = false
    var isLoading: Bool = false
    var error: String? = nil
    
    // Phone entry state
    var phoneNumber: String = ""
    var selectedRegion: Region = .unitedStates
    var isPhoneNumberValid: Bool = false
    var isVerificationCodeSent: Bool = false
    
    // Verification state
    var verificationCode: String = ""
    var isVerificationCodeValid: Bool = false
    var verificationID: String? = nil
    var canResendCode: Bool = false
    var resendCodeTimer: Int = 0
    
    // Presentation state
    @Presents var alert: AlertState<Action.Alert>?
    
    // Child feature states
    var phoneEntry: PhoneEntryFeature.State?
    var verification: VerificationFeature.State?
}
```

## State Properties

### Core State

#### `isAuthenticated: Bool`

A boolean indicating whether the user is authenticated.

**Initial Value:** `false`

**Updated When:**
- User successfully signs in
- User signs out
- App loads with existing authentication

#### `isLoading: Bool`

A boolean indicating whether an authentication operation is in progress.

**Initial Value:** `false`

**Updated When:**
- Authentication operation starts
- Authentication operation completes

#### `error: String?`

An optional string containing an error message.

**Initial Value:** `nil`

**Updated When:**
- Authentication operation fails
- Error is dismissed

### Phone Entry State

#### `phoneNumber: String`

The user's phone number.

**Initial Value:** `""`

**Updated When:**
- User enters or modifies their phone number

#### `selectedRegion: Region`

The selected region for phone number formatting.

**Initial Value:** `.unitedStates`

**Updated When:**
- User selects a different region

#### `isPhoneNumberValid: Bool`

A boolean indicating whether the entered phone number is valid.

**Initial Value:** `false`

**Updated When:**
- Phone number is validated

#### `isVerificationCodeSent: Bool`

A boolean indicating whether a verification code has been sent.

**Initial Value:** `false`

**Updated When:**
- Verification code is sent
- User returns to phone entry screen

### Verification State

#### `verificationCode: String`

The verification code entered by the user.

**Initial Value:** `""`

**Updated When:**
- User enters or modifies the verification code

#### `isVerificationCodeValid: Bool`

A boolean indicating whether the entered verification code is valid.

**Initial Value:** `false`

**Updated When:**
- Verification code is validated

#### `verificationID: String?`

An optional string containing the verification ID received from the authentication service.

**Initial Value:** `nil`

**Updated When:**
- Verification code is sent
- User returns to phone entry screen

#### `canResendCode: Bool`

A boolean indicating whether the user can resend the verification code.

**Initial Value:** `false`

**Updated When:**
- Verification code is sent
- Resend timer expires

#### `resendCodeTimer: Int`

An integer representing the remaining time (in seconds) before the user can resend the verification code.

**Initial Value:** `0`

**Updated When:**
- Verification code is sent
- Timer tick occurs

### Presentation State

#### `alert: AlertState<Action.Alert>?`

An optional alert state for displaying alerts.

**Initial Value:** `nil`

**Updated When:**
- Error occurs
- Sign out confirmation is requested
- Alert is dismissed

### Child Feature States

#### `phoneEntry: PhoneEntryFeature.State?`

An optional state for the phone entry child feature.

**Initial Value:** `nil`

**Updated When:**
- Auth feature is initialized
- User navigates between screens

#### `verification: VerificationFeature.State?`

An optional state for the verification child feature.

**Initial Value:** `nil`

**Updated When:**
- Verification code is sent
- User navigates between screens

## Computed Properties

These properties are computed from the core state and are not stored directly:

#### `isSignInButtonEnabled: Bool`

A boolean indicating whether the sign-in button should be enabled.

**Computation:**
```swift
var isSignInButtonEnabled: Bool {
    return isPhoneNumberValid && !isLoading
}
```

#### `isVerifyButtonEnabled: Bool`

A boolean indicating whether the verify button should be enabled.

**Computation:**
```swift
var isVerifyButtonEnabled: Bool {
    return isVerificationCodeValid && !isLoading
}
```

#### `formattedPhoneNumber: String`

A string containing the formatted phone number.

**Computation:**
```swift
var formattedPhoneNumber: String {
    return PhoneFormatter.format(phoneNumber, for: selectedRegion)
}
```

## State Updates

The state is updated in response to actions dispatched to the feature's reducer. For detailed information on how the state is updated, see the [Actions](Actions.md) and [Effects](Effects.md) documents.

## State Persistence

The core state properties are persisted as follows:

- `isAuthenticated` is determined by the authentication service's session state
- Other properties are not persisted and only exist in memory

## State Access

The state is accessed by the feature's view and by parent features that include the AuthFeature as a child feature.

Example of a parent feature accessing the AuthFeature state:

```swift
struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>
    
    var body: some View {
        Group {
            if !store.auth.isAuthenticated {
                AuthView(
                    store: store.scope(
                        state: \.auth,
                        action: \.auth
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
                MainTabView(
                    store: store.scope(
                        state: \.mainTab,
                        action: \.mainTab
                    )
                )
            }
        }
    }
}
```

## Best Practices

When working with the AuthFeature state, follow these best practices:

1. **Use Computed Properties for Derived State** - Use computed properties for state that can be derived from other state properties.

2. **Keep State Minimal** - Only include properties that are necessary for the feature's functionality.

3. **Use Optional Properties Appropriately** - Use optional properties for state that may not be available, such as `error` and `verificationID`.

4. **Use Presentation Properties for Presentations** - Use `@Presents` properties for managing presentations, such as alerts.

5. **Document State Properties** - Document the purpose and usage of each state property.

6. **Handle State Transitions Carefully** - Ensure that state transitions are handled correctly, especially when navigating between screens.

7. **Validate State** - Validate state properties to ensure they are in a valid state, such as validating phone numbers and verification codes.

8. **Protect Sensitive Information** - Do not store sensitive information, such as verification codes, longer than necessary.
