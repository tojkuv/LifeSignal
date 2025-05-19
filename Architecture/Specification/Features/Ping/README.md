# PingFeature

**Navigation:** [Back to Feature List](../../FeatureList.md) | [State](State.md) | [Actions](Actions.md) | [Effects](Effects.md)

---

## Overview

The PingFeature is responsible for managing ping functionality in the LifeSignal iOS application. It allows responders to ping dependents who are non-responsive, and it allows users to respond to pings from their responders. The feature is designed to facilitate communication between users in situations where a dependent may be at risk.

## Responsibilities

- Allow responders to ping non-responsive dependents
- Allow users to respond to pings from responders
- Allow users to respond to all pings at once
- Allow responders to clear pings that have been sent
- Track ping history and status
- Notify users of new pings
- Display ping status in the UI

## User Experience

The PingFeature provides the following user experience:

1. **Ping Dependent** - Responders can ping non-responsive dependents
2. **Respond to Ping** - Users can respond to pings from responders
3. **Respond to All** - Users can respond to all pending pings at once
4. **Clear Ping** - Responders can clear pings that have been sent
5. **Ping History** - Users can view their ping history
6. **Ping Notifications** - Users receive notifications for new pings

## Dependencies

The PingFeature depends on the following clients:

- **PingClient** - For ping operations
- **UserClient** - For user profile operations
- **ContactClient** - For contact relationship operations

## Feature Composition

The PingFeature is a standalone feature that is used by other features:

- **RespondersFeature** - Uses the PingFeature to respond to pings
- **DependentsFeature** - Uses the PingFeature to ping dependents
- **NotificationFeature** - Uses the PingFeature to display ping notifications

## Integration with Other Features

The PingFeature integrates with the following features:

- **AppFeature** - The PingFeature is a child of the AppFeature
- **RespondersFeature** - The RespondersFeature uses the PingFeature for ping operations
- **DependentsFeature** - The DependentsFeature uses the PingFeature for ping operations
- **NotificationFeature** - The NotificationFeature displays ping notifications

## Implementation Details

The PingFeature is implemented using The Composable Architecture (TCA) with the following components:

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

The PingFeature is tested using the following approach:

1. **Unit Tests** - Test the reducer logic in isolation
   - Test each action and its effect on the state
   - Test success and failure paths
   - Test edge cases and error conditions

2. **Integration Tests** - Test the feature's integration with its dependencies
   - Test ping operations with mock dependencies
   - Test error handling with simulated failures

3. **UI Tests** - Test the feature's UI and user interactions
   - Test ping functionality
   - Test ping response
   - Test ping history display
