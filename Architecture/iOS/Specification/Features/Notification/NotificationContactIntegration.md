# Notification and Contact System Integration

## Overview

This document outlines how the notification system integrates with the contact system in the LifeSignal app. Since many notifications are related to contact actions (role changes, additions, removals), it's important to understand how these systems interact.

## Contact-Related Notifications

### Types of Contact Notifications

1. **Contact Added**: When a user adds a new contact
2. **Contact Removed**: When a user removes a contact
3. **Role Changed**: When a contact's role (responder/dependent) is changed
4. **Non-Responsive Contact**: When a contact hasn't checked in within their interval
5. **Manual Alert**: When a contact triggers a manual alert
6. **Ping Notification**: When a contact sends a ping

### Notification Data Structure for Contact Events

```swift
struct ContactData: Equatable, Sendable {
    let id: String
    let name: String
    let role: ContactRole
    let action: ContactAction
}

enum ContactRole: String, Equatable, Sendable {
    case responder
    case dependent
    case both
    case none
}

enum ContactAction: String, Equatable, Sendable {
    case added
    case removed
    case roleChanged
    case nonResponsive
    case alert
    case ping
}

// Used within NotificationData
struct NotificationData: Identifiable, Equatable, Sendable {
    // Base properties
    let id: String
    let type: NotificationType
    let title: String
    let message: String
    let timestamp: Date
    var isRead: Bool
    
    // Related IDs
    let relatedContactID: String?
    let relatedAlertID: String?
    let relatedPingID: String?
    
    // Type-specific data
    var contactData: ContactData?
    // Other type-specific data...
}
```

## Bidirectional Notification Flow

When a contact-related event occurs, notifications are generated for both the user and the contact:

1. **User adds a contact**:
   - User receives "You added [Contact Name]" notification
   - Contact receives "[User Name] added you" notification

2. **User changes a contact's role**:
   - User receives "You changed [Contact Name]'s role to [Role]" notification
   - Contact receives "[User Name] changed your role to [Role]" notification

3. **User removes a contact**:
   - User receives "You removed [Contact Name]" notification
   - Contact receives "[User Name] removed you" notification

## Server-Side Implementation

The server is responsible for:

1. Creating notification documents in both users' notification collections
2. Sending push notifications to both users' devices
3. Updating contact documents to reflect the changes

```typescript
// Example server-side function (Firebase Cloud Functions)
export async function handleContactRoleChange(
  userId: string,
  contactId: string,
  isResponder: boolean,
  isDependent: boolean
): Promise<void> {
  const db = admin.firestore();
  const messaging = admin.messaging();
  
  // Get user and contact data
  const userDoc = await db.doc(`users/${userId}`).get();
  const contactDoc = await db.doc(`users/${contactId}`).get();
  const userData = userDoc.data() as UserProfile;
  const contactData = contactDoc.data() as UserProfile;
  
  // Determine role change
  const roleText = determineRoleText(isResponder, isDependent);
  
  // Create notification for user
  await db.collection(`notifications/${userId}/history`).add({
    type: "role",
    title: "Role Changed",
    message: `You changed ${contactData.name}'s role to ${roleText}.`,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    isRead: false,
    relatedContactID: contactId,
    contactData: {
      id: contactId,
      name: contactData.name,
      role: determineRole(isResponder, isDependent),
      action: "roleChanged"
    }
  });
  
  // Create notification for contact
  await db.collection(`notifications/${contactId}/history`).add({
    type: "role",
    title: "Role Changed",
    message: `${userData.name} changed your role to ${roleText}.`,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    isRead: false,
    relatedContactID: userId,
    contactData: {
      id: userId,
      name: userData.name,
      role: determineRole(isResponder, isDependent),
      action: "roleChanged"
    }
  });
  
  // Send push notifications
  if (userData.fcmToken) {
    await messaging.send({
      token: userData.fcmToken,
      notification: {
        title: "Role Changed",
        body: `You changed ${contactData.name}'s role to ${roleText}.`
      }
    });
  }
  
  if (contactData.fcmToken) {
    await messaging.send({
      token: contactData.fcmToken,
      notification: {
        title: "Role Changed",
        body: `${userData.name} changed your role to ${roleText}.`
      }
    });
  }
}
```

## Client-Side Implementation

### Contact Feature Integration

The contact feature needs to:

1. Update contact roles locally
2. Send the changes to the server
3. Handle incoming notifications about contact changes

```swift
@Reducer
struct ContactsFeature {
    // State and other actions...
    
    enum Action: Equatable, Sendable {
        // Existing actions...
        
        case updateContactRoles(id: String, isResponder: Bool, isDependent: Bool)
        case contactRolesUpdated
        case contactRolesUpdateFailed(UserFacingError)
        
        // Notification-related actions
        case contactAdded(String, isResponder: Bool, isDependent: Bool)
        case contactRemoved(String)
        case contactRoleChanged(String, isResponder: Bool, isDependent: Bool)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .updateContactRoles(id, isResponder, isDependent):
                // Update local state immediately for better UX
                if let index = state.contacts.index(id: id) {
                    state.contacts[index].isResponder = isResponder
                    state.contacts[index].isDependent = isDependent
                }
                
                return .run { [contactsClient, authClient] send in
                    do {
                        let userId = try await authClient.currentUserId()
                        
                        // Update contact roles on the server
                        try await contactsClient.updateContact(userId, id, [
                            "isResponder": isResponder,
                            "isDependent": isDependent
                        ])
                        
                        await send(.contactRolesUpdated)
                    } catch {
                        let userFacingError = UserFacingError.from(error)
                        await send(.contactRolesUpdateFailed(userFacingError))
                    }
                }
                
            // Handle other actions...
            }
        }
    }
}
```

### Notification Feature Integration

The notification feature needs to:

1. Display contact-related notifications
2. Allow users to navigate to the related contact from a notification
3. Update the notification list when contact changes occur

```swift
@Reducer
struct NotificationFeature {
    // State and other actions...
    
    enum Action: Equatable, Sendable {
        // Existing actions...
        
        case notificationTapped(id: String)
        case navigateToContact(id: String)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .notificationTapped(id):
                if let notification = state.notifications[id: id],
                   let contactId = notification.relatedContactID {
                    // Mark as read
                    return .merge(
                        .send(.markAsRead(id: id)),
                        .send(.navigateToContact(id: contactId))
                    )
                }
                return .send(.markAsRead(id: id))
                
            case .navigateToContact:
                // This will be handled by the parent feature for navigation
                return .none
                
            // Handle other actions...
            }
        }
    }
}
```

## Handling Notification Streams in the App Feature

The app feature coordinates between the contacts and notifications features:

```swift
@Reducer
struct AppFeature {
    // State and other actions...
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appDidLaunch:
                return .merge(
                    // Initialize contact stream
                    .run { [contactsClient, authClient] send in
                        do {
                            let userId = try await authClient.currentUserId()
                            for await contacts in contactsClient.streamContacts(userId) {
                                await send(.contacts(.contactsUpdated(contacts)))
                            }
                        } catch {
                            // Handle error
                        }
                    }
                    .cancellable(id: CancelID.contactStream),
                    
                    // Initialize notification stream
                    .run { [notificationClient, authClient] send in
                        do {
                            let userId = try await authClient.currentUserId()
                            for await notifications in notificationClient.streamNotifications(userId) {
                                await send(.notification(.notificationsUpdated(notifications)))
                            }
                        } catch {
                            // Handle error
                        }
                    }
                    .cancellable(id: CancelID.notificationStream)
                )
                
            case let .notification(.navigateToContact(id)):
                // Handle navigation to contact detail
                state.selectedTab = .contacts
                state.contacts.selectedContactId = id
                return .none
                
            // Handle other actions...
            }
        }
        // Feature composition...
    }
}
```

## Notification Center UI Integration

The notification center UI should:

1. Display contact information in contact-related notifications
2. Allow tapping on a notification to navigate to the related contact
3. Group notifications by type (added, removed, role changed)

```swift
struct NotificationCenterView: View {
    @Bindable var store: StoreOf<NotificationFeature>
    
    var body: some View {
        List {
            ForEach(store.filteredNotifications) { notification in
                NotificationRow(
                    notification: notification,
                    onTap: {
                        store.send(.notificationTapped(id: notification.id))
                    }
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        store.send(.setFilter(.all))
                    } label: {
                        Label("All", systemImage: "tray.full")
                    }
                    
                    Button {
                        store.send(.setFilter(.added))
                    } label: {
                        Label("Added", systemImage: "person.badge.plus")
                    }
                    
                    Button {
                        store.send(.setFilter(.removed))
                    } label: {
                        Label("Removed", systemImage: "person.badge.minus")
                    }
                    
                    Button {
                        store.send(.setFilter(.role))
                    } label: {
                        Label("Roles", systemImage: "person.badge.key")
                    }
                    
                    // Other filter options...
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }
}

struct NotificationRow: View {
    let notification: NotificationData
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Icon based on notification type
                notificationIcon
                    .foregroundColor(notificationColor)
                
                VStack(alignment: .leading) {
                    Text(notification.title)
                        .font(.headline)
                    
                    Text(notification.message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(notification.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.tertiary)
                }
                
                Spacer()
                
                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 10, height: 10)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Computed properties for icon and color based on notification type...
}
```

## Testing

Test cases should include:

1. **Contact Role Changes**:
   - Verify both users receive notifications
   - Verify notification content is correct
   - Verify navigation to contact works

2. **Contact Addition/Removal**:
   - Verify both users receive notifications
   - Verify contact list is updated
   - Verify notification content is correct

3. **Stream Synchronization**:
   - Verify contact changes from one device appear on another
   - Verify notification stream updates when contacts change
   - Verify offline changes sync when coming back online

## Conclusion

The integration between the notification and contact systems is crucial for providing a seamless user experience in the LifeSignal app. By implementing bidirectional notifications and real-time streams, users can stay informed about changes to their contact network and respond appropriately to alerts, pings, and role changes.
