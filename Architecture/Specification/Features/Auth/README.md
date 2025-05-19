# AuthFeature

**Navigation:** [Back to Feature List](../../FeatureList.md) | [State](State.md) | [Actions](Actions.md) | [Effects](Effects.md)

---

## Overview

The AuthFeature is responsible for managing user authentication in the LifeSignal iOS application. It handles phone number verification, verification code entry, and session management. The feature ensures that users can securely access the application and maintains their authentication state across app launches.

## Responsibilities

- Allow users to sign in with their phone number
- Handle verification code entry and validation
- Manage user authentication state
- Handle sign out functionality
- Provide error handling for authentication failures
- Maintain session persistence across app launches

## User Experience

The AuthFeature provides the following user experience:

1. **Phone Number Entry** - A screen where users can enter their phone number
   - Phone number is formatted according to the selected region
   - Continue button is enabled only when a valid phone number is entered
   - Error messages are displayed for invalid phone numbers

2. **Verification Code Entry** - A screen where users can enter the verification code
   - Code is sent to the user's phone number via SMS
   - Resend button is available after a timeout period
   - Error messages are displayed for invalid codes
   - Auto-verification is attempted when possible

3. **Authentication State** - The feature maintains the user's authentication state
   - Authenticated users are directed to the main application
   - Unauthenticated users are directed to the sign-in flow
   - Authentication state persists across app launches

4. **Sign Out** - Users can sign out of the application
   - Confirmation dialog is displayed before signing out
   - All user data is cleared from the device upon sign out

## Dependencies

The AuthFeature depends on the following clients:

- **AuthClient** - For authentication operations
- **UserClient** - For user profile operations after successful authentication

## Feature Composition

The AuthFeature is composed of the following child features:

- **PhoneEntryFeature** - Handles phone number entry and validation
- **VerificationFeature** - Handles verification code entry and validation

## Integration with Other Features

The AuthFeature integrates with the following features:

- **AppFeature** - The AuthFeature is a child of the AppFeature and controls access to the main application
- **ProfileFeature** - After successful authentication, user profile information is loaded

## Implementation Details

The AuthFeature is implemented using The Composable Architecture (TCA) with the following components:

- **State** - Defines the feature's state
- **Action** - Defines the actions that can be performed on the feature
- **Reducer** - Defines how the state changes in response to actions
- **View** - Displays the feature's UI and handles user interaction

For detailed implementation information, see:

- [State](State.md) - Detailed information about the feature's state
- [Actions](Actions.md) - Detailed information about the feature's actions
- [Effects](Effects.md) - Detailed information about the feature's effects

## Example Implementation

For a complete example implementation of a TCA feature, see the [FeatureExample](../../Examples/FeatureExample.md) document.

## Testing

The AuthFeature is tested using the following approach:

1. **Unit Tests** - Test the reducer logic in isolation
   - Test each action and its effect on the state
   - Test success and failure paths
   - Test edge cases and error conditions

2. **Integration Tests** - Test the feature's integration with its dependencies
   - Test authentication flow with mock dependencies
   - Test error handling with simulated failures

3. **UI Tests** - Test the feature's UI and user interactions
   - Test phone number entry and validation
   - Test verification code entry and validation
   - Test navigation between screens

## Best Practices

When working with the AuthFeature, follow these best practices:

1. **Handle Authentication Errors Gracefully** - Display user-friendly error messages
2. **Provide Clear Feedback** - Indicate when authentication is in progress
3. **Respect User Privacy** - Only request necessary permissions
4. **Optimize for Speed** - Make authentication as quick and seamless as possible
5. **Support Accessibility** - Ensure all authentication screens are accessible
6. **Test Thoroughly** - Test all authentication paths and error conditions
7. **Maintain Security** - Follow best practices for secure authentication
