# DependentsFeature

**Navigation:** [Back to Feature List](../../FeatureList.md) | [State](State.md) | [Actions](Actions.md) | [Effects](Effects.md)

---

## Overview

The DependentsFeature is responsible for managing the user's dependent contacts in the LifeSignal iOS application. It allows users to view their dependents, monitor their status, and send pings to non-responsive dependents. The feature is designed to help users keep track of the people they are responsible for and ensure their safety.

## Responsibilities

- Display the list of dependent contacts
- Show dependent status (responsive, non-responsive, alert active)
- Allow users to ping non-responsive dependents
- Allow users to clear pings
- Enable adding new dependents via QR code scanning
- Manage dependent relationship details
- Sort dependents by different criteria (time left, name, date added)

## User Experience

The DependentsFeature provides the following user experience:

1. **Dependent List** - Displays the user's dependents with their name, photo, and status
2. **Status Monitoring** - Shows the status of each dependent (responsive, non-responsive, alert active)
3. **Ping Dependent** - Allows users to ping non-responsive dependents
4. **Clear Ping** - Allows users to clear pings that have been sent
5. **Add Dependent** - Enables adding new dependents via QR code scanning
6. **Dependent Details** - Shows detailed information about a dependent and allows managing the relationship
7. **Sorting Options** - Allows sorting dependents by different criteria

## Dependencies

The DependentsFeature depends on the following clients:

- **ContactClient** - For contact relationship operations
- **PingClient** - For ping operations
- **UserClient** - For user profile operations

## Feature Composition

The DependentsFeature is composed of the following child features:

- **ContactDetailsSheetViewFeature** - For viewing and managing dependent details
- **QRScannerFeature** - For scanning QR codes to add new dependents
- **AddContactFeature** - For adding new dependents

## Integration with Other Features

The DependentsFeature integrates with the following features:

- **ContactsFeature** - The DependentsFeature is a child of the ContactsFeature
- **PingFeature** - The DependentsFeature uses the PingFeature for ping operations

## Implementation Details

The DependentsFeature is implemented using The Composable Architecture (TCA) with the following components:

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

The DependentsFeature is tested using the following approach:

1. **Unit Tests** - Test the reducer logic in isolation
   - Test each action and its effect on the state
   - Test success and failure paths
   - Test edge cases and error conditions

2. **Integration Tests** - Test the feature's integration with its dependencies
   - Test contact operations with mock dependencies
   - Test ping operations with mock dependencies
   - Test error handling with simulated failures

3. **UI Tests** - Test the feature's UI and user interactions
   - Test dependent list display
   - Test ping functionality
   - Test adding new dependents
   - Test dependent details
