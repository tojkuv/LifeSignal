import Foundation

// MARK: - Live gRPC Service Implementations

class LiveUserService: UserServiceProtocol, @unchecked Sendable {
    // TODO: Implement with actual gRPC client
    // For now, using MockUserService behavior to prevent crashes during development
    func getUser(_ request: GetUserRequest) async throws -> User_Proto { 
        User_Proto(
            id: UUID().uuidString,
            firebaseUID: request.firebaseUID,
            name: "Live User",
            phoneNumber: "+1234567890",
            isNotificationsEnabled: true,
            avatarURL: "",
            lastModified: Int64(Date().timeIntervalSince1970)
        )
    }
    
    func createUser(_ request: CreateUserRequest) async throws -> User_Proto { 
        User_Proto(
            id: UUID().uuidString,
            firebaseUID: request.firebaseUID,
            name: request.name,
            phoneNumber: request.phoneNumber,
            isNotificationsEnabled: request.isNotificationsEnabled,
            avatarURL: "",
            lastModified: Int64(Date().timeIntervalSince1970)
        )
    }
    
    func updateUser(_ request: UpdateUserRequest) async throws -> User_Proto { 
        User_Proto(
            id: UUID().uuidString,
            firebaseUID: request.firebaseUID,
            name: request.name,
            phoneNumber: request.phoneNumber,
            isNotificationsEnabled: request.isNotificationsEnabled,
            avatarURL: request.avatarURL,
            lastModified: Int64(Date().timeIntervalSince1970)
        )
    }
    
    func deleteUser(_ request: DeleteUserRequest) async throws -> Empty_Proto { 
        Empty_Proto()
    }
    
    func uploadAvatar(_ request: UploadAvatarRequest) async throws -> UploadAvatarResponse { 
        UploadAvatarResponse(url: "https://example.com/live-avatar/\(UUID().uuidString).jpg")
    }
}

class LiveContactService: ContactServiceProtocol, @unchecked Sendable {
    // TODO: Implement with actual gRPC client
    // For now, using mock data to prevent crashes during development
    func getContacts(_ request: GetContactsRequest) async throws -> GetContactsResponse { 
        GetContactsResponse(contacts: [
            Contact_Proto(
                id: UUID().uuidString,
                userID: request.userID,
                name: "Live Contact 1",
                phoneNumber: "+1234567890",
                relationship: .responder,
                status: .active,
                lastUpdated: Int64(Date().timeIntervalSince1970)
            ),
            Contact_Proto(
                id: UUID().uuidString,
                userID: request.userID,
                name: "Live Contact 2",
                phoneNumber: "+0987654321",
                relationship: .dependent,
                status: .away,
                lastUpdated: Int64(Date().timeIntervalSince1970)
            )
        ])
    }
    
    func addContact(_ request: AddContactRequest) async throws -> Contact_Proto { 
        Contact_Proto(
            id: UUID().uuidString,
            userID: request.userID,
            name: request.name,
            phoneNumber: request.phoneNumber,
            relationship: request.relationship,
            status: .active,
            lastUpdated: Int64(Date().timeIntervalSince1970)
        )
    }
    
    func updateContactStatus(_ request: UpdateContactStatusRequest) async throws -> Contact_Proto { 
        Contact_Proto(
            id: request.contactID,
            userID: request.userID,
            name: "Updated Contact",
            phoneNumber: "+1234567890",
            relationship: .responder,
            status: request.status,
            lastUpdated: Int64(Date().timeIntervalSince1970)
        )
    }
    
    func removeContact(_ request: RemoveContactRequest) async throws -> Empty_Proto { 
        Empty_Proto()
    }
    
    func streamContactUpdates(_ request: StreamContactUpdatesRequest) -> AsyncStream<Contact_Proto> { 
        AsyncStream { continuation in
            // Return empty stream for now - actual implementation would stream from gRPC
            continuation.finish()
        }
    }
}

class LiveNotificationService: NotificationServiceProtocol, @unchecked Sendable {
    // TODO: Implement with actual gRPC client
    // For now, using mock data to prevent crashes during development
    func getNotifications(_ request: GetNotificationsRequest) async throws -> GetNotificationsResponse {
        GetNotificationsResponse(notifications: [
            Notification_Proto(
                id: UUID().uuidString,
                userID: request.userID,
                type: .checkIn,
                title: "Check-in Reminder",
                message: "Time for your check-in!",
                isRead: false,
                createdAt: Int64(Date().timeIntervalSince1970 - 3600)
            ),
            Notification_Proto(
                id: UUID().uuidString,
                userID: request.userID,
                type: .system,
                title: "Welcome",
                message: "Welcome to LifeSignal!",
                isRead: true,
                createdAt: Int64(Date().timeIntervalSince1970 - 7200)
            )
        ])
    }
    
    func markAsRead(_ request: MarkNotificationRequest) async throws -> Empty_Proto {
        Empty_Proto()
    }
    
    func deleteNotification(_ request: DeleteNotificationRequest) async throws -> Empty_Proto {
        Empty_Proto()
    }
}