import Foundation
import UIKit
import ComposableArchitecture
import Dependencies
import DependenciesMacros
@_exported import Sharing

// MARK: - gRPC Protocol Integration

protocol ContactServiceProtocol: Sendable {
    func getContacts(_ request: GetContactsRequest) async throws -> GetContactsResponse
    func addContact(_ request: AddContactRequest) async throws -> Contact_Proto
    func removeContact(_ request: RemoveContactRequest) async throws -> Empty_Proto
    func streamContactUpdates(_ request: StreamContactUpdatesRequest) -> AsyncStream<Contact_Proto>
}

// MARK: - gRPC Request/Response Types

struct GetContactsRequest: Sendable {
    let userId: UUID
    let authToken: String
}

struct GetContactsResponse: Sendable {
    let contacts: [Contact_Proto]
}

struct AddContactRequest: Sendable {
    let userId: UUID
    let phoneNumber: String
    let name: String
    let isResponder: Bool
    let isDependent: Bool
    let authToken: String
}


struct RemoveContactRequest: Sendable {
    let contactId: UUID
    let authToken: String
}

struct StreamContactUpdatesRequest: Sendable {
    let userId: UUID
    let authToken: String
}


// MARK: - gRPC Proto Types

struct Contact_Proto: Sendable {
    var id: String
    var name: String
    var phoneNumber: String
    var isResponder: Bool
    var isDependent: Bool
    var emergencyNote: String
    var lastCheckInTimestamp: Int64?
    var checkInInterval: Int64
    var hasIncomingPing: Bool
    var hasOutgoingPing: Bool
    var hasManualAlertActive: Bool
    var hasNotResponsiveAlert: Bool
    var incomingPingTimestamp: Int64?
    var outgoingPingTimestamp: Int64?
    var emergencyAlertTimestamp: Int64?
    var notResponsiveAlertTimestamp: Int64?
    var profileImageURL: String?
    var dateAdded: Int64
    var lastUpdated: Int64
}

// MARK: - Mock gRPC Service

final class MockContactService: ContactServiceProtocol {
    func getContacts(_ request: GetContactsRequest) async throws -> GetContactsResponse {
        try await Task.sleep(for: .milliseconds(500))

        let mockContacts = [
            Contact_Proto(
                id: UUID().uuidString,
                name: "John Doe",
                phoneNumber: "+1234567890",
                isResponder: true,
                isDependent: false,
                emergencyNote: "Emergency contact",
                lastCheckInTimestamp: Int64(Date().addingTimeInterval(-3600).timeIntervalSince1970),
                checkInInterval: 86400,
                hasIncomingPing: false,
                hasOutgoingPing: false,
                hasManualAlertActive: false,
                hasNotResponsiveAlert: false,
                incomingPingTimestamp: nil,
                outgoingPingTimestamp: nil,
                emergencyAlertTimestamp: nil,
                notResponsiveAlertTimestamp: nil,
                profileImageURL: "https://example.com/profile/john_doe.jpg",
                dateAdded: Int64(Date().addingTimeInterval(-604800).timeIntervalSince1970), // 1 week ago
                lastUpdated: Int64(Date().timeIntervalSince1970)
            ),
            Contact_Proto(
                id: UUID().uuidString,
                name: "Jane Smith",
                phoneNumber: "+0987654321",
                isResponder: false,
                isDependent: true,
                emergencyNote: "Dependent contact",
                lastCheckInTimestamp: nil,
                checkInInterval: 43200,
                hasIncomingPing: true,
                hasOutgoingPing: false,
                hasManualAlertActive: false,
                hasNotResponsiveAlert: true,
                incomingPingTimestamp: Int64(Date().addingTimeInterval(-1800).timeIntervalSince1970),
                outgoingPingTimestamp: nil,
                emergencyAlertTimestamp: nil,
                notResponsiveAlertTimestamp: Int64(Date().addingTimeInterval(-7200).timeIntervalSince1970),
                profileImageURL: nil,
                dateAdded: Int64(Date().addingTimeInterval(-259200).timeIntervalSince1970), // 3 days ago
                lastUpdated: Int64(Date().timeIntervalSince1970)
            )
        ]

        return GetContactsResponse(contacts: mockContacts)
    }

    func addContact(_ request: AddContactRequest) async throws -> Contact_Proto {
        try await Task.sleep(for: .milliseconds(800))
        return Contact_Proto(
            id: UUID().uuidString,
            name: request.name,
            phoneNumber: request.phoneNumber,
            isResponder: request.isResponder,
            isDependent: request.isDependent,
            emergencyNote: "",
            lastCheckInTimestamp: nil,
            checkInInterval: 86400,
            hasIncomingPing: false,
            hasOutgoingPing: false,
            hasManualAlertActive: false,
            hasNotResponsiveAlert: false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil,
            emergencyAlertTimestamp: nil,
            notResponsiveAlertTimestamp: nil,
            profileImageURL: nil,
            dateAdded: Int64(Date().timeIntervalSince1970),
            lastUpdated: Int64(Date().timeIntervalSince1970)
        )
    }


    func removeContact(_ request: RemoveContactRequest) async throws -> Empty_Proto {
        try await Task.sleep(for: .milliseconds(500))
        return Empty_Proto()
    }

    func streamContactUpdates(_ request: StreamContactUpdatesRequest) -> AsyncStream<Contact_Proto> {
        AsyncStream { continuation in
            Task {
                for i in 0..<5 {
                    try? await Task.sleep(for: .seconds(2))
                    let contact = Contact_Proto(
                        id: UUID().uuidString,
                        name: "Streamed Contact \(i)",
                        phoneNumber: "+123456789\(i)",
                        isResponder: i % 2 == 0,
                        isDependent: i % 2 == 1,
                        emergencyNote: "",
                        lastCheckInTimestamp: nil,
                        checkInInterval: 86400,
                        hasIncomingPing: false,
                        hasOutgoingPing: false,
                        hasManualAlertActive: false,
                        hasNotResponsiveAlert: false,
                        incomingPingTimestamp: nil,
                        outgoingPingTimestamp: nil,
                        emergencyAlertTimestamp: nil,
                        notResponsiveAlertTimestamp: nil,
                        profileImageURL: nil,
                        dateAdded: Int64(Date().timeIntervalSince1970),
                        lastUpdated: Int64(Date().timeIntervalSince1970)
                    )
                    continuation.yield(contact)
                }
                continuation.finish()
            }
        }
    }
}

// MARK: - Proto Mapping Extensions
//
// Converts Contact_Proto (gRPC) to Contact (domain model)
// 
// Key conversions:
// - id: String -> UUID  
// - timestamps: Int64 -> Date
// - checkInInterval: Int64 -> TimeInterval
// - profileImageData: Not in proto (local cache only)

extension Contact_Proto {
    func toDomain() -> Contact {
        Contact(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            phoneNumber: phoneNumber,
            isResponder: isResponder,
            isDependent: isDependent,
            emergencyNote: emergencyNote,
            lastCheckInTimestamp: lastCheckInTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            checkInInterval: TimeInterval(checkInInterval),
            hasIncomingPing: hasIncomingPing,
            hasOutgoingPing: hasOutgoingPing,
            incomingPingTimestamp: incomingPingTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            outgoingPingTimestamp: outgoingPingTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            hasManualAlertActive: hasManualAlertActive,
            emergencyAlertTimestamp: emergencyAlertTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            hasNotResponsiveAlert: hasNotResponsiveAlert,
            notResponsiveAlertTimestamp: notResponsiveAlertTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            profileImageURL: profileImageURL,
            profileImageData: nil, // Would be populated separately from image service
            dateAdded: Date(timeIntervalSince1970: TimeInterval(dateAdded)),
            lastUpdated: Date(timeIntervalSince1970: TimeInterval(lastUpdated))
        )
    }
}

// MARK: - Contacts Shared State

extension SharedReaderKey where Self == InMemoryKey<[Contact]>.Default {
    static var contacts: Self {
        Self[.inMemory("contacts"), default: []]
    }
}


// MARK: - Contact Domain Model
//
// This model exactly matches Contact_Proto with these additions:
// - profileImageData: Local cache of profile image (not sent over gRPC)
// - Computed properties for enhanced functionality

struct Contact: Codable, Equatable, Identifiable, Sendable {
    // MARK: - Core Properties (matches Contact_Proto)
    let id: UUID
    var name: String
    var phoneNumber: String
    var isResponder: Bool
    var isDependent: Bool
    var emergencyNote: String
    
    // MARK: - Check-in Properties (matches Contact_Proto)
    var lastCheckInTimestamp: Date?
    var checkInInterval: TimeInterval
    
    // MARK: - Ping Status Properties (matches Contact_Proto)
    var hasIncomingPing: Bool
    var hasOutgoingPing: Bool
    var incomingPingTimestamp: Date?
    var outgoingPingTimestamp: Date?
    
    // MARK: - Emergency Alert Properties (matches Contact_Proto)
    var hasManualAlertActive: Bool
    var emergencyAlertTimestamp: Date?
    
    // MARK: - Non-Responsive Alert Properties (matches Contact_Proto)
    var hasNotResponsiveAlert: Bool
    var notResponsiveAlertTimestamp: Date?
    
    // MARK: - Profile Image Properties
    var profileImageURL: String? // From Contact_Proto
    var profileImageData: Data?   // Local cache only (not in proto)
    
    // MARK: - Metadata (matches Contact_Proto)
    var dateAdded: Date
    var lastUpdated: Date
    
    // MARK: - Computed Properties
    
    /// Returns the contact's profile image from cached data
    var profileImage: UIImage? {
        guard let imageData = profileImageData else { return nil }
        return UIImage(data: imageData)
    }
}

// MARK: - Client Errors

enum ContactsClientError: Error, LocalizedError {
    case contactNotFound(String)
    case saveFailed(String) 
    case deleteFailed(String)
    case networkError(String)
    case streamingError(String)
    case authenticationRequired

    var errorDescription: String? {
        switch self {
        case .contactNotFound(let details):
            return "Contact not found: \(details)"
        case .saveFailed(let details):
            return "Save failed: \(details)"
        case .deleteFailed(let details):
            return "Delete failed: \(details)"
        case .networkError(let details):
            return "Network error: \(details)"
        case .streamingError(let details):
            return "Streaming error: \(details)"
        case .authenticationRequired:
            return "Authentication required"
        }
    }
}


// MARK: - Contacts Client
//
// The ContactsClient provides a simplified interface for contact management where:
// - CRUD operations (create, read, delete) are handled via standard API calls
// - Contact updates are received via gRPC streaming (no direct update API)
// - The streaming connection automatically updates shared state when contacts change
// - Features subscribe to shared state changes via @Shared(.contacts) for reactivity

// MARK: - ContactsClient Internal Helpers

extension ContactsClient {
    /// Gets the authenticated user info for ContactsClient operations
    private static func getAuthenticatedUserInfo() async throws -> (token: String, userId: UUID) {
        @Shared(.authenticationToken) var authToken
        @Shared(.currentUser) var currentUser
        
        guard let token = authToken else {
            throw ContactsClientError.authenticationRequired
        }
        
        guard let user = currentUser else {
            throw ContactsClientError.authenticationRequired
        }
        
        return (token: token, userId: user.id)
    }
}

@DependencyClient
struct ContactsClient {
    // MARK: - Service Integration
    var contactService: ContactServiceProtocol = MockContactService()
    
    // MARK: - Core CRUD Operations
    var getContacts: @Sendable () async -> [Contact] = { [] }
    var getContact: @Sendable (UUID) async throws -> Contact? = { _ in nil }
    var getContactByQRCode: @Sendable (String) async throws -> Contact = { qrCodeId in
        throw ContactsClientError.contactNotFound("Contact not found for QR code: \(qrCodeId)")
    }
    var addContact: @Sendable (String, String, Bool, Bool) async throws -> Contact = { _, _, _, _ in
        throw ContactsClientError.saveFailed("Contact")
    }
    var removeContact: @Sendable (UUID) async throws -> Void = { _ in }
    var updateContact: @Sendable (Contact) async -> Void = { _ in }
    var refreshContacts: @Sendable () async throws -> Void = { }
    
    // MARK: - Real-time Contact Updates (gRPC Streaming)
    var startContactUpdatesStream: @Sendable () async throws -> Void = { }
    var stopContactUpdatesStream: @Sendable () async -> Void = { }
    var contactUpdates: @Sendable () -> AsyncStream<Contact> = {
        AsyncStream { _ in }
    }
    
}

extension ContactsClient: DependencyKey {
    static let liveValue: ContactsClient = ContactsClient()
    static let testValue = ContactsClient()
    
    static let mockValue = ContactsClient(
        getContacts: {
            @Shared(.contacts) var contacts
            return contacts
        },
        
        getContact: { contactId in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(300))
            
            @Shared(.contacts) var contacts
            return contacts.first { $0.id == contactId }
        },
        
        getContactByQRCode: { qrCodeId in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(500))
            
            // Mock contact based on QR code ID
            let contact = Contact(
                id: UUID(),
                name: "John Doe",
                phoneNumber: "+1234567890",
                isResponder: true,
                isDependent: false,
                emergencyNote: "Emergency contact information",
                lastCheckInTimestamp: Date(),
                checkInInterval: 24 * 60 * 60,
                hasIncomingPing: false,
                hasOutgoingPing: false,
                incomingPingTimestamp: nil,
                outgoingPingTimestamp: nil,
                hasManualAlertActive: false,
                emergencyAlertTimestamp: nil,
                hasNotResponsiveAlert: false,
                notResponsiveAlertTimestamp: nil,
                profileImageURL: nil,
                profileImageData: nil,
                dateAdded: Date(),
                lastUpdated: Date()
            )
            
            return contact
        },
        
        addContact: { name, phoneNumber, isResponder, isDependent in
            let authInfo = try await Self.getAuthenticatedUserInfo()
            let service = MockContactService()
            
            let request = AddContactRequest(
                userId: authInfo.userId,
                phoneNumber: phoneNumber,
                name: name,
                isResponder: isResponder,
                isDependent: isDependent,
                authToken: authInfo.token
            )
            
            let contactProto = try await service.addContact(request)
            let newContact = contactProto.toDomain()
            
            // Update shared state
            @Shared(.contacts) var contacts
            $contacts.withLock { $0.append(newContact) }
            
            return newContact
        },
        
        
        removeContact: { contactId in
            let authInfo = try await Self.getAuthenticatedUserInfo()
            let service = MockContactService()
            
            let request = RemoveContactRequest(contactId: contactId, authToken: authInfo.token)
            _ = try await service.removeContact(request)
            
            @Shared(.contacts) var contacts
            $contacts.withLock { $0.removeAll { $0.id == contactId } }
        },
        
        updateContact: { updatedContact in
            @Shared(.contacts) var contacts
            $contacts.withLock { contacts in
                if let index = contacts.firstIndex(where: { $0.id == updatedContact.id }) {
                    contacts[index] = updatedContact
                }
            }
        },
        
        refreshContacts: {
            // For MVP/mock stage, ensure we have a current user set up
            @Shared(.currentUser) var currentUser
            @Shared(.authenticationToken) var authToken
            @Shared(.internalAuthUID) var authUID
            
            // If no user exists, set up mock user for visual testing
            if currentUser == nil {
                $currentUser.withLock { $0 = User.mock }
                $authToken.withLock { $0 = "mock-token" }
                $authUID.withLock { $0 = User.mock.id.uuidString }
            }
            
            let authInfo = try await Self.getAuthenticatedUserInfo()
            let service = MockContactService()
            
            let request = GetContactsRequest(userId: authInfo.userId, authToken: authInfo.token)
            let response = try await service.getContacts(request)
            let contacts = response.contacts.map { proto in
                proto.toDomain()
            }
            
            // Also include our comprehensive mock data for visual testing
            let allContacts = contacts + Contact.mockData
            
            @Shared(.contacts) var sharedContacts
            $sharedContacts.withLock { $0 = allContacts }
        },
        
        startContactUpdatesStream: {
            // Mock gRPC streaming start - establishes bidirectional stream
            // In production, this would connect to the gRPC streaming endpoint
        },
        
        stopContactUpdatesStream: {
            // Mock gRPC streaming stop - closes the stream connection
        },
        
        contactUpdates: {
            AsyncStream { continuation in
                Task {
                    // Mock gRPC streaming - simulates receiving contact updates from server
                    for i in 0..<3 {
                        try? await Task.sleep(for: .seconds(5))
                        
                        @Shared(.contacts) var contacts
                        if let contact = contacts.first {
                            // Simulate a contact update from gRPC stream
                            let updatedContact = Contact(
                                id: contact.id,
                                name: contact.name,
                                phoneNumber: contact.phoneNumber,
                                isResponder: contact.isResponder,
                                isDependent: contact.isDependent,
                                emergencyNote: contact.emergencyNote,
                                lastCheckInTimestamp: i % 2 == 0 ? Date() : contact.lastCheckInTimestamp,
                                checkInInterval: contact.checkInInterval,
                                hasIncomingPing: i == 1,
                                hasOutgoingPing: contact.hasOutgoingPing,
                                incomingPingTimestamp: i == 1 ? Date() : contact.incomingPingTimestamp,
                                outgoingPingTimestamp: contact.outgoingPingTimestamp,
                                hasManualAlertActive: i == 2,
                                emergencyAlertTimestamp: i == 2 ? Date() : contact.emergencyAlertTimestamp,
                                hasNotResponsiveAlert: contact.hasNotResponsiveAlert,
                                notResponsiveAlertTimestamp: contact.notResponsiveAlertTimestamp,
                                profileImageURL: contact.profileImageURL,
                                profileImageData: contact.profileImageData,
                                dateAdded: contact.dateAdded,
                                lastUpdated: Date()
                            )
                            
                            // Update shared state with streamed contact
                            $contacts.withLock { 
                                if let index = $0.firstIndex(where: { $0.id == contact.id }) {
                                    $0[index] = updatedContact
                                }
                            }
                            
                            continuation.yield(updatedContact)
                        }
                    }
                    continuation.finish()
                }
            }
        }
        
    )
}

extension DependencyValues {
    var contactsClient: ContactsClient {
        get { self[ContactsClient.self] }
        set { self[ContactsClient.self] = newValue }
    }
}

// MARK: - Mock Data Extensions

extension Contact {
    /// Mock contact data for testing various scenarios
    static let mockData: [Contact] = [
        // Active responder - recently checked in
        Contact(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Alice Johnson",
            phoneNumber: "+12345678901",
            isResponder: true,
            isDependent: false,
            emergencyNote: "Primary emergency contact",
            lastCheckInTimestamp: Date().addingTimeInterval(-1800), // 30 minutes ago
            checkInInterval: 86400, // 24 hours
            hasIncomingPing: false,
            hasOutgoingPing: false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil,
            hasManualAlertActive: false,
            emergencyAlertTimestamp: nil,
            hasNotResponsiveAlert: false,
            notResponsiveAlertTimestamp: nil,
            profileImageURL: "https://example.com/alice.jpg",
            profileImageData: nil,
            dateAdded: Date().addingTimeInterval(-1209600), // 14 days ago
            lastUpdated: Date()
        ),
        
        // Dependent with active alert
        Contact(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Bob Smith",
            phoneNumber: "+12345678902",
            isResponder: false,
            isDependent: true,
            emergencyNote: "Lives alone, requires daily check-ins",
            lastCheckInTimestamp: Date().addingTimeInterval(-7200), // 2 hours ago
            checkInInterval: 43200, // 12 hours
            hasIncomingPing: false,
            hasOutgoingPing: false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil,
            hasManualAlertActive: true,
            emergencyAlertTimestamp: Date().addingTimeInterval(-600), // 10 minutes ago
            hasNotResponsiveAlert: false,
            notResponsiveAlertTimestamp: nil,
            profileImageURL: nil,
            profileImageData: nil,
            dateAdded: Date().addingTimeInterval(-1728000), // 20 days ago
            lastUpdated: Date()
        ),
        
        // Dependent - overdue check-in
        Contact(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "Carol Davis",
            phoneNumber: "+12345678903",
            isResponder: false,
            isDependent: true,
            emergencyNote: "Weekly check-ins required",
            lastCheckInTimestamp: Date().addingTimeInterval(-172800), // 2 days ago
            checkInInterval: 86400, // 24 hours (overdue)
            hasIncomingPing: false,
            hasOutgoingPing: true,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: Date().addingTimeInterval(-300), // 5 minutes ago
            hasManualAlertActive: false,
            emergencyAlertTimestamp: nil,
            hasNotResponsiveAlert: false,
            notResponsiveAlertTimestamp: nil,
            profileImageURL: nil,
            profileImageData: nil,
            dateAdded: Date().addingTimeInterval(-518400), // 6 days ago
            lastUpdated: Date()
        ),
        
        // Both responder and dependent - incoming ping
        Contact(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            name: "David Wilson",
            phoneNumber: "+12345678904",
            isResponder: true,
            isDependent: true,
            emergencyNote: "Family member - backup contact",
            lastCheckInTimestamp: Date().addingTimeInterval(-14400), // 4 hours ago
            checkInInterval: 28800, // 8 hours
            hasIncomingPing: true,
            hasOutgoingPing: false,
            incomingPingTimestamp: Date().addingTimeInterval(-180), // 3 minutes ago
            outgoingPingTimestamp: nil,
            hasManualAlertActive: false,
            emergencyAlertTimestamp: nil,
            hasNotResponsiveAlert: false,
            notResponsiveAlertTimestamp: nil,
            profileImageURL: "https://example.com/david.jpg",
            profileImageData: nil,
            dateAdded: Date().addingTimeInterval(-432000), // 5 days ago
            lastUpdated: Date()
        ),
        
        // Not responsive alert
        Contact(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            name: "Emma Brown",
            phoneNumber: "+12345678905",
            isResponder: false,
            isDependent: true,
            emergencyNote: "Elderly dependent - medical conditions",
            lastCheckInTimestamp: Date().addingTimeInterval(-259200), // 3 days ago
            checkInInterval: 86400, // 24 hours (very overdue)
            hasIncomingPing: false,
            hasOutgoingPing: false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil,
            hasManualAlertActive: false,
            emergencyAlertTimestamp: nil,
            hasNotResponsiveAlert: true,
            notResponsiveAlertTimestamp: Date().addingTimeInterval(-3600), // 1 hour ago
            profileImageURL: nil,
            profileImageData: nil,
            dateAdded: Date().addingTimeInterval(-345600), // 4 days ago
            lastUpdated: Date()
        ),
        
        // Responder - no recent check-in
        Contact(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
            name: "Frank Miller",
            phoneNumber: "+12345678906",
            isResponder: true,
            isDependent: false,
            emergencyNote: "Backup emergency contact",
            lastCheckInTimestamp: nil, // Never checked in
            checkInInterval: 86400, // 24 hours
            hasIncomingPing: false,
            hasOutgoingPing: false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil,
            hasManualAlertActive: false,
            emergencyAlertTimestamp: nil,
            hasNotResponsiveAlert: false,
            notResponsiveAlertTimestamp: nil,
            profileImageURL: nil,
            profileImageData: nil,
            dateAdded: Date().addingTimeInterval(-345600), // 4 days ago
            lastUpdated: Date()
        ),
        
        // Recently active dependent
        Contact(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
            name: "Grace Taylor",
            phoneNumber: "+12345678907",
            isResponder: false,
            isDependent: true,
            emergencyNote: "College student - needs monitoring",
            lastCheckInTimestamp: Date().addingTimeInterval(-300), // 5 minutes ago
            checkInInterval: 21600, // 6 hours
            hasIncomingPing: false,
            hasOutgoingPing: false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil,
            hasManualAlertActive: false,
            emergencyAlertTimestamp: nil,
            hasNotResponsiveAlert: false,
            notResponsiveAlertTimestamp: nil,
            profileImageURL: "https://example.com/grace.jpg",
            profileImageData: nil,
            dateAdded: Date().addingTimeInterval(-172800), // 2 days ago
            lastUpdated: Date()
        ),
        
        // Contact with both incoming and outgoing pings (edge case)
        Contact(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!,
            name: "Henry Anderson",
            phoneNumber: "+12345678908",
            isResponder: true,
            isDependent: true,
            emergencyNote: "Family member with high activity",
            lastCheckInTimestamp: Date().addingTimeInterval(-10800), // 3 hours ago
            checkInInterval: 43200, // 12 hours
            hasIncomingPing: true,
            hasOutgoingPing: true,
            incomingPingTimestamp: Date().addingTimeInterval(-120), // 2 minutes ago
            outgoingPingTimestamp: Date().addingTimeInterval(-600), // 10 minutes ago
            hasManualAlertActive: false,
            emergencyAlertTimestamp: nil,
            hasNotResponsiveAlert: false,
            notResponsiveAlertTimestamp: nil,
            profileImageURL: nil,
            profileImageData: nil,
            dateAdded: Date().addingTimeInterval(-259200), // 3 days ago
            lastUpdated: Date()
        ),
        
        // Dependent with very old check-in (testing edge cases)
        Contact(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000009")!,
            name: "Ivy Chen",
            phoneNumber: "+12345678909",
            isResponder: false,
            isDependent: true,
            emergencyNote: "International contact",
            lastCheckInTimestamp: Date().addingTimeInterval(-2678400), // 31 days ago
            checkInInterval: 604800, // 7 days (very overdue)
            hasIncomingPing: false,
            hasOutgoingPing: false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil,
            hasManualAlertActive: false,
            emergencyAlertTimestamp: nil,
            hasNotResponsiveAlert: false,
            notResponsiveAlertTimestamp: nil,
            profileImageURL: nil,
            profileImageData: nil,
            dateAdded: Date().addingTimeInterval(-604800), // 7 days ago
            lastUpdated: Date()
        ),
        
        // Contact with all alerts active (stress test)
        Contact(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            name: "Jack Robinson",
            phoneNumber: "+12345678910",
            isResponder: true,
            isDependent: true,
            emergencyNote: "High-priority contact - all alerts active",
            lastCheckInTimestamp: Date().addingTimeInterval(-432000), // 5 days ago
            checkInInterval: 86400, // 24 hours (very overdue)
            hasIncomingPing: true,
            hasOutgoingPing: true,
            incomingPingTimestamp: Date().addingTimeInterval(-60), // 1 minute ago
            outgoingPingTimestamp: Date().addingTimeInterval(-300), // 5 minutes ago
            hasManualAlertActive: true,
            emergencyAlertTimestamp: Date().addingTimeInterval(-1800), // 30 minutes ago
            hasNotResponsiveAlert: true,
            notResponsiveAlertTimestamp: Date().addingTimeInterval(-7200), // 2 hours ago
            profileImageURL: "https://example.com/jack.jpg",
            profileImageData: nil,
            dateAdded: Date().addingTimeInterval(-86400), // 1 day ago
            lastUpdated: Date()
        )
    ]
    
    /// Filtered mock data for dependents only
    static var mockDependents: [Contact] {
        mockData.filter { $0.isDependent }
    }
    
    /// Filtered mock data for responders only
    static var mockResponders: [Contact] {
        mockData.filter { $0.isResponder }
    }
    
    /// Mock contact with specific characteristics for targeted testing
    static func mockContact(
        id: UUID = UUID(),
        name: String = "Test Contact",
        phoneNumber: String = "+1234567890",
        isResponder: Bool = false,
        isDependent: Bool = true,
        emergencyNote: String = "Test note",
        lastCheckInTimestamp: Date? = nil,
        checkInInterval: TimeInterval = 86400,
        hasIncomingPing: Bool = false,
        hasOutgoingPing: Bool = false,
        hasManualAlertActive: Bool = false,
        hasNotResponsiveAlert: Bool = false
    ) -> Contact {
        Contact(
            id: id,
            name: name,
            phoneNumber: phoneNumber,
            isResponder: isResponder,
            isDependent: isDependent,
            emergencyNote: emergencyNote,
            lastCheckInTimestamp: lastCheckInTimestamp,
            checkInInterval: checkInInterval,
            hasIncomingPing: hasIncomingPing,
            hasOutgoingPing: hasOutgoingPing,
            incomingPingTimestamp: hasIncomingPing ? Date().addingTimeInterval(-300) : nil,
            outgoingPingTimestamp: hasOutgoingPing ? Date().addingTimeInterval(-300) : nil,
            hasManualAlertActive: hasManualAlertActive,
            emergencyAlertTimestamp: hasManualAlertActive ? Date().addingTimeInterval(-600) : nil,
            hasNotResponsiveAlert: hasNotResponsiveAlert,
            notResponsiveAlertTimestamp: hasNotResponsiveAlert ? Date().addingTimeInterval(-3600) : nil,
            profileImageURL: nil,
            profileImageData: nil,
            dateAdded: Date(),
            lastUpdated: Date()
        )
    }
}