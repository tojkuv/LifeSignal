# AuthFeature Actions

**Navigation:** [Back to AuthFeature](README.md) | [State](State.md) | [Effects](Effects.md)

---

## Overview

This document provides detailed information about the actions of the AuthFeature in the LifeSignal iOS application. Actions represent the events that can occur in the feature, including user interactions, system events, and responses from external dependencies.

## Action Definition

```swift
enum Action: Equatable, Sendable {
    // User actions
    case phoneNumberChanged(String)
    case regionChanged(Region)
    case signInButtonTapped
    case verificationCodeChanged(String)
    case verifyButtonTapped
    case resendCodeButtonTapped
    case signOutButtonTapped
    case debugSignInButtonTapped
    
    // System actions
    case checkAuthenticationStatus
    case authenticationStatusResponse(Bool)
    case sendVerificationCodeResponse(TaskResult<String>)
    case verifyCodeResponse(TaskResult<Void>)
    case signOutResponse(TaskResult<Void>)
    case timerTick
    
    // Navigation actions
    case backButtonTapped
    
    // Presentation actions
    case alert(PresentationAction<Alert>)
    
    // Child feature actions
    case phoneEntry(PhoneEntryFeature.Action)
    case verification(VerificationFeature.Action)
    
    // Error handling
    case setError(String?)
    case dismissError
    
    // Alert actions
    enum Alert: Equatable, Sendable {
        case confirmSignOut
        case dismissSignOutConfirmation
    }
}
```

## Action Categories

### User Actions

These actions are triggered by user interactions with the UI.

#### `phoneNumberChanged(String)`

Triggered when the user changes the phone number input.

**Parameters:**
- `String` - The new phone number value

**Effect:**
- Updates the `phoneNumber` state
- Validates the phone number
- Updates the `isPhoneNumberValid` state

**Example:**
```swift
case let .phoneNumberChanged(phoneNumber):
    state.phoneNumber = phoneNumber
    state.isPhoneNumberValid = PhoneValidator.isValid(phoneNumber, for: state.selectedRegion)
    return .none
```

#### `regionChanged(Region)`

Triggered when the user changes the region selection.

**Parameters:**
- `Region` - The new selected region

**Effect:**
- Updates the `selectedRegion` state
- Revalidates the phone number
- Updates the `isPhoneNumberValid` state

**Example:**
```swift
case let .regionChanged(region):
    state.selectedRegion = region
    state.isPhoneNumberValid = PhoneValidator.isValid(state.phoneNumber, for: region)
    return .none
```

#### `signInButtonTapped`

Triggered when the user taps the sign-in button.

**Effect:**
- Sets `isLoading` to true
- Sends a verification code to the phone number
- Transitions to the verification screen if successful

**Example:**
```swift
case .signInButtonTapped:
    state.isLoading = true
    return .run { [phoneNumber = state.phoneNumber, region = state.selectedRegion] send in
        do {
            let verificationID = try await authClient.sendVerificationCode(
                to: phoneNumber,
                region: region
            )
            await send(.sendVerificationCodeResponse(.success(verificationID)))
        } catch {
            await send(.sendVerificationCodeResponse(.failure(error)))
        }
    }
```

#### `verificationCodeChanged(String)`

Triggered when the user changes the verification code input.

**Parameters:**
- `String` - The new verification code value

**Effect:**
- Updates the `verificationCode` state
- Validates the verification code
- Updates the `isVerificationCodeValid` state

**Example:**
```swift
case let .verificationCodeChanged(code):
    state.verificationCode = code
    state.isVerificationCodeValid = code.count == 6 && code.allSatisfy { $0.isNumber }
    return .none
```

#### `verifyButtonTapped`

Triggered when the user taps the verify button.

**Effect:**
- Sets `isLoading` to true
- Verifies the code with the authentication service
- Sets `isAuthenticated` to true if successful

**Example:**
```swift
case .verifyButtonTapped:
    state.isLoading = true
    return .run { [code = state.verificationCode, verificationID = state.verificationID ?? ""] send in
        do {
            try await authClient.verifyCode(code, verificationID: verificationID)
            await send(.verifyCodeResponse(.success(())))
        } catch {
            await send(.verifyCodeResponse(.failure(error)))
        }
    }
```

#### `resendCodeButtonTapped`

Triggered when the user taps the resend code button.

**Effect:**
- Sets `isLoading` to true
- Resends a verification code to the phone number
- Updates the `verificationID` state if successful
- Resets the resend code timer

**Example:**
```swift
case .resendCodeButtonTapped:
    state.isLoading = true
    return .run { [phoneNumber = state.phoneNumber, region = state.selectedRegion] send in
        do {
            let verificationID = try await authClient.sendVerificationCode(
                to: phoneNumber,
                region: region
            )
            await send(.sendVerificationCodeResponse(.success(verificationID)))
        } catch {
            await send(.sendVerificationCodeResponse(.failure(error)))
        }
    }
```

#### `signOutButtonTapped`

Triggered when the user taps the sign-out button.

**Effect:**
- Displays a confirmation alert

**Example:**
```swift
case .signOutButtonTapped:
    state.alert = AlertState {
        TextState("Sign Out")
    } actions: {
        ButtonState(role: .destructive, action: .confirmSignOut) {
            TextState("Sign Out")
        }
        ButtonState(role: .cancel, action: .dismissSignOutConfirmation) {
            TextState("Cancel")
        }
    } message: {
        TextState("Are you sure you want to sign out?")
    }
    return .none
```

#### `debugSignInButtonTapped`

Triggered when the user taps the debug sign-in button (only available in debug builds).

**Effect:**
- Sets `isAuthenticated` to true without going through the normal authentication flow

**Example:**
```swift
case .debugSignInButtonTapped:
    state.isAuthenticated = true
    return .none
```

### System Actions

These actions are triggered by system events or responses from external dependencies.

#### `checkAuthenticationStatus`

Triggered when the feature is initialized to check the current authentication status.

**Effect:**
- Checks if the user is already authenticated
- Updates the `isAuthenticated` state accordingly

**Example:**
```swift
case .checkAuthenticationStatus:
    return .run { send in
        let isAuthenticated = await authClient.isAuthenticated()
        await send(.authenticationStatusResponse(isAuthenticated))
    }
```

#### `authenticationStatusResponse(Bool)`

Triggered when the authentication status check completes.

**Parameters:**
- `Bool` - Whether the user is authenticated

**Effect:**
- Updates the `isAuthenticated` state

**Example:**
```swift
case let .authenticationStatusResponse(isAuthenticated):
    state.isAuthenticated = isAuthenticated
    return .none
```

#### `sendVerificationCodeResponse(TaskResult<String>)`

Triggered when the send verification code operation completes.

**Parameters:**
- `TaskResult<String>` - The result of the operation, containing the verification ID or an error

**Effect:**
- Sets `isLoading` to false
- Updates the `verificationID` state if successful
- Sets `isVerificationCodeSent` to true if successful
- Sets `error` if the operation failed
- Initializes the resend code timer

**Example:**
```swift
case let .sendVerificationCodeResponse(.success(verificationID)):
    state.isLoading = false
    state.verificationID = verificationID
    state.isVerificationCodeSent = true
    state.canResendCode = false
    state.resendCodeTimer = 60
    return .run { send in
        for await _ in clock.timer(interval: .seconds(1)) {
            await send(.timerTick)
        }
    }
    .cancellable(id: TimerID.self)
    
case let .sendVerificationCodeResponse(.failure(error)):
    state.isLoading = false
    state.error = error.localizedDescription
    return .none
```

#### `verifyCodeResponse(TaskResult<Void>)`

Triggered when the verify code operation completes.

**Parameters:**
- `TaskResult<Void>` - The result of the operation, containing success or an error

**Effect:**
- Sets `isLoading` to false
- Sets `isAuthenticated` to true if successful
- Sets `error` if the operation failed

**Example:**
```swift
case .verifyCodeResponse(.success):
    state.isLoading = false
    state.isAuthenticated = true
    return .cancel(id: TimerID.self)
    
case let .verifyCodeResponse(.failure(error)):
    state.isLoading = false
    state.error = error.localizedDescription
    return .none
```

#### `signOutResponse(TaskResult<Void>)`

Triggered when the sign-out operation completes.

**Parameters:**
- `TaskResult<Void>` - The result of the operation, containing success or an error

**Effect:**
- Sets `isLoading` to false
- Sets `isAuthenticated` to false if successful
- Sets `error` if the operation failed
- Resets the feature state

**Example:**
```swift
case .signOutResponse(.success):
    state.isLoading = false
    state.isAuthenticated = false
    state.phoneNumber = ""
    state.verificationCode = ""
    state.verificationID = nil
    state.isVerificationCodeSent = false
    return .none
    
case let .signOutResponse(.failure(error)):
    state.isLoading = false
    state.error = error.localizedDescription
    return .none
```

#### `timerTick`

Triggered every second when the resend code timer is active.

**Effect:**
- Decrements the `resendCodeTimer` state
- Sets `canResendCode` to true when the timer reaches 0
- Cancels the timer when it reaches 0

**Example:**
```swift
case .timerTick:
    if state.resendCodeTimer > 0 {
        state.resendCodeTimer -= 1
        if state.resendCodeTimer == 0 {
            state.canResendCode = true
            return .cancel(id: TimerID.self)
        }
    }
    return .none
```

### Navigation Actions

These actions are triggered by navigation events.

#### `backButtonTapped`

Triggered when the user taps the back button in the verification screen.

**Effect:**
- Sets `isVerificationCodeSent` to false
- Resets the verification state
- Cancels the resend code timer

**Example:**
```swift
case .backButtonTapped:
    state.isVerificationCodeSent = false
    state.verificationCode = ""
    state.verificationID = nil
    state.canResendCode = false
    state.resendCodeTimer = 0
    return .cancel(id: TimerID.self)
```

### Presentation Actions

These actions are related to presentations such as alerts, sheets, and popovers.

#### `alert(PresentationAction<Alert>)`

Triggered by alert-related actions.

**Parameters:**
- `PresentationAction<Alert>` - The presentation action

**Effect:**
- Handles alert presentation and dismissal

**Example:**
```swift
case .alert(.presented(.confirmSignOut)):
    state.alert = nil
    state.isLoading = true
    return .run { send in
        do {
            try await authClient.signOut()
            await send(.signOutResponse(.success(())))
        } catch {
            await send(.signOutResponse(.failure(error)))
        }
    }
    
case .alert(.presented(.dismissSignOutConfirmation)):
    state.alert = nil
    return .none
    
case .alert(.dismiss):
    state.alert = nil
    return .none
```

### Child Feature Actions

These actions are related to child features.

#### `phoneEntry(PhoneEntryFeature.Action)`

Triggered by actions from the phone entry child feature.

**Parameters:**
- `PhoneEntryFeature.Action` - The action from the phone entry feature

**Effect:**
- Delegates to the phone entry feature's reducer

**Example:**
```swift
case let .phoneEntry(action):
    return .none
```

#### `verification(VerificationFeature.Action)`

Triggered by actions from the verification child feature.

**Parameters:**
- `VerificationFeature.Action` - The action from the verification feature

**Effect:**
- Delegates to the verification feature's reducer

**Example:**
```swift
case let .verification(action):
    return .none
```

### Error Handling Actions

These actions are related to error handling.

#### `setError(String?)`

Triggered to set an error message.

**Parameters:**
- `String?` - The error message or nil to clear the error

**Effect:**
- Updates the `error` state

**Example:**
```swift
case let .setError(error):
    state.error = error
    return .none
```

#### `dismissError`

Triggered to dismiss the current error.

**Effect:**
- Sets `error` to nil

**Example:**
```swift
case .dismissError:
    state.error = nil
    return .none
```

## Action Handling

Actions are handled by the feature's reducer, which defines how the state changes in response to actions and what effects are executed.

For detailed information on how actions are handled, see the [Effects](Effects.md) document.

## Best Practices

When working with the AuthFeature actions, follow these best practices:

1. **Group Actions by Category** - Group actions into categories such as user actions, system actions, and presentation actions.

2. **Use Descriptive Action Names** - Use descriptive names that clearly indicate the action's purpose.

3. **Use TaskResult for Async Operations** - Use `TaskResult` for handling the results of asynchronous operations.

4. **Handle Errors Gracefully** - Provide clear error messages and recovery paths.

5. **Use Presentation Actions** - Use presentation actions for managing alerts, sheets, and popovers.

6. **Document Actions** - Document the purpose, parameters, and effects of each action.

7. **Test Actions** - Write tests for each action to ensure correct behavior.
