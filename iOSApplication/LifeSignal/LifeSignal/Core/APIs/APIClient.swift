import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation

// MARK: - API Client (Legacy Support)

@DependencyClient
struct APIClient {
    var getUser: @Sendable (String) async throws -> User
    var createUser: @Sendable (String, String, String) async throws -> User
    var updateUser: @Sendable (User) async throws -> User
    var getContacts: @Sendable () async throws -> [Contact]
    var addContact: @Sendable (String) async throws -> Contact
    var updateContactStatus: @Sendable (UUID, Contact.Status) async throws -> Contact
    var removeContact: @Sendable (UUID) async throws -> Void
    var uploadAvatar: @Sendable (Data) async throws -> URL
}

extension APIClient: DependencyKey {
    static let liveValue = APIClient(
        getUser: { uid in
            User(
                id: UUID(),
                firebaseUID: uid,
                name: "Mock User",
                phoneNumber: "+1234567890"
            )
        },
        createUser: { uid, name, phone in
            User(
                id: UUID(),
                firebaseUID: uid,
                name: name,
                phoneNumber: phone
            )
        },
        updateUser: { user in user },
        getContacts: {
            [
                Contact(
                    id: UUID(),
                    userID: UUID(),
                    name: "John Doe",
                    phoneNumber: "+1234567890",
                    relationship: .responder,
                    status: .active,
                    lastUpdated: Date(),
                    qrCodeId: UUID().uuidString,
                    lastCheckIn: Date(),
                    note: "",
                    manualAlertActive: false,
                    isNonResponsive: false,
                    hasIncomingPing: false,
                    incomingPingTimestamp: nil,
                    hasOutgoingPing: false,
                    outgoingPingTimestamp: nil,
                    checkInInterval: 24 * 60 * 60,
                    manualAlertTimestamp: nil
                ),
                Contact(
                    id: UUID(),
                    userID: UUID(),
                    name: "Jane Smith",
                    phoneNumber: "+0987654321",
                    relationship: .dependent,
                    status: .away,
                    lastUpdated: Date(),
                    qrCodeId: UUID().uuidString,
                    lastCheckIn: Date(),
                    note: "",
                    manualAlertActive: false,
                    isNonResponsive: false,
                    hasIncomingPing: false,
                    incomingPingTimestamp: nil,
                    hasOutgoingPing: false,
                    outgoingPingTimestamp: nil,
                    checkInInterval: 24 * 60 * 60,
                    manualAlertTimestamp: nil
                )
            ]
        },
        addContact: { phone in
            Contact(
                id: UUID(),
                userID: UUID(),
                name: "New Contact",
                phoneNumber: phone,
                relationship: .responder,
                status: .active,
                lastUpdated: Date(),
                qrCodeId: UUID().uuidString,
                lastCheckIn: Date(),
                note: "",
                manualAlertActive: false,
                isNonResponsive: false,
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 24 * 60 * 60,
                manualAlertTimestamp: nil
            )
        },
        updateContactStatus: { id, status in
            Contact(
                id: id,
                userID: UUID(),
                name: "Updated Contact",
                phoneNumber: "+1234567890",
                relationship: .responder,
                status: status,
                lastUpdated: Date(),
                qrCodeId: UUID().uuidString,
                lastCheckIn: Date(),
                note: "",
                manualAlertActive: false,
                isNonResponsive: false,
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 24 * 60 * 60,
                manualAlertTimestamp: nil
            )
        },
        removeContact: { _ in },
        uploadAvatar: { _ in URL(string: "https://example.com/avatar.jpg")! }
    )
    
    static let testValue = APIClient(
        getUser: { uid in
            User(
                id: UUID(),
                firebaseUID: uid,
                name: "Test User",
                phoneNumber: "+1234567890"
            )
        },
        createUser: { uid, name, phone in
            User(
                id: UUID(),
                firebaseUID: uid,
                name: name,
                phoneNumber: phone
            )
        },
        updateUser: { user in user },
        getContacts: { Contact.mockContacts() },
        addContact: { phone in
            Contact(
                id: UUID(),
                userID: UUID(),
                name: "Test Contact",
                phoneNumber: phone,
                relationship: .responder,
                status: .active,
                lastUpdated: Date(),
                qrCodeId: UUID().uuidString,
                lastCheckIn: Date(),
                note: "",
                manualAlertActive: false,
                isNonResponsive: false,
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 24 * 60 * 60,
                manualAlertTimestamp: nil
            )
        },
        updateContactStatus: { id, status in
            Contact(
                id: id,
                userID: UUID(),
                name: "Test Contact",
                phoneNumber: "+1234567890",
                relationship: .responder,
                status: status,
                lastUpdated: Date(),
                qrCodeId: UUID().uuidString,
                lastCheckIn: Date(),
                note: "",
                manualAlertActive: false,
                isNonResponsive: false,
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 24 * 60 * 60,
                manualAlertTimestamp: nil
            )
        },
        removeContact: { _ in },
        uploadAvatar: { _ in URL(string: "https://test.com/avatar.jpg")! }
    )
}

extension DependencyValues {
    var apiClient: APIClient {
        get { self[APIClient.self] }
        set { self[APIClient.self] = newValue }
    }
}