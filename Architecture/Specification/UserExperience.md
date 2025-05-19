# LifeSignal User Experience

This document outlines the complete user experience for the LifeSignal application, including all user actions and expected behaviors. It serves as a comprehensive guide for understanding the application's functionality and user flows.

---

## Core User Flows

### Authentication Flow

#### User Actions
- Sign in with phone number
- Enter verification code
- Sign out

#### Expected Behavior
1. **Sign In with Phone Number**
   - User enters their phone number
   - System validates the phone number format
   - System sends a verification code to the phone number
   - User is presented with a verification code entry screen

2. **Enter Verification Code**
   - User enters the verification code received via SMS
   - System validates the code
   - If valid, user is authenticated and directed to the main app
   - If invalid, user is shown an error message and can retry

3. **Sign Out**
   - User taps sign out in profile settings
   - System signs the user out
   - User is returned to the sign-in screen

---

### Onboarding Flow

#### User Actions
- Complete profile setup
- Set notification preferences
- Set check-in interval

#### Expected Behavior
1. **Profile Setup**
   - User enters their name
   - User enters emergency note (optional)
   - User can upload a profile picture (optional)

2. **Notification Preferences**
   - User enables/disables check-in reminders
   - User configures reminder timing (30 minutes before, 2 hours before)

3. **Check-in Interval**
   - User selects their preferred check-in interval (12 hours, 24 hours, 48 hours, etc.)
   - System confirms selection and sets up initial check-in schedule

---

### Check-In System

#### User Actions
- Perform check-in
- Change check-in interval
- View check-in status

#### Expected Behavior
1. **Perform Check-in**
   - User taps the check-in button
   - System records the check-in time
   - System updates the next check-in deadline
   - System schedules new reminders based on preferences
   - User sees confirmation of successful check-in

2. **Change Check-in Interval**
   - User selects a new interval from options
   - System updates the interval setting
   - System recalculates the next check-in deadline
   - System reschedules reminders based on new deadline

3. **View Check-in Status**
   - User sees time since last check-in
   - User sees time until next check-in deadline
   - User sees visual indicator of check-in status (normal, warning, critical)

---

### Contact Management

#### User Actions
- Add contact via QR code
- Update contact roles (responder, dependent)
- Remove contact
- View contact details

#### Expected Behavior
1. **Add Contact via QR Code**
   - User scans another user's QR code
   - User assigns roles to the contact (responder, dependent, or both)
   - System creates bidirectional relationship between users
   - Both users receive confirmation of new contact relationship

2. **Update Contact Roles**
   - User selects a contact
   - User toggles responder/dependent roles
   - System shows a confirmation dialog explaining the implications of the role change
   - User confirms the role change
   - System updates the relationship in the database
   - System updates any existing pings to maintain the rule that only responders can ping dependents
   - Contact receives notification of role change

3. **Remove Contact**
   - User selects a contact
   - User confirms deletion
   - System removes bidirectional relationship
   - Both users' contact lists are updated

4. **View Contact Details**
   - User taps on a contact
   - System displays contact details (name, roles, last check-in, etc.)
   - User can see contact's check-in status if they are a dependent

---

### Responder Features

#### User Actions
- View responder list
- Respond to pings
- Respond to all pings
- View dependent status
- Ping dependent
- Clear ping

#### Expected Behavior
1. **View Responder List**
   - User sees list of contacts who are responders
   - List shows responder name, photo, and status
   - Badge indicates number of pending pings

2. **Respond to Pings**
   - User receives notification of ping from another responder
   - User taps "Respond" on a specific ping
   - System records response and notifies the sender
   - Ping is marked as responded

3. **Respond to All Pings**
   - User taps "Respond to All" button
   - System records response for all pending pings
   - All senders are notified
   - All pings are marked as responded

4. **View Dependent Status**
   - User can see check-in status of dependents
   - User can see if dependent has triggered manual alert
   - User can see if dependent has missed check-in

5. **Ping Dependent**
   - User taps "Ping" button for a specific dependent
   - System sends ping notification to dependent
   - Dependent is marked as "pinged" with timestamp
   - User sees confirmation of ping sent

6. **Clear Ping**
   - User taps "Clear Ping" for a previously pinged dependent
   - System clears the ping status
   - Dependent is notified that ping was cleared
   - Ping status and timestamp are removed

> **Important:** Only responders can send pings to dependents. Dependents cannot send pings to responders.

---

### Dependent Features

#### User Actions
- View dependent list
- View responder status

#### Expected Behavior
1. **View Dependent List**
   - User sees list of contacts who are dependents
   - List shows dependent name, photo, and status
   - Badge indicates number of non-responsive dependents

2. **View Responder Status**
   - User can see which responders are available
   - User can see last response time from responders
   - User can see if they have been pinged by a responder

> **Important:** Dependents cannot send pings to responders. Only responders can send pings to dependents.

---

### Alert System

#### User Actions
- Trigger manual alert
- Clear manual alert
- View alert history

#### Expected Behavior
1. **Trigger Manual Alert**
   - User taps "Alert" button
   - User confirms alert trigger
   - System activates alert status
   - All responders are notified
   - Alert is recorded with timestamp

2. **Clear Manual Alert**
   - User taps "Clear Alert" button
   - User confirms alert clearance
   - System deactivates alert status
   - All responders are notified
   - Alert clearance is recorded with timestamp

3. **View Alert History**
   - User can see history of alerts triggered
   - User can see which responders responded to each alert
   - User can see response times for each responder

---

### Notification System

#### User Actions
- Enable/disable notifications
- Configure notification preferences
- View notification history

#### Expected Behavior
1. **Enable/Disable Notifications**
   - User toggles notification settings
   - System updates notification permissions
   - System applies changes to scheduled notifications

2. **Configure Notification Preferences**
   - User selects which events trigger notifications
   - User configures timing for check-in reminders
   - System applies preferences to notification scheduling

3. **View Notification History**
   - User can see history of notifications received
   - User can filter notifications by type
   - User can clear notification history

---

### Profile Management

#### User Actions
- Update profile information
- Change phone number
- Update notification preferences
- View account information

#### Expected Behavior
1. **Update Profile Information**
   - User edits name, emergency note, or profile picture
   - System validates and saves changes
   - Updated information is visible to contacts

2. **Change Phone Number**
   - User enters new phone number
   - System sends verification code to new number
   - User verifies new number with code
   - System updates phone number in user profile

3. **Update Notification Preferences**
   - User modifies notification settings
   - System applies changes immediately
   - New preferences affect future notifications

4. **View Account Information**
   - User can see account creation date
   - User can see current check-in interval
   - User can see number of contacts

---

## Cross-Feature Interactions

### Check-In and Alert Integration

When a user misses a check-in deadline:
1. System automatically changes user status to "non-responsive"
2. System notifies all responders
3. Responders can see the non-responsive status in their dependent list
4. Responders can ping the non-responsive user

### Ping and Alert Integration

When a dependent doesn't respond to pings from responders:
1. Ping status remains "pending" until responded to
2. Responders can see pending ping status and time since ping
3. Multiple responders can ping the same dependent
4. Dependent can respond to all pings with a single action
5. Only responders can send pings to dependents

### Contact and Profile Integration

When a user updates their profile:
1. Changes are reflected in contacts' views
2. Profile picture updates are propagated to contacts
3. Name changes are reflected in contacts' lists

### Role Change and Ping Integration

When a user's role changes:
1. System evaluates all existing pings involving the user
2. If role change would create pings that violate the rule (dependents pinging responders), those pings are cleared
3. User is notified about any pings that were cleared due to role change
4. Contact is notified about the role change and any affected pings

---

## Offline Behavior

### Data Persistence

1. **Check-In Status**
   - Last check-in time is persisted locally
   - Check-in interval is persisted locally
   - User can perform check-in while offline

2. **Contact Information**
   - Basic contact information is cached locally
   - User can view contacts while offline
   - Changes made offline are synced when connection is restored

3. **Alert Status**
   - Alert status is persisted locally
   - User can trigger alert while offline (will sync when online)
   - Alert history is cached for offline viewing

### Sync Behavior

1. **Background Sync**
   - System attempts to sync data when app is in background
   - System prioritizes critical data (alerts, check-ins) for sync
   - User is notified of sync failures for critical actions

2. **Conflict Resolution**
   - Server timestamp is used to resolve conflicts
   - Last-write-wins strategy for most data
   - Critical actions (alerts, check-ins) are never overwritten

---

## Error Handling

### Network Errors

1. **Connection Loss**
   - User is notified when connection is lost
   - Critical actions are queued for retry
   - UI indicates offline status

2. **Timeout Errors**
   - System retries critical operations automatically
   - User is prompted to retry non-critical operations
   - Exponential backoff is used for retries

### Validation Errors

1. **Input Validation**
   - User is shown immediate feedback for invalid input
   - Submit buttons are disabled until input is valid
   - Clear error messages explain validation requirements

2. **Business Rule Validation**
   - System enforces check-in intervals
   - System prevents duplicate contact relationships
   - System validates role assignments

---

## Accessibility Considerations

### Visual Accessibility

1. **Color Contrast**
   - All UI elements meet WCAG AA contrast requirements
   - Status indicators use both color and shape
   - Text size adapts to system settings

2. **Screen Reader Support**
   - All interactive elements have appropriate accessibility labels
   - Actions announce their results
   - Navigation structure is logical and hierarchical

### Motor Accessibility

1. **Touch Targets**
   - Critical buttons have large touch targets
   - Swipe gestures have button alternatives
   - Confirmation dialogs prevent accidental actions

### UI Consistency

1. **Sheet Dismissal**
   - Sheets should not have X buttons for dismissal
   - Sheets should be dismissed using standard buttons (e.g., "Done", "Cancel", "Save")
   - This is not considered an accessibility case that needs to be covered

---

## Performance Expectations

### Response Times

1. **UI Interactions**
   - Button presses respond within 100ms
   - List scrolling maintains 60fps
   - Transitions complete within 300ms

2. **Network Operations**
   - Check-in confirmation appears within 2 seconds
   - Contact list loads within 3 seconds
   - Background operations don't impact UI responsiveness

### Battery Usage

1. **Background Activity**
   - Background sync occurs at most every 15 minutes
   - Location services only used when necessary
   - Push notifications used instead of polling where possible

2. **Optimization Techniques**
   - Images are cached and compressed
   - Network requests are batched when possible
   - UI updates are coalesced to minimize redraws
