# Notification Functions

**Navigation:** [Back to Functions](README.md) | [Data Management](DataManagement.md) | [Scheduled](Scheduled.md)

---

## Overview

This document provides detailed specifications for the notification functions in the LifeSignal backend. These functions handle sending notifications to users for various events, such as check-in reminders, alerts, and pings.

## Notification Types

The LifeSignal application uses several types of notifications:

1. **Check-in Reminders**: Reminders to check in before the check-in expires
2. **Check-in Expiry**: Notifications when a user's check-in has expired
3. **Ping Notifications**: Notifications when a user is pinged by a responder
4. **Alert Notifications**: Notifications when a user activates an alert
5. **Role Change Notifications**: Notifications when a user's role is changed
6. **Contact Added/Removed Notifications**: Notifications when a contact is added or removed

## Notification Functions

### sendCheckInReminders

Sends check-in reminders to users whose check-in is about to expire.

**Function Signature:**
```typescript
export const sendCheckInReminders = onSchedule(
  "every 15 minutes",
  async (context) => {
    // Implementation
  }
);
```

**Implementation Details:**
1. Query users whose check-in is about to expire
2. Filter users based on notification preferences
3. Send push notifications to users
4. Log notification status

**Notification Timing:**
- 30 minutes before expiry (if `notify30MinBefore` is true)
- 2 hours before expiry (if `notify2HoursBefore` is true)

**Notification Content:**
```json
{
  "title": "Check-in Reminder",
  "body": "Your check-in will expire in [time]. Tap to check in now.",
  "data": {
    "type": "check_in_reminder",
    "expiryTime": "[timestamp]"
  }
}
```

### sendAlertNotifications

Sends notifications to responders when a user activates an alert.

**Function Signature:**
```typescript
export const sendAlertNotifications = functions.firestore
  .document("users/{userId}/contacts/{contactId}")
  .onUpdate(async (change, context) => {
    // Implementation
  });
```

**Trigger:**
- Document update in `users/{userId}/contacts/{contactId}`
- `manualAlertActive` field changes from `false` to `true`

**Implementation Details:**
1. Check if the alert status has changed
2. Query the user's responders
3. Filter responders based on notification preferences
4. Send push notifications to responders
5. Log notification status

**Notification Content:**
```json
{
  "title": "ALERT: [User Name] needs help!",
  "body": "[User Name] has activated their emergency alert. Tap to view details.",
  "data": {
    "type": "alert_notification",
    "userId": "[userId]",
    "alertTime": "[timestamp]"
  }
}
```

### sendPingNotifications

Sends notifications to users when they are pinged by a responder.

**Function Signature:**
```typescript
export const sendPingNotifications = functions.firestore
  .document("users/{userId}/contacts/{contactId}")
  .onUpdate(async (change, context) => {
    // Implementation
  });
```

**Trigger:**
- Document update in `users/{userId}/contacts/{contactId}`
- `outgoingPingTimestamp` field is updated

**Implementation Details:**
1. Check if a ping has been sent
2. Query the dependent's user document
3. Check if the dependent has notification preferences
4. Send push notification to the dependent
5. Log notification status

**Notification Content:**
```json
{
  "title": "[Responder Name] is checking on you",
  "body": "[Responder Name] has sent you a ping. Tap to respond.",
  "data": {
    "type": "ping_notification",
    "responderId": "[responderId]",
    "pingTime": "[timestamp]"
  }
}
```

### sendRoleChangeNotifications

Sends notifications to users when their role is changed.

**Function Signature:**
```typescript
export const sendRoleChangeNotifications = functions.firestore
  .document("users/{userId}/contacts/{contactId}")
  .onUpdate(async (change, context) => {
    // Implementation
  });
```

**Trigger:**
- Document update in `users/{userId}/contacts/{contactId}`
- `isResponder` or `isDependent` fields are updated

**Implementation Details:**
1. Check if the roles have changed
2. Query the contact's user document
3. Check if the contact has notification preferences
4. Send push notification to the contact
5. Log notification status

**Notification Content:**
```json
{
  "title": "Role Update",
  "body": "[User Name] has updated your role in their contacts.",
  "data": {
    "type": "role_change_notification",
    "userId": "[userId]",
    "isResponder": "[boolean]",
    "isDependent": "[boolean]"
  }
}
```

### sendContactAddedNotifications

Sends notifications to users when they are added as a contact.

**Function Signature:**
```typescript
export const sendContactAddedNotifications = functions.firestore
  .document("users/{userId}/contacts/{contactId}")
  .onCreate(async (snapshot, context) => {
    // Implementation
  });
```

**Trigger:**
- Document creation in `users/{userId}/contacts/{contactId}`

**Implementation Details:**
1. Query the contact's user document
2. Check if the contact has notification preferences
3. Send push notification to the contact
4. Log notification status

**Notification Content:**
```json
{
  "title": "New Contact",
  "body": "[User Name] has added you as a contact.",
  "data": {
    "type": "contact_added_notification",
    "userId": "[userId]",
    "isResponder": "[boolean]",
    "isDependent": "[boolean]"
  }
}
```

### sendContactRemovedNotifications

Sends notifications to users when they are removed as a contact.

**Function Signature:**
```typescript
export const sendContactRemovedNotifications = functions.firestore
  .document("users/{userId}/contacts/{contactId}")
  .onDelete(async (snapshot, context) => {
    // Implementation
  });
```

**Trigger:**
- Document deletion in `users/{userId}/contacts/{contactId}`

**Implementation Details:**
1. Query the contact's user document
2. Check if the contact has notification preferences
3. Send push notification to the contact
4. Log notification status

**Notification Content:**
```json
{
  "title": "Contact Removed",
  "body": "[User Name] has removed you as a contact.",
  "data": {
    "type": "contact_removed_notification",
    "userId": "[userId]"
  }
}
```

## Notification Delivery

The LifeSignal application uses Firebase Cloud Messaging (FCM) for notification delivery:

1. **Token Management**: FCM tokens are stored in the user document
2. **Notification Preferences**: Users can configure notification preferences
3. **Delivery Status**: Notification delivery status is logged
4. **Retry Logic**: Failed notifications are retried

## Implementation Guidelines

### Notification Implementation

1. **Token Validation**: Validate FCM tokens before sending notifications
2. **Payload Size**: Keep notification payloads small
3. **Localization**: Support localized notification content
4. **Deep Linking**: Include deep links in notifications
5. **Batching**: Batch notifications when possible
6. **Rate Limiting**: Implement rate limiting for notifications
7. **Error Handling**: Handle notification delivery failures

For detailed implementation guidelines, see the [Backend Guidelines](../../Guidelines/README.md) section.

For implementation examples, see the [Cloud Function Example](../Examples/CloudFunctionExample.md).
