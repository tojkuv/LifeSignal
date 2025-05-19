# Scheduled Functions

**Navigation:** [Back to Functions](README.md) | [Data Management](DataManagement.md) | [Notifications](Notifications.md)

---

## Overview

This document provides detailed specifications for the scheduled functions in the LifeSignal backend. These functions run on a schedule to perform background tasks such as processing check-ins, alerts, and notifications.

## Scheduled Function Types

The LifeSignal application uses several types of scheduled functions:

1. **Check-in Processing**: Functions that process check-ins and expirations
2. **Alert Processing**: Functions that process alerts and notifications
3. **Notification Processing**: Functions that process notification delivery
4. **Data Cleanup**: Functions that clean up expired data

## Scheduled Functions

### processCheckIns

Processes check-ins and expirations.

**Function Signature:**
```typescript
export const processCheckIns = onSchedule(
  "every 15 minutes",
  async (context) => {
    // Implementation
  }
);
```

**Schedule:** Every 15 minutes

**Implementation Details:**
1. Query users whose check-in has expired
2. Update user status to indicate expiration
3. Notify responders of the expiration
4. Log processing status

**Processing Logic:**
- Check-in is considered expired if `expirationTimestamp` is in the past
- Responders are notified based on their notification preferences
- User status is updated to indicate expiration

### processAlerts

Processes alerts and notifications.

**Function Signature:**
```typescript
export const processAlerts = onSchedule(
  "every 5 minutes",
  async (context) => {
    // Implementation
  }
);
```

**Schedule:** Every 5 minutes

**Implementation Details:**
1. Query users with active alerts
2. Check if responders have been notified
3. Send notifications to responders who haven't been notified
4. Log processing status

**Processing Logic:**
- Alert is considered active if `manualAlertActive` is true
- Responders are notified based on their notification preferences
- Notification status is tracked to prevent duplicate notifications

### processNotifications

Processes notification delivery and retries.

**Function Signature:**
```typescript
export const processNotifications = onSchedule(
  "every 10 minutes",
  async (context) => {
    // Implementation
  }
);
```

**Schedule:** Every 10 minutes

**Implementation Details:**
1. Query pending notifications
2. Attempt to deliver notifications
3. Update notification status
4. Retry failed notifications
5. Log processing status

**Processing Logic:**
- Notifications are retried up to 3 times
- Notifications are marked as failed after 3 unsuccessful attempts
- Notification delivery status is logged

### cleanupExpiredData

Cleans up expired data.

**Function Signature:**
```typescript
export const cleanupExpiredData = onSchedule(
  "every 24 hours",
  async (context) => {
    // Implementation
  }
);
```

**Schedule:** Every 24 hours

**Implementation Details:**
1. Query expired data
2. Delete or archive expired data
3. Log cleanup status

**Cleanup Logic:**
- Expired pings are cleared after 24 hours
- Expired notifications are deleted after 7 days
- Expired logs are archived after 30 days

## Schedule Management

The LifeSignal application uses Firebase Cloud Functions for schedule management:

1. **Schedule Definition**: Schedules are defined using cron syntax
2. **Timezone**: Schedules are defined in UTC
3. **Retry Logic**: Failed executions are retried automatically
4. **Monitoring**: Schedule execution is monitored for failures

## Implementation Guidelines

### Scheduled Function Implementation

1. **Idempotency**: Implement idempotent functions that can be safely retried
2. **Concurrency**: Handle concurrent executions
3. **Timeout Handling**: Handle function timeouts
4. **Error Handling**: Implement proper error handling
5. **Logging**: Log function execution status
6. **Monitoring**: Monitor function execution
7. **Testing**: Test scheduled functions with emulated time

For detailed implementation guidelines, see the [Backend Guidelines](../../Guidelines/README.md) section.

For implementation examples, see the [Cloud Function Example](../Examples/CloudFunctionExample.md).
