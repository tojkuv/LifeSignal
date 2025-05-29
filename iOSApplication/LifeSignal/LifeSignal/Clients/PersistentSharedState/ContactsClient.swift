import Foundation
import UIKit
import ComposableArchitecture
import Dependencies
import DependenciesMacros
@_exported import Sharing

// MARK: - Contacts Shared State

struct ContactsClientState: Equatable, Codable {
    var contacts: [Contact]
    var lastSyncTimestamp: Date?
    var isLoading: Bool
    
    init(
        contacts: [Contact] = [],
        lastSyncTimestamp: Date? = nil,
        isLoading: Bool = false
    ) {
        self.contacts = contacts
        self.lastSyncTimestamp = lastSyncTimestamp
        self.isLoading = isLoading
    }
}

// MARK: - Clean Shared Key Implementation (FileStorage)

extension SharedReaderKey where Self == FileStorageKey<ContactsClientState>.Default {
    static var contactsInternalState: Self {
        Self[.fileStorage(.documentsDirectory.appending(component: "contactsInternalState.json")), default: ContactsClientState()]
    }
}

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

// MARK: - Mock Contacts Backend Service

/// Simple mock backend for contacts data persistence
final class MockContactsBackendService: Sendable {
    
    // Simple data storage keys
    private static let contactsKey = "MockContactsBackend_Contacts"
    
    // MARK: - Data Persistence
    
    private func getStoredContacts() -> [Contact] {
        guard let data = UserDefaults.standard.data(forKey: Self.contactsKey),
              let decoded = try? JSONDecoder().decode([Contact].self, from: data) else {
            return []
        }
        return decoded
    }
    
    private func storeContacts(_ contacts: [Contact]) {
        guard let data = try? JSONEncoder().encode(contacts) else { return }
        UserDefaults.standard.set(data, forKey: Self.contactsKey)
    }
    
    // MARK: - Simple Operations
    
    func getContacts() -> [Contact] {
        let stored = getStoredContacts()
        if stored.isEmpty {
            // Return mock contacts if none stored
            return createMockContacts()
        }
        return stored
    }
    
    func addContact(_ contact: Contact) {
        var contacts = getStoredContacts()
        contacts.append(contact)
        storeContacts(contacts)
    }
    
    func updateContact(_ contact: Contact) {
        var contacts = getStoredContacts()
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[index] = contact
            storeContacts(contacts)
        }
    }
    
    func deleteContact(id: UUID) {
        var contacts = getStoredContacts()
        contacts.removeAll { $0.id == id }
        storeContacts(contacts)
    }
    
    private func createMockContacts() -> [Contact] {
        let mockContacts = [
            Contact(
                id: UUID(uuidString: "99999999-9999-9999-9999-999999999001")!,
                name: "John Doe",
                phoneNumber: "+1234567890",
                isResponder: true,
                isDependent: false,
                emergencyNote: "Emergency contact",
                lastCheckInTimestamp: Date().addingTimeInterval(-3600), // 1 hour ago
                checkInInterval: 86400,
                hasIncomingPing: false,
                hasOutgoingPing: false,
                hasManualAlertActive: false,
                hasNotResponsiveAlert: false,
                profileImageURL: "https://example.com/profile/john_doe.jpg",
                dateAdded: Date().addingTimeInterval(-604800),
                lastUpdated: Date()
            ),
            Contact(
                id: UUID(uuidString: "99999999-9999-9999-9999-999999999002")!,
                name: "Jane Smith",
                phoneNumber: "+0987654321",
                isResponder: false,
                isDependent: true,
                emergencyNote: "Dependent contact",
                lastCheckInTimestamp: Date().addingTimeInterval(-7200), // 2 hours ago
                checkInInterval: 43200,
                hasIncomingPing: true,
                hasOutgoingPing: false,
                hasManualAlertActive: false,
                hasNotResponsiveAlert: true,
                profileImageURL: nil,
                dateAdded: Date().addingTimeInterval(-259200),
                lastUpdated: Date()
            ),
            Contact(
                id: UUID(uuidString: "99999999-9999-9999-9999-999999999003")!,
                name: "Lisa Thompson",
                phoneNumber: "+1555123456",
                isResponder: true,
                isDependent: false,
                emergencyNote: "Has severe allergies to peanuts",
                lastCheckInTimestamp: Date().addingTimeInterval(-1800), // 30 minutes ago
                checkInInterval: 86400,
                hasIncomingPing: false,
                hasOutgoingPing: false,
                hasManualAlertActive: false,
                hasNotResponsiveAlert: false,
                profileImageURL: nil,
                dateAdded: Date().addingTimeInterval(-432000),
                lastUpdated: Date()
            )
        ]
        
        storeContacts(mockContacts)
        return mockContacts
    }
    
    // Helper method to clear all backend data for testing
    static func clearAllBackendData() {
        UserDefaults.standard.removeObject(forKey: contactsKey)
    }
}

// MARK: - Simple Contact Service Protocol (for mock implementation)

protocol SimpleContactServiceProtocol: Sendable {
    func getContacts(userId: UUID, authToken: String) async throws -> [Contact]
    func addContact(name: String, phoneNumber: String, isResponder: Bool, isDependent: Bool, userId: UUID, authToken: String) async throws -> Contact
    func updateContact(_ contact: Contact, authToken: String) async throws -> Contact
    func deleteContact(id: UUID, authToken: String) async throws
    static func clearAllMockData()
}

// MARK: - Mock Contact Service (Simple interface)

final class MockContactService: SimpleContactServiceProtocol, Sendable {
    
    private let backend = MockContactsBackendService()
    func getContacts(userId: UUID, authToken: String) async throws -> [Contact] {
        try await Task.sleep(for: .milliseconds(500))
        return backend.getContacts()
    }
    
    func addContact(name: String, phoneNumber: String, isResponder: Bool, isDependent: Bool, userId: UUID, authToken: String) async throws -> Contact {
        try await Task.sleep(for: .milliseconds(800))
        
        let newContact = Contact(
            id: UUID(),
            name: name,
            phoneNumber: phoneNumber,
            isResponder: isResponder,
            isDependent: isDependent,
            emergencyNote: "",
            lastCheckInTimestamp: nil,
            checkInInterval: 86400,
            hasIncomingPing: false,
            hasOutgoingPing: false,
            hasManualAlertActive: false,
            hasNotResponsiveAlert: false,
            profileImageURL: nil,
            dateAdded: Date(),
            lastUpdated: Date()
        )
        
        backend.addContact(newContact)
        return newContact
    }
    
    func updateContact(_ contact: Contact, authToken: String) async throws -> Contact {
        try await Task.sleep(for: .milliseconds(600))
        backend.updateContact(contact)
        return contact
    }
    
    func deleteContact(id: UUID, authToken: String) async throws {
        try await Task.sleep(for: .milliseconds(500))
        backend.deleteContact(id: id)
    }
    
    // Helper method to clear all mock data for testing
    static func clearAllMockData() {
        MockContactsBackendService.clearAllBackendData()
    }
}

// MARK: - Mock gRPC Adapter (converts simple service to gRPC protocol)

final class MockContactServiceGRPCAdapter: ContactServiceProtocol, Sendable {
    
    private let simpleService = MockContactService()
    
    func getContacts(_ request: GetContactsRequest) async throws -> GetContactsResponse {
        let contacts = try await simpleService.getContacts(userId: request.userId, authToken: request.authToken)
        let contactProtos = contacts.map { $0.toProto() }
        return GetContactsResponse(contacts: contactProtos)
    }
    
    func addContact(_ request: AddContactRequest) async throws -> Contact_Proto {
        let contact = try await simpleService.addContact(
            name: request.name,
            phoneNumber: request.phoneNumber,
            isResponder: request.isResponder,
            isDependent: request.isDependent,
            userId: request.userId,
            authToken: request.authToken
        )
        return contact.toProto()
    }
    
    func removeContact(_ request: RemoveContactRequest) async throws -> Empty_Proto {
        try await simpleService.deleteContact(id: request.contactId, authToken: request.authToken)
        return Empty_Proto()
    }
    
    func streamContactUpdates(_ request: StreamContactUpdatesRequest) -> AsyncStream<Contact_Proto> {
        return AsyncStream { continuation in
            Task {
                // Mock gRPC streaming - simulates receiving contact updates from server
                for i in 0..<3 {
                    try? await Task.sleep(for: .seconds(5))
                    
                    // Generate a mock contact update
                    let contact = Contact(
                        id: UUID(),
                        name: "Streamed Contact \(i + 1)",
                        phoneNumber: "+1\(Int.random(in: 1000000000...9999999999))",
                        isResponder: true,
                        isDependent: false,
                        emergencyNote: "Streaming update \(i + 1)",
                        lastCheckInTimestamp: Date(),
                        checkInInterval: 86400,
                        hasIncomingPing: i % 2 == 0,
                        hasOutgoingPing: false,
                        hasManualAlertActive: i == 2,
                        hasNotResponsiveAlert: false,
                        profileImageURL: nil,
                        dateAdded: Date(),
                        lastUpdated: Date()
                    )
                    
                    continuation.yield(contact.toProto())
                }
                continuation.finish()
            }
        }
    }
}


// MARK: - Proto Mapping Extensions

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
            profileImageData: nil,
            dateAdded: Date(timeIntervalSince1970: TimeInterval(dateAdded)),
            lastUpdated: Date(timeIntervalSince1970: TimeInterval(lastUpdated))
        )
    }
}

extension Contact {
    func toProto() -> Contact_Proto {
        Contact_Proto(
            id: id.uuidString,
            name: name,
            phoneNumber: phoneNumber,
            isResponder: isResponder,
            isDependent: isDependent,
            emergencyNote: emergencyNote,
            lastCheckInTimestamp: lastCheckInTimestamp.map { Int64($0.timeIntervalSince1970) },
            checkInInterval: Int64(checkInInterval),
            hasIncomingPing: hasIncomingPing,
            hasOutgoingPing: hasOutgoingPing,
            hasManualAlertActive: hasManualAlertActive,
            hasNotResponsiveAlert: hasNotResponsiveAlert,
            incomingPingTimestamp: incomingPingTimestamp.map { Int64($0.timeIntervalSince1970) },
            outgoingPingTimestamp: outgoingPingTimestamp.map { Int64($0.timeIntervalSince1970) },
            emergencyAlertTimestamp: emergencyAlertTimestamp.map { Int64($0.timeIntervalSince1970) },
            notResponsiveAlertTimestamp: notResponsiveAlertTimestamp.map { Int64($0.timeIntervalSince1970) },
            profileImageURL: profileImageURL,
            dateAdded: Int64(dateAdded.timeIntervalSince1970),
            lastUpdated: Int64(lastUpdated.timeIntervalSince1970)
        )
    }
}

// MARK: - Contact Domain Model

struct Contact: Codable, Equatable, Identifiable, Sendable {
    // MARK: - Core Properties
    let id: UUID
    var name: String
    var phoneNumber: String
    var isResponder: Bool
    var isDependent: Bool
    var emergencyNote: String
    
    // MARK: - Check-in Properties
    var lastCheckInTimestamp: Date?
    var checkInInterval: TimeInterval
    
    // MARK: - Ping Status Properties
    var hasIncomingPing: Bool
    var hasOutgoingPing: Bool
    var incomingPingTimestamp: Date?
    var outgoingPingTimestamp: Date?
    
    // MARK: - Emergency Alert Properties
    var hasManualAlertActive: Bool
    var emergencyAlertTimestamp: Date?
    
    // MARK: - Non-Responsive Alert Properties
    var hasNotResponsiveAlert: Bool
    var notResponsiveAlertTimestamp: Date?
    
    // MARK: - Profile Image Properties
    var profileImageURL: String?
    var profileImageData: Data?
    
    // MARK: - Metadata
    var dateAdded: Date
    var lastUpdated: Date
    
    // MARK: - Computed Properties
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

// MARK: - ContactsClient Internal Helpers

extension ContactsClient {
}

// MARK: - ContactsClient (TCA Shared State Pattern)

@DependencyClient
struct ContactsClient {
    
    // MARK: - Service Integration (uses adapter for mock)
    var contactService: ContactServiceProtocol = MockContactServiceGRPCAdapter()
    
    // MARK: - Core CRUD Operations - Features must pass auth tokens
    var getContacts: @Sendable () async -> [Contact] = { [] }
    var getContact: @Sendable (UUID) async throws -> Contact? = { _ in nil }
    var getContactByQRCode: @Sendable (String) async throws -> Contact = { qrCodeId in
        throw ContactsClientError.contactNotFound("Contact not found for QR code: \(qrCodeId)")
    }
    var addContact: @Sendable (String, String, Bool, Bool, String, UUID) async throws -> Contact = { _, _, _, _, _, _ in
        throw ContactsClientError.saveFailed("Contact")
    }
    var removeContact: @Sendable (UUID, String) async throws -> Void = { _, _ in }
    var updateContact: @Sendable (Contact, String) async throws -> Contact = { contact, _ in contact }
    var refreshContacts: @Sendable (String, UUID) async throws -> Void = { _, _ in }
    
    // MARK: - Real-time Contact Updates (gRPC Streaming) - Features must pass auth tokens
    var startContactUpdatesStream: @Sendable (String, UUID) async throws -> Void = { _, _ in }
    var stopContactUpdatesStream: @Sendable () async -> Void = { }
    var contactUpdates: @Sendable () -> AsyncStream<Contact> = {
        AsyncStream { _ in }
    }
    
    // MARK: - State Management
    
    /// Clears contacts state (used for coordinated state clearing).
    var clearContactsState: @Sendable () async throws -> Void = { }
}

extension ContactsClient: DependencyKey {
    static let liveValue = ContactsClient()
    
    static let testValue = ContactsClient()
    
    static let mockValue = ContactsClient(
        getContacts: {
            @Shared(.contactsInternalState) var contactsState
            return contactsState.contacts
        },
        
        getContact: { contactId in
            try await Task.sleep(for: .milliseconds(300))
            
            @Shared(.contactsInternalState) var contactsState
            return contactsState.contacts.first { $0.id == contactId }
        },
        
        getContactByQRCode: { qrCodeId in
            try await Task.sleep(for: .milliseconds(500))
            
            // Validate QR code format first
            guard UUID(uuidString: qrCodeId) != nil else {
                throw ContactsClientError.contactNotFound("Invalid QR code format")
            }
            
            // Mock: Simulate 80% chance of finding a LifeSignal user
            let userFound = Double.random(in: 0...1) < 0.8
            
            if !userFound {
                // QR code is valid but no LifeSignal user found
                throw ContactsClientError.contactNotFound("QR code found but no LifeSignal user was found")
            }
            
            // Generate realistic mock contact data for the found user
            let contact = Contact(
                id: UUID(uuidString: qrCodeId) ?? UUID(),
                name: ["Sarah Johnson", "Mike Chen", "Emma Wilson", "David Rodriguez", "Lisa Thompson"].randomElement() ?? "John Doe",
                phoneNumber: "+1 \(Int.random(in: 100...999))-\(Int.random(in: 100...999))-\(Int.random(in: 1000...9999))",
                isResponder: true,
                isDependent: false,
                emergencyNote: ["Has severe allergies to peanuts", "Takes medication for heart condition", "Contact work if not reachable", "Lives alone - check neighbor if needed", "Has emergency key under flowerpot"].randomElement() ?? "No emergency information provided",
                lastCheckInTimestamp: Date().addingTimeInterval(-Double.random(in: 1800...43200)), // 30 min to 12 hours ago
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
        
        addContact: { name, phoneNumber, isResponder, isDependent, authToken, userId in
            let service = MockContactService()
            
            let newContact = try await service.addContact(
                name: name, 
                phoneNumber: phoneNumber, 
                isResponder: isResponder, 
                isDependent: isDependent,
                userId: userId,
                authToken: authToken
            )
            
            // Update shared state
            @Shared(.contactsInternalState) var contactsState
            $contactsState.withLock { state in
                state.contacts.append(newContact)
                state.lastSyncTimestamp = Date()
                state.isLoading = false
            }
            
            return newContact
        },
        
        removeContact: { contactId, authToken in
            let service = MockContactService()
            
            try await service.deleteContact(id: contactId, authToken: authToken)
            
            // Update shared state
            @Shared(.contactsInternalState) var contactsState
            $contactsState.withLock { state in
                state.contacts.removeAll { $0.id == contactId }
                state.lastSyncTimestamp = Date()
                state.isLoading = false
            }
        },
        
        updateContact: { updatedContact, authToken in
            let service = MockContactService()
            
            let finalContact = try await service.updateContact(updatedContact, authToken: authToken)
            
            // Update shared state
            @Shared(.contactsInternalState) var contactsState
            $contactsState.withLock { state in
                if let index = state.contacts.firstIndex(where: { $0.id == finalContact.id }) {
                    state.contacts[index] = finalContact
                }
                state.lastSyncTimestamp = Date()
                state.isLoading = false
            }
            
            return finalContact
        },
        
        refreshContacts: { authToken, userId in
            let service = MockContactService()
            
            let contacts = try await service.getContacts(userId: userId, authToken: authToken)
            
            // Check if we already have persisted contacts to avoid overwriting cleared pings
            @Shared(.contactsInternalState) var contactsState
            $contactsState.withLock { state in
                let existingContacts = state.contacts
                
                let finalContacts: [Contact]
                if existingContacts.isEmpty {
                    // First time or no persisted data - include mock data for visual testing
                    finalContacts = contacts + Contact.mockData
                } else {
                    // We have persisted data - preserve it and only add genuinely new contacts
                    let existingIds = Set(existingContacts.map(\.id))
                    let newServerContacts = contacts.filter { !existingIds.contains($0.id) }
                    finalContacts = existingContacts + newServerContacts
                }
                
                state.contacts = finalContacts
                state.lastSyncTimestamp = Date()
                state.isLoading = false
            }
        },
        
        startContactUpdatesStream: { authToken, userId in
            // Mock gRPC streaming start
        },
        
        stopContactUpdatesStream: {
            // Mock gRPC streaming stop
        },
        
        contactUpdates: {
            AsyncStream { continuation in
                Task {
                    // Mock gRPC streaming - simulates receiving contact updates from server
                    for i in 0..<3 {
                        try? await Task.sleep(for: .seconds(5))
                        
                        @Shared(.contactsInternalState) var contactsState
                        if let contact = contactsState.contacts.first {
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
                            $contactsState.withLock { state in
                                if let index = state.contacts.firstIndex(where: { $0.id == contact.id }) {
                                    state.contacts[index] = updatedContact
                                }
                                state.lastSyncTimestamp = Date()
                                state.isLoading = false
                            }
                            
                            continuation.yield(updatedContact)
                        }
                    }
                    continuation.finish()
                }
            }
        },
        
        clearContactsState: {
            @Shared(.contactsInternalState) var contactsState
            $contactsState.withLock { state in
                state.contacts = []
                state.lastSyncTimestamp = nil
                state.isLoading = false
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
    static let mockData: [Contact] = [
        // Active responder - recently checked in
        Contact(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Alice Johnson",
            phoneNumber: "+12345678901",
            isResponder: true,
            isDependent: false,
            emergencyNote: "Primary emergency contact",
            lastCheckInTimestamp: Date().addingTimeInterval(-1800),
            checkInInterval: 86400,
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
            dateAdded: Date().addingTimeInterval(-1209600),
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
            lastCheckInTimestamp: Date().addingTimeInterval(-7200),
            checkInInterval: 43200,
            hasIncomingPing: false,
            hasOutgoingPing: false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil,
            hasManualAlertActive: true,
            emergencyAlertTimestamp: Date().addingTimeInterval(-600),
            hasNotResponsiveAlert: false,
            notResponsiveAlertTimestamp: nil,
            profileImageURL: nil,
            profileImageData: nil,
            dateAdded: Date().addingTimeInterval(-1728000),
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
            lastCheckInTimestamp: Date().addingTimeInterval(-172800),
            checkInInterval: 86400,
            hasIncomingPing: false,
            hasOutgoingPing: true,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: Date().addingTimeInterval(-300),
            hasManualAlertActive: false,
            emergencyAlertTimestamp: nil,
            hasNotResponsiveAlert: false,
            notResponsiveAlertTimestamp: nil,
            profileImageURL: nil,
            profileImageData: nil,
            dateAdded: Date().addingTimeInterval(-518400),
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
            lastCheckInTimestamp: Date().addingTimeInterval(-14400),
            checkInInterval: 28800,
            hasIncomingPing: true,
            hasOutgoingPing: false,
            incomingPingTimestamp: Date().addingTimeInterval(-180),
            outgoingPingTimestamp: nil,
            hasManualAlertActive: false,
            emergencyAlertTimestamp: nil,
            hasNotResponsiveAlert: false,
            notResponsiveAlertTimestamp: nil,
            profileImageURL: "https://example.com/david.jpg",
            profileImageData: nil,
            dateAdded: Date().addingTimeInterval(-432000),
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
            lastCheckInTimestamp: Date().addingTimeInterval(-259200),
            checkInInterval: 86400,
            hasIncomingPing: false,
            hasOutgoingPing: false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil,
            hasManualAlertActive: false,
            emergencyAlertTimestamp: nil,
            hasNotResponsiveAlert: true,
            notResponsiveAlertTimestamp: Date().addingTimeInterval(-3600),
            profileImageURL: nil,
            profileImageData: nil,
            dateAdded: Date().addingTimeInterval(-345600),
            lastUpdated: Date()
        )
    ]
    
    static var mockDependents: [Contact] {
        mockData.filter { $0.isDependent }
    }
    
    static var mockResponders: [Contact] {
        mockData.filter { $0.isResponder }
    }
    
    static func mockContact(
        id: UUID = UUID(),
        name: String = "Test Contact",
        phoneNumber: String = "+1234567890",
        isResponder: Bool = false,
        isDependent: Bool = true,
        emergencyNote: String = "Test note",
        lastCheckInTimestamp: Date? = Date().addingTimeInterval(-Double.random(in: 3600...86400)), // 1-24 hours ago
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