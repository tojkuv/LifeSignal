# CheckInFeature

**Navigation:** [Back to Feature List](../../FeatureList.md) | [State](State.md) | [Actions](Actions.md) | [Effects](Effects.md)

---

## Overview

The CheckInFeature is responsible for managing the user's check-in functionality. It allows users to check in, view their check-in status, and manage their check-in interval. The feature is designed to help users maintain a regular check-in schedule and notify their responders if they fail to check in.

## Responsibilities

- Allow users to check in manually
- Display the user's check-in status and time remaining
- Allow users to set their check-in interval
- Manage check-in reminders
- Track check-in history
- Notify responders when a user fails to check in

## User Experience

The CheckInFeature provides the following user experience:

1. **Check-In Button** - A prominent button that allows users to check in manually
2. **Status Display** - Shows the user's current check-in status (on schedule or overdue)
3. **Time Remaining** - Shows the time remaining until the next check-in is due
4. **Interval Selection** - Allows users to select their check-in interval from predefined options
5. **Reminder Settings** - Allows users to set when they want to be reminded to check in

## Dependencies

The CheckInFeature depends on the following clients:

- **CheckInClient** - For check-in operations
- **UserClient** - For user profile operations
- **NotificationClient** - For notification operations

## Feature Composition

The CheckInFeature is composed of the following child features:

- **IntervalSelectionFeature** - For selecting the check-in interval

## Integration with Other Features

The CheckInFeature integrates with the following features:

- **HomeFeature** - The CheckInFeature is displayed on the home screen
- **NotificationFeature** - Check-in reminders and overdue notifications are displayed in the notification center
- **ProfileFeature** - Check-in interval settings are accessible from the profile screen

## Implementation Details

The CheckInFeature is implemented using The Composable Architecture (TCA) with the following components:

- **State** - Defines the feature's state
- **Action** - Defines the actions that can be performed on the feature
- **Reducer** - Defines how the state changes in response to actions
- **View** - Displays the feature's UI and handles user interaction

For detailed implementation information, see:

- [State](State.md) - Detailed information about the feature's state
- [Actions](Actions.md) - Detailed information about the feature's actions
- [Effects](Effects.md) - Detailed information about the feature's effects

## Example Implementation

For a complete example implementation of the CheckInFeature, see the [FeatureExample](../../Examples/FeatureExample.md) document.

## Testing

The CheckInFeature is tested using the following approach:

1. **Unit Tests** - Test the reducer and effects in isolation
2. **Integration Tests** - Test the feature's integration with its dependencies
3. **UI Tests** - Test the feature's UI and user interaction

Example test cases include:

- Test successful check-in
- Test check-in failure
- Test interval selection
- Test time remaining calculation
- Test overdue status

## Acceptance Criteria

The CheckInFeature must meet the following acceptance criteria:

1. Users must be able to check in manually
2. The check-in status must be clearly displayed
3. The time remaining until the next check-in must be accurately displayed
4. Users must be able to select their check-in interval from predefined options
5. Users must be able to set when they want to be reminded to check in
6. Responders must be notified when a user fails to check in
7. The feature must work offline and sync when the device is online
8. The feature must handle error conditions gracefully

## Future Enhancements

Potential future enhancements for the CheckInFeature include:

1. **Automatic Check-In** - Allow users to set up automatic check-ins based on location or activity
2. **Custom Intervals** - Allow users to set custom check-in intervals
3. **Multiple Reminders** - Allow users to set multiple reminder times
4. **Check-In Analytics** - Provide analytics on check-in patterns and history
5. **Emergency Mode** - Allow users to temporarily increase check-in frequency during high-risk activities
