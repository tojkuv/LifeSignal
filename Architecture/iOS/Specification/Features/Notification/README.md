# NotificationFeature

**Navigation:** [Back to Features](../README.md) | [Utility Features](../UtilityFeatures.md) | [State](State.md) | [Actions](Actions.md) | [Effects](Effects.md) | [Notification Stream](NotificationStream.md) | [Contact Integration](NotificationContactIntegration.md) | [Implementation](NotificationStreamImplementation.md)

---

## Overview

The NotificationFeature is responsible for managing notifications in the LifeSignal iOS application. It handles displaying notifications, managing notification preferences, and processing notification events. The feature is designed to keep users informed about important events such as check-in reminders, alerts, and contact updates.

The notification system uses a server-side streaming approach where all notifications are stored on the server and streamed to the client in real-time. This ensures that users always have the most up-to-date notification information, even across multiple devices.

## Responsibilities

- Display a list of notifications with filtering options
- Manage notification preferences (enable/disable, timing)
- Handle push notification registration and permissions
- Process incoming notifications
- Mark notifications as read
- Clear notifications
- Group notifications by type (Alerts, Pings, Roles, Removed, Added, Check-Ins)
- Stream notifications from the server in real-time
- Maintain bidirectional notification flow between users and their contacts
- Update notification history based on server-side changes

## User Experience

The NotificationFeature provides the following user experience:

1. **Notification Center** - Displays a list of notifications with filtering options
2. **Notification Preferences** - Allows users to manage notification settings
3. **Notification Badges** - Shows badges for unread notifications
4. **Notification Actions** - Allows users to take actions directly from notifications
5. **Notification Filtering** - Enables filtering notifications by type

## Dependencies

The NotificationFeature depends on the following clients:

- **NotificationClient** - For notification operations, including streaming notifications from the server
- **UserClient** - For user profile operations
- **AuthClient** - For authentication operations
- **ContactsClient** - For contact-related notifications

## Feature Composition

The NotificationFeature is composed of the following child features:

- **NotificationPreferencesFeature** - For managing notification preferences
- **NotificationFilterFeature** - For filtering notifications by type

## Integration with Other Features

The NotificationFeature integrates with the following features:

- **AppFeature** - The NotificationFeature is a child of the AppFeature
- **CheckInFeature** - The NotificationFeature displays check-in reminders
- **AlertFeature** - The NotificationFeature displays alert notifications
- **PingFeature** - The NotificationFeature displays ping notifications
- **ContactsFeature** - The NotificationFeature displays contact update notifications

## Implementation Details

The NotificationFeature is implemented using The Composable Architecture (TCA) with the following components:

- **State** - Defines the feature's state
- **Action** - Defines the actions that can be performed on the feature
- **Reducer** - Defines how the state changes in response to actions
- **View** - Displays the feature's UI and handles user interaction

The notification stream is implemented using AsyncStream and Firebase Firestore's real-time listeners. This allows the app to receive notifications in real-time without polling the server.

For detailed implementation information, see:

- [State](State.md) - Detailed information about the feature's state
- [Actions](Actions.md) - Detailed information about the feature's actions
- [Effects](Effects.md) - Detailed information about the feature's effects
- [Notification Stream](NotificationStream.md) - Detailed information about the notification stream
- [Contact Integration](NotificationContactIntegration.md) - Detailed information about how notifications integrate with contacts
- [Implementation](NotificationStreamImplementation.md) - Technical guide for implementing the notification stream

## Example Implementation

For a complete example implementation of a TCA feature, see the [FeatureExample](../../Examples/FeatureExample.md) document.

## Testing

The NotificationFeature is tested using the following approach:

1. **Unit Tests** - Test the reducer logic in isolation
   - Test each action and its effect on the state
   - Test success and failure paths
   - Test edge cases and error conditions
   - Test notification stream handling

2. **Integration Tests** - Test the feature's integration with its dependencies
   - Test notification operations with mock dependencies
   - Test permission handling with mock dependencies
   - Test error handling with simulated failures
   - Test bidirectional notification flow
   - Test notification stream with simulated server updates

3. **UI Tests** - Test the feature's UI and user interactions
   - Test notification list display
   - Test notification filtering
   - Test notification preferences
   - Test notification actions
   - Test real-time updates to the notification list
