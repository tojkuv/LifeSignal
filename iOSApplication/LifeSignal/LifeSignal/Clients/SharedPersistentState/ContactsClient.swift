import Foundation
import UIKit
import ComposableArchitecture
import Dependencies
import DependenciesMacros
@_exported import Sharing

// MARK: - Shared State (Read-Only Wrapper Pattern)

// 1. Mutable internal state (private to Client)
struct ContactsState: Equatable, Codable {
    var contacts: [Contact] = []
    var lastSyncTimestamp: Date? = nil
    var isLoading: Bool = false
}

// 2. Read-only wrapper (prevents direct mutation)
struct ReadOnlyContactsState: Equatable, Codable {
    private let _state: ContactsState
    fileprivate init(_ state: ContactsState) { self._state = state }  // 🔑 Client can access (same file)
    
    // MARK: - Codable Implementation (Preserves Ownership Pattern)
    
    // Private coding keys to prevent external access
    private enum CodingKeys: String, CodingKey {
        case state = "_state"
    }
    
    // Decoder uses the fileprivate init - maintains ownership
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let state = try container.decode(ContactsState.self, forKey: .state)
        self.init(state)  // Uses fileprivate init - ownership preserved ✅
    }
    
    // Encoder exposes only the internal state
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(_state, forKey: .state)
    }
    
    // Read-only access
    var contacts: [Contact] { _state.contacts }
    var lastSyncTimestamp: Date? { _state.lastSyncTimestamp }
    var isLoading: Bool { _state.isLoading }
    var count: Int { _state.contacts.count }
    
    // Computed properties
    var responders: [Contact] { _state.contacts.filter(\.isResponder) }
    var dependents: [Contact] { _state.contacts.filter(\.isDependent) }
    
    func contact(by id: UUID) -> Contact? {
        _state.contacts.first { $0.id == id }
    }
    
    func contactIndex(for id: UUID) -> Int? {
        _state.contacts.firstIndex { $0.id == id }
    }
}

// MARK: - RawRepresentable Conformance for AppStorage (Preserves Ownership)

extension ReadOnlyContactsState: RawRepresentable {
    typealias RawValue = String
    
    // Convert to JSON string for storage
    var rawValue: String {
        do {
            let data = try JSONEncoder().encode(self)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            print("Failed to encode ReadOnlyContactsState: \(error)")
            return ""
        }
    }
    
    // Decode from JSON string - uses our ownership-preserving Codable init
    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8) else { return nil }
        do {
            self = try JSONDecoder().decode(ReadOnlyContactsState.self, from: data)
            // ☝️ This calls our custom init(from decoder:) which uses fileprivate init ✅
        } catch {
            print("Failed to decode ReadOnlyContactsState: \(error)")
            return nil
        }
    }
}

// 3. Shared key stores read-only wrapper with persistence
extension SharedReaderKey where Self == AppStorageKey<ReadOnlyContactsState>.Default {
    static var contacts: Self {
        Self[.appStorage("contacts"), default: ReadOnlyContactsState(ContactsState())]
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

// MARK: - Mock gRPC Service

final class MockContactService: ContactServiceProtocol {
    func getContacts(_ request: GetContactsRequest) async throws -> GetContactsResponse {
        try await Task.sleep(for: .milliseconds(500))

        let mockContacts = [
            Contact_Proto(
                id: "99999999-9999-9999-9999-999999999001", // Fixed UUID for John Doe
                name: "John Doe",
                phoneNumber: "+1234567890",
                isResponder: true,
                isDependent: false,
                emergencyNote: "Emergency contact",
                lastCheckInTimestamp: Int64(Date().addingTimeInterval(-3600).timeIntervalSince1970), // 1 hour ago
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
                dateAdded: Int64(Date().addingTimeInterval(-604800).timeIntervalSince1970),
                lastUpdated: Int64(Date().timeIntervalSince1970)
            ),
            Contact_Proto(
                id: "99999999-9999-9999-9999-999999999002", // Fixed UUID for Jane Smith
                name: "Jane Smith",
                phoneNumber: "+0987654321",
                isResponder: false,
                isDependent: true,
                emergencyNote: "Dependent contact",
                lastCheckInTimestamp: Int64(Date().addingTimeInterval(-7200).timeIntervalSince1970), // 2 hours ago
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
                dateAdded: Int64(Date().addingTimeInterval(-259200).timeIntervalSince1970),
                lastUpdated: Int64(Date().timeIntervalSince1970)
            ),
            Contact_Proto(
                id: "99999999-9999-9999-9999-999999999003", // Fixed UUID for Lisa Thompson
                name: "Lisa Thompson",
                phoneNumber: "+1555123456",
                isResponder: true,
                isDependent: false,
                emergencyNote: "Has severe allergies to peanuts",
                lastCheckInTimestamp: Int64(Date().addingTimeInterval(-1800).timeIntervalSince1970), // 30 minutes ago
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
                dateAdded: Int64(Date().addingTimeInterval(-432000).timeIntervalSince1970), // 5 days ago
                lastUpdated: Int64(Date().timeIntervalSince1970)
            ),
            Contact_Proto(
                id: "99999999-9999-9999-9999-999999999004", // Fixed UUID for Mike Chen
                name: "Mike Chen",
                phoneNumber: "+1555789012",
                isResponder: true,
                isDependent: false,
                emergencyNote: "Takes medication for heart condition",
                lastCheckInTimestamp: Int64(Date().addingTimeInterval(-10800).timeIntervalSince1970), // 3 hours ago
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
                dateAdded: Int64(Date().addingTimeInterval(-345600).timeIntervalSince1970), // 4 days ago
                lastUpdated: Int64(Date().timeIntervalSince1970)
            ),
            Contact_Proto(
                id: "99999999-9999-9999-9999-999999999005", // Fixed UUID for Sarah Johnson
                name: "Sarah Johnson",
                phoneNumber: "+1555345678",
                isResponder: false,
                isDependent: true,
                emergencyNote: "Contact work if not reachable",
                lastCheckInTimestamp: Int64(Date().addingTimeInterval(-5400).timeIntervalSince1970), // 1.5 hours ago
                checkInInterval: 43200, // 12 hours
                hasIncomingPing: false,
                hasOutgoingPing: false,
                hasManualAlertActive: false,
                hasNotResponsiveAlert: false,
                incomingPingTimestamp: nil,
                outgoingPingTimestamp: nil,
                emergencyAlertTimestamp: nil,
                notResponsiveAlertTimestamp: nil,
                profileImageURL: nil,
                dateAdded: Int64(Date().addingTimeInterval(-172800).timeIntervalSince1970), // 2 days ago
                lastUpdated: Int64(Date().timeIntervalSince1970)
            ),
            Contact_Proto(
                id: "99999999-9999-9999-9999-999999999006", // Fixed UUID for Emma Wilson
                name: "Emma Wilson",
                phoneNumber: "+1555901234",
                isResponder: true,
                isDependent: false,
                emergencyNote: "Lives alone - check neighbor if needed",
                lastCheckInTimestamp: Int64(Date().addingTimeInterval(-14400).timeIntervalSince1970), // 4 hours ago
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
                dateAdded: Int64(Date().addingTimeInterval(-86400).timeIntervalSince1970), // 1 day ago
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

// MARK: - ContactsClient (TCA Shared State Pattern)

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
    static let liveValue = ContactsClient()
    
    static let testValue = ContactsClient()
    
    static let mockValue = ContactsClient(
        getContacts: {
            @Shared(.contacts) var contacts
            return contacts.contacts
        },
        
        getContact: { contactId in
            try await Task.sleep(for: .milliseconds(300))
            
            @Shared(.contacts) var contacts
            return contacts.contact(by: contactId)
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
            
            // Update shared state via fileprivate init (ONLY Clients can do this)
            @Shared(.contacts) var sharedContactsState
            let mutableState = ContactsState(
                contacts: sharedContactsState.contacts + [newContact],
                lastSyncTimestamp: Date(),
                isLoading: false
            )
            $sharedContactsState.withLock { $0 = ReadOnlyContactsState(mutableState) }  // ✅ fileprivate access
            
            return newContact
        },
        
        removeContact: { contactId in
            let authInfo = try await Self.getAuthenticatedUserInfo()
            let service = MockContactService()
            
            let request = RemoveContactRequest(contactId: contactId, authToken: authInfo.token)
            _ = try await service.removeContact(request)
            
            // Update shared state via fileprivate init
            @Shared(.contacts) var sharedContactsState
            let updatedContacts = sharedContactsState.contacts.filter { $0.id != contactId }
            let mutableState = ContactsState(
                contacts: updatedContacts,
                lastSyncTimestamp: Date(),
                isLoading: false
            )
            $sharedContactsState.withLock { $0 = ReadOnlyContactsState(mutableState) }  // ✅ fileprivate access
        },
        
        updateContact: { updatedContact in
            // Update shared state via fileprivate init
            @Shared(.contacts) var sharedContactsState
            var contacts = sharedContactsState.contacts
            if let index = contacts.firstIndex(where: { $0.id == updatedContact.id }) {
                contacts[index] = updatedContact
            }
            
            let mutableState = ContactsState(
                contacts: contacts,
                lastSyncTimestamp: Date(),
                isLoading: false
            )
            $sharedContactsState.withLock { $0 = ReadOnlyContactsState(mutableState) }  // ✅ fileprivate access
        },
        
        refreshContacts: {
            // ContactsClient should NOT mutate SessionClient's state
            // If no authentication, SessionClient should handle this
            let authInfo = try await Self.getAuthenticatedUserInfo()
            let service = MockContactService()
            
            let request = GetContactsRequest(userId: authInfo.userId, authToken: authInfo.token)
            let response = try await service.getContacts(request)
            let contacts = response.contacts.map { proto in
                proto.toDomain()
            }
            
            // Check if we already have persisted contacts to avoid overwriting cleared pings
            @Shared(.contacts) var sharedContactsState
            let existingContacts = sharedContactsState.contacts
            
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
            
            // Update shared state via fileprivate init
            let mutableState = ContactsState(
                contacts: finalContacts,
                lastSyncTimestamp: Date(),
                isLoading: false
            )
            $sharedContactsState.withLock { $0 = ReadOnlyContactsState(mutableState) }  // ✅ fileprivate access
        },
        
        startContactUpdatesStream: {
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
                        
                        @Shared(.contacts) var sharedContactsState
                        if let contact = sharedContactsState.contacts.first {
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
                            
                            // Update shared state with streamed contact via fileprivate init
                            var contacts = sharedContactsState.contacts
                            if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
                                contacts[index] = updatedContact
                            }
                            
                            let mutableState = ContactsState(
                                contacts: contacts,
                                lastSyncTimestamp: Date(),
                                isLoading: false
                            )
                            $sharedContactsState.withLock { $0 = ReadOnlyContactsState(mutableState) }  // ✅ fileprivate access
                            
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