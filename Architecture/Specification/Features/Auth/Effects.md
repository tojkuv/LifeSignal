# AuthFeature Effects

**Navigation:** [Back to AuthFeature](README.md) | [State](State.md) | [Actions](Actions.md)

---

## Overview

This document provides detailed information about the effects of the AuthFeature in the LifeSignal iOS application. Effects represent the side effects that occur in response to actions, such as API calls, timer operations, and other asynchronous operations.

## Effect Types

The AuthFeature uses the following types of effects:

1. **API Effects** - Effects that interact with external services through clients
2. **Timer Effects** - Effects that perform operations at regular intervals
3. **Navigation Effects** - Effects that handle navigation between screens
4. **Presentation Effects** - Effects that handle presentations such as alerts

## Dependencies

The AuthFeature depends on the following clients for its effects:

```swift
@Dependency(\.authClient) var authClient
@Dependency(\.userClient) var userClient
@Dependency(\.continuousClock) var clock
```

## Effect Implementation

The effects are implemented in the feature's reducer:

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .checkAuthenticationStatus:
            return .run { send in
                let isAuthenticated = await authClient.isAuthenticated()
                await send(.authenticationStatusResponse(isAuthenticated))
            }
            
        case let .authenticationStatusResponse(isAuthenticated):
            state.isAuthenticated = isAuthenticated
            return .none
            
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
            
        case .verifyCodeResponse(.success):
            state.isLoading = false
            state.isAuthenticated = true
            return .cancel(id: TimerID.self)
            
        case let .verifyCodeResponse(.failure(error)):
            state.isLoading = false
            state.error = error.localizedDescription
            return .none
            
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
            
        case .timerTick:
            if state.resendCodeTimer > 0 {
                state.resendCodeTimer -= 1
                if state.resendCodeTimer == 0 {
                    state.canResendCode = true
                    return .cancel(id: TimerID.self)
                }
            }
            return .none
            
        case .backButtonTapped:
            state.isVerificationCodeSent = false
            state.verificationCode = ""
            state.verificationID = nil
            state.canResendCode = false
            state.resendCodeTimer = 0
            return .cancel(id: TimerID.self)
            
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
            
        // Other cases...
        
        default:
            return .none
        }
    }
    .ifLet(\.$alert, action: \.alert)
}
```

## Effect Cancellation

The AuthFeature uses the following cancellation IDs:

### TimerID

Used to cancel the resend code timer:

```swift
private enum TimerID: Hashable {}

case .sendVerificationCodeResponse(.success(let verificationID)):
    // ...
    return .run { send in
        for await _ in clock.timer(interval: .seconds(1)) {
            await send(.timerTick)
        }
    }
    .cancellable(id: TimerID.self)
    
case .backButtonTapped:
    // ...
    return .cancel(id: TimerID.self)
    
case .verifyCodeResponse(.success):
    // ...
    return .cancel(id: TimerID.self)
    
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

## API Effects

The AuthFeature interacts with the following APIs:

### Authentication Status Check

Checks if the user is already authenticated:

```swift
case .checkAuthenticationStatus:
    return .run { send in
        let isAuthenticated = await authClient.isAuthenticated()
        await send(.authenticationStatusResponse(isAuthenticated))
    }
```

### Send Verification Code

Sends a verification code to the user's phone number:

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

### Verify Code

Verifies the code entered by the user:

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

### Sign Out

Signs the user out:

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
```

## Timer Effects

The AuthFeature uses the following timer effects:

### Resend Code Timer

A timer that counts down the time until the user can resend the verification code:

```swift
case .sendVerificationCodeResponse(.success(let verificationID)):
    // ...
    return .run { send in
        for await _ in clock.timer(interval: .seconds(1)) {
            await send(.timerTick)
        }
    }
    .cancellable(id: TimerID.self)
    
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

## Navigation Effects

The AuthFeature uses the following navigation effects:

### Back Navigation

Handles navigation back from the verification screen to the phone entry screen:

```swift
case .backButtonTapped:
    state.isVerificationCodeSent = false
    state.verificationCode = ""
    state.verificationID = nil
    state.canResendCode = false
    state.resendCodeTimer = 0
    return .cancel(id: TimerID.self)
```

## Presentation Effects

The AuthFeature uses the following presentation effects:

### Alert Presentation

Handles the presentation of alerts:

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

## Error Handling

The AuthFeature handles errors in the following ways:

### API Error Handling

Handles errors from API calls:

```swift
case let .sendVerificationCodeResponse(.failure(error)):
    state.isLoading = false
    state.error = error.localizedDescription
    return .none
    
case let .verifyCodeResponse(.failure(error)):
    state.isLoading = false
    state.error = error.localizedDescription
    return .none
    
case let .signOutResponse(.failure(error)):
    state.isLoading = false
    state.error = error.localizedDescription
    return .none
```

### Error Presentation

Presents errors to the user:

```swift
case let .setError(error):
    state.error = error
    return .none
    
case .dismissError:
    state.error = nil
    return .none
```

## Testing

The AuthFeature's effects are tested using the following approach:

1. **Unit Tests** - Test each effect in isolation
   - Test success and failure paths
   - Test cancellation behavior
   - Test edge cases

2. **Integration Tests** - Test the feature's integration with its dependencies
   - Test authentication flow with mock dependencies
   - Test error handling with simulated failures

Example test for the send verification code effect:

```swift
func testSendVerificationCode_Success() async {
    let store = TestStore(initialState: AuthFeature.State()) {
        AuthFeature()
    } withDependencies: {
        $0.authClient.sendVerificationCode = { _, _ in
            return "verification-id"
        }
    }
    
    await store.send(.phoneNumberChanged("1234567890")) {
        $0.phoneNumber = "1234567890"
        $0.isPhoneNumberValid = true
    }
    
    await store.send(.signInButtonTapped) {
        $0.isLoading = true
    }
    
    await store.receive(.sendVerificationCodeResponse(.success("verification-id"))) {
        $0.isLoading = false
        $0.verificationID = "verification-id"
        $0.isVerificationCodeSent = true
        $0.canResendCode = false
        $0.resendCodeTimer = 60
    }
}

func testSendVerificationCode_Failure() async {
    let error = NSError(domain: "auth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid phone number"])
    
    let store = TestStore(initialState: AuthFeature.State()) {
        AuthFeature()
    } withDependencies: {
        $0.authClient.sendVerificationCode = { _, _ in
            throw error
        }
    }
    
    await store.send(.phoneNumberChanged("1234567890")) {
        $0.phoneNumber = "1234567890"
        $0.isPhoneNumberValid = true
    }
    
    await store.send(.signInButtonTapped) {
        $0.isLoading = true
    }
    
    await store.receive(.sendVerificationCodeResponse(.failure(error))) {
        $0.isLoading = false
        $0.error = "Invalid phone number"
    }
}
```

## Best Practices

When working with the AuthFeature effects, follow these best practices:

1. **Use Dependency Injection** - Inject dependencies using TCA's dependency injection system.

2. **Handle Errors Gracefully** - Provide clear error messages and recovery paths.

3. **Cancel Long-Running Effects** - Use cancellation IDs to cancel long-running effects when they are no longer needed.

4. **Test Effects Thoroughly** - Write tests for success and failure paths, as well as cancellation behavior.

5. **Use TaskResult for Async Operations** - Use `TaskResult` for handling the results of asynchronous operations.

6. **Document Effects** - Document the purpose and behavior of each effect.

7. **Keep Effects Focused** - Each effect should have a single responsibility.

8. **Use Async/Await** - Use Swift's async/await for asynchronous operations.

9. **Capture State in Closures** - Capture the necessary state in closures to avoid state changes affecting the effect.

10. **Use Strong Typing** - Use strong typing for parameters and return values to catch errors at compile time.
