import Foundation

#if DEBUG
// MARK: - Mock Services for Development/Testing

class MockUserService: UserServiceProtocol, @unchecked Sendable {
    func getUser(_ request: GetUserRequest) async throws -> User_Proto {
        User_Proto(
            id: UUID().uuidString,
            firebaseUID: request.firebaseUID,
            name: "Test User",
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
        UploadAvatarResponse(url: "https://example.com/avatar/\(UUID().uuidString).jpg")
    }
}

class MockContactService: ContactServiceProtocol, @unchecked Sendable {
    func getContacts(_ request: GetContactsRequest) async throws -> GetContactsResponse {
        GetContactsResponse(contacts: [
            Contact_Proto(
                id: UUID().uuidString,
                userID: UUID().uuidString,
                name: "Emergency Contact",
                phoneNumber: "+1234567891",
                relationship: .responder,
                status: .active,
                lastUpdated: Int64(Date().timeIntervalSince1970)
            ),
            Contact_Proto(
                id: UUID().uuidString,
                userID: UUID().uuidString,
                name: "Family Member",
                phoneNumber: "+1234567892",
                relationship: .dependent,
                status: .active,
                lastUpdated: Int64(Date().timeIntervalSince1970)
            )
        ])
    }
    
    func addContact(_ request: AddContactRequest) async throws -> Contact_Proto {
        Contact_Proto(
            id: UUID().uuidString,
            userID: UUID().uuidString,
            name: "New Contact",
            phoneNumber: request.phoneNumber,
            relationship: request.relationship,
            status: .active,
            lastUpdated: Int64(Date().timeIntervalSince1970)
        )
    }
    
    func updateContactStatus(_ request: UpdateContactStatusRequest) async throws -> Contact_Proto {
        Contact_Proto(
            id: request.contactID,
            userID: UUID().uuidString,
            name: "Updated Contact",
            phoneNumber: "+1234567894",
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
            Task {
                // Simulate periodic updates
                for i in 0..<3 {
                    try? await Task.sleep(for: .seconds(5))
                    continuation.yield(Contact_Proto(
                        id: UUID().uuidString,
                        userID: UUID().uuidString,
                        name: "Stream Update \(i)",
                        phoneNumber: "+123456789\(i)",
                        relationship: .responder,
                        status: .active,
                        lastUpdated: Int64(Date().timeIntervalSince1970)
                    ))
                }
                continuation.finish()
            }
        }
    }
}

class MockNotificationService: NotificationServiceProtocol, @unchecked Sendable {
    func getNotifications(_ request: GetNotificationsRequest) async throws -> GetNotificationsResponse {
        GetNotificationsResponse(notifications: [
            Notification_Proto(
                id: UUID().uuidString,
                userID: request.firebaseUID,
                type: .checkIn,
                title: "Check-in Reminder",
                message: "Time for your daily check-in",
                isRead: false,
                createdAt: Int64(Date().timeIntervalSince1970)
            ),
            Notification_Proto(
                id: UUID().uuidString,
                userID: request.firebaseUID,
                type: .contactRequest,
                title: "New Contact Request",
                message: "John Doe wants to add you as a contact",
                isRead: true,
                createdAt: Int64(Date().timeIntervalSince1970 - 3600)
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
#endif