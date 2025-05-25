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
    func updateContact(_ request: UpdateContactRequest) async throws -> Contact_Proto
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

struct UpdateContactRequest: Sendable {
    let contactId: UUID
    let name: String?
    let isResponder: Bool?
    let isDependent: Bool?
    let emergencyNote: String?
    let checkInInterval: TimeInterval?
    let hasIncomingPing: Bool?
    let hasOutgoingPing: Bool?
    let hasEmergencyAlert: Bool?
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

struct Empty_Proto: Sendable {}

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
    var hasEmergencyAlert: Bool
    var incomingPingTimestamp: Int64?
    var outgoingPingTimestamp: Int64?
    var emergencyAlertTimestamp: Int64?
    var profileImageURL: String?
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
                hasEmergencyAlert: false,
                incomingPingTimestamp: nil,
                outgoingPingTimestamp: nil,
                emergencyAlertTimestamp: nil,
                profileImageURL: "https://example.com/profile/john_doe.jpg",
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
                hasEmergencyAlert: false,
                incomingPingTimestamp: Int64(Date().addingTimeInterval(-1800).timeIntervalSince1970),
                outgoingPingTimestamp: nil,
                emergencyAlertTimestamp: nil,
                profileImageURL: nil,
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
            hasEmergencyAlert: false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil,
            emergencyAlertTimestamp: nil,
            profileImageURL: nil,
            lastUpdated: Int64(Date().timeIntervalSince1970)
        )
    }

    func updateContact(_ request: UpdateContactRequest) async throws -> Contact_Proto {
        try await Task.sleep(for: .milliseconds(500))
        return Contact_Proto(
            id: request.contactId.uuidString,
            name: request.name ?? "Updated Contact",
            phoneNumber: "+1234567890",
            isResponder: request.isResponder ?? true,
            isDependent: request.isDependent ?? false,
            emergencyNote: request.emergencyNote ?? "",
            lastCheckInTimestamp: nil,
            checkInInterval: Int64(request.checkInInterval ?? 86400),
            hasIncomingPing: request.hasIncomingPing ?? false,
            hasOutgoingPing: request.hasOutgoingPing ?? false,
            hasEmergencyAlert: request.hasEmergencyAlert ?? false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil,
            emergencyAlertTimestamp: nil,
            profileImageURL: nil,
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
                        hasEmergencyAlert: false,
                        incomingPingTimestamp: nil,
                        outgoingPingTimestamp: nil,
                        emergencyAlertTimestamp: nil,
                        profileImageURL: nil,
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
            hasEmergencyAlert: hasEmergencyAlert,
            incomingPingTimestamp: incomingPingTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            outgoingPingTimestamp: outgoingPingTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            emergencyAlertTimestamp: emergencyAlertTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            profileImageURL: profileImageURL,
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

extension SharedReaderKey where Self == InMemoryKey<[PendingContactAction]>.Default {
    static var pendingContactActions: Self {
        Self[.inMemory("pendingContactActions"), default: []]
    }
}

// MARK: - Contact Persistence Models

struct PendingContactAction: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var operation: ContactOperation
    var payload: Data
    var createdAt: Date
    var attemptCount: Int
    var maxAttempts: Int
    var priority: ActionPriority
    
    enum ActionPriority: Int, Codable, CaseIterable {
        case low = 0
        case standard = 1
        case high = 2
        case critical = 3
    }
    
    enum ContactOperation: String, Codable, CaseIterable {
        case createContact = "contact.create"
        case updateContact = "contact.update"
        case deleteContact = "contact.delete"
    }
    
    init(
        id: UUID = UUID(),
        operation: ContactOperation,
        payload: Data,
        createdAt: Date = Date(),
        attemptCount: Int = 0,
        maxAttempts: Int = 3,
        priority: ActionPriority = .standard
    ) {
        self.id = id
        self.operation = operation
        self.payload = payload
        self.createdAt = createdAt
        self.attemptCount = attemptCount
        self.maxAttempts = maxAttempts
        self.priority = priority
    }
    
    var canRetry: Bool {
        attemptCount < maxAttempts
    }
    
    var isExpired: Bool {
        let expiryTime: TimeInterval = priority == .critical ? 86400 : 3600
        return Date().timeIntervalSince(createdAt) > expiryTime
    }
}

// MARK: - Contact Domain Model

struct Contact: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var phoneNumber: String
    var isResponder: Bool
    var isDependent: Bool
    var emergencyNote: String
    var lastCheckInTimestamp: Date?
    var checkInInterval: TimeInterval
    var hasIncomingPing: Bool
    var hasOutgoingPing: Bool
    var hasEmergencyAlert: Bool
    var incomingPingTimestamp: Date?
    var outgoingPingTimestamp: Date?
    var emergencyAlertTimestamp: Date?
    var profileImageURL: String?
    var profileImageData: Data?
    var lastUpdated: Date
    
    // Computed properties for profile image
    var profileImage: UIImage? {
        guard let imageData = profileImageData else { return nil }
        return UIImage(data: imageData)
    }
    
    // Deprecated compatibility properties
    @available(*, deprecated, message: "Use hasEmergencyAlert instead")
    var manualAlertActive: Bool { hasEmergencyAlert }
    
    @available(*, deprecated, message: "Use emergencyAlertTimestamp instead")
    var manualAlertTimestamp: Date? { emergencyAlertTimestamp }
    
    @available(*, deprecated, message: "Use lastCheckInTimestamp instead")
    var lastCheckInTime: Date? { lastCheckInTimestamp }
    
    @available(*, deprecated, message: "Use checkInInterval instead")
    var interval: TimeInterval { checkInInterval }
    
    @available(*, deprecated, message: "Use emergencyNote directly")
    var note: String { emergencyNote }
}

// MARK: - Client Errors

enum ContactsClientError: Error, LocalizedError {
    case contactNotFound(String)
    case saveFailed(String)
    case deleteFailed(String)
    case networkError(String)
    case invalidData(String)
    case streamingError(String)

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
        case .invalidData(let details):
            return "Invalid data: \(details)"
        case .streamingError(let details):
            return "Streaming error: \(details)"
        }
    }
}

// MARK: - Streaming Status

enum ContactStreamingStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case error(String)

    var displayText: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .reconnecting: return "Reconnecting..."
        case .error(let message): return "Error: \(message)"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

// MARK: - Contacts Client

// MARK: - Contact Persistence Helpers

extension ContactsClient {
    static func getAuthenticationToken() async throws -> String {
        @Dependency(\.authenticationClient) var authClient
        guard let token = try await authClient.getIdToken(false) else {
            throw ContactsClientError.networkError("No authentication token available")
        }
        return token
    }
    
    // For backward compatibility during transition
    static func getAuthToken() async throws -> String {
        return try await getAuthenticationToken()
    }
    
    static func storeContactsData(_ contacts: [Contact], key: String = "contacts") async {
        // Mock local storage - would use Core Data/file system in production
        try? await Task.sleep(for: .milliseconds(50))
    }
    
    static func retrieveContactsData<T>(_ key: String, type: T.Type) async -> T? {
        // Mock retrieval - would load from Core Data/file system in production
        try? await Task.sleep(for: .milliseconds(50))
        return nil
    }
    
    static func addPendingContactAction(_ operation: PendingContactAction.ContactOperation, payload: Data, priority: PendingContactAction.ActionPriority) async {
        @Shared(.pendingContactActions) var pending
        let action = PendingContactAction(
            operation: operation,
            payload: payload,
            priority: priority
        )
        $pending.withLock { $0.append(action) }
    }
    
    static func executeWithNetworkFallback<T>(
        _ networkOperation: @escaping () async throws -> T,
        pendingOperation: PendingContactAction.ContactOperation? = nil,
        priority: PendingContactAction.ActionPriority = .standard
    ) async throws -> T {
        @Dependency(\.networkClient) var network
        
        let isConnected = await network.checkConnectivity()
        
        if isConnected {
            do {
                let result = try await networkOperation()
                // Store successful result locally
                if let contacts = result as? [Contact] {
                    await Self.storeContactsData(contacts)
                }
                return result
            } catch {
                if let operation = pendingOperation {
                    await Self.addPendingContactAction(operation, payload: Data(), priority: priority)
                }
                throw error
            }
        } else {
            // Queue operation for later synchronization
            if let operation = pendingOperation {
                await Self.addPendingContactAction(operation, payload: Data(), priority: priority)
            }
            
            throw ContactsClientError.networkError("Operation requires network connectivity")
        }
    }
}

@DependencyClient
struct ContactsClient {
    // gRPC service integration
    var contactService: ContactServiceProtocol = MockContactService()
    
    // CRUD operations that sync with shared state
    var getContacts: @Sendable () async -> [Contact] = { [] }
    var getContact: @Sendable (UUID) async throws -> Contact? = { _ in nil }
    var addContact: @Sendable (String, String, Bool, Bool) async throws -> Contact = { _, _, _, _ in
        throw ContactsClientError.saveFailed("Contact")
    }
    var removeContact: @Sendable (UUID) async throws -> Void = { _ in }
    
    // Specific update operations that sync with shared state
    var updateContactResponder: @Sendable (UUID, Bool) async throws -> Contact = { _, _ in
        throw ContactsClientError.saveFailed("ContactResponder")
    }
    var updateContactDependent: @Sendable (UUID, Bool) async throws -> Contact = { _, _ in
        throw ContactsClientError.saveFailed("ContactDependent")
    }
    var updateContactOutgoingPingStatus: @Sendable (UUID, Bool) async throws -> Contact = { _, _ in
        throw ContactsClientError.saveFailed("ContactOutgoingPingStatus")
    }
    
    // Real-time streaming
    var startStreaming: @Sendable () async throws -> Void = { }
    var stopStreaming: @Sendable () async -> Void = { }
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
        
        addContact: { name, phoneNumber, isResponder, isDependent in
            return try await Self.executeWithNetworkFallback({
                let authToken = try await Self.getAuthenticationToken()
                let service = MockContactService()
                @Dependency(\.userClient) var userClient
                
                guard let currentUser = await userClient.getCurrentUser() else {
                    throw ContactsClientError.saveFailed("No current user available")
                }
                
                let request = AddContactRequest(
                    userId: currentUser.id,
                    phoneNumber: phoneNumber,
                    name: name,
                    isResponder: isResponder,
                    isDependent: isDependent,
                    authToken: authToken
                )
                
                let contactProto = try await service.addContact(request)
                let newContact = contactProto.toDomain()
                
                // Update shared state
                @Shared(.contacts) var contacts
                $contacts.withLock { $0.append(newContact) }
                
                return newContact
            }, pendingOperation: .createContact, priority: .standard)
        },
        
        updateContact: { contact in
            let authToken = try await Self.getAuthToken()
            let service = MockContactService()
            
            let request = UpdateContactRequest(
                contactId: contact.id,
                name: contact.name,
                isResponder: contact.isResponder,
                isDependent: contact.isDependent,
                emergencyNote: contact.emergencyNote,
                checkInInterval: contact.checkInInterval,
                hasIncomingPing: contact.hasIncomingPing,
                hasOutgoingPing: contact.hasOutgoingPing,
                hasEmergencyAlert: contact.hasEmergencyAlert,
                authToken: authToken
            )
            
            let contactProto = try await service.updateContact(request)
            let updatedContact = contactProto.toDomain()
            
            @Shared(.contacts) var contacts
            if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
                $contacts.withLock { $0[index] = updatedContact }
                return updatedContact
            }
            
            throw ContactsClientError.contactNotFound("Contact with ID \(contact.id) not found")
        },
        
        removeContact: { contactId in
            let authToken = try await Self.getAuthToken()
            let service = MockContactService()
            
            let request = RemoveContactRequest(contactId: contactId, authToken: authToken)
            _ = try await service.removeContact(request)
            
            @Shared(.contacts) var contacts
            $contacts.withLock { $0.removeAll { $0.id == contactId } }
        },
        
        updateContactResponder: { contactId, isResponder in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(300))
            
            @Shared(.contacts) var contacts
            if let index = contacts.firstIndex(where: { $0.id == contactId }) {
                $contacts.withLock { 
                    $0[index].isResponder = isResponder
                    $0[index].lastUpdated = Date()
                }
                return contacts[index]
            }
            
            throw ContactsClientError.contactNotFound("Contact with ID \(contactId) not found")
        },
        
        updateContactDependent: { contactId, isDependent in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(300))
            
            @Shared(.contacts) var contacts
            if let index = contacts.firstIndex(where: { $0.id == contactId }) {
                $contacts.withLock { 
                    $0[index].isDependent = isDependent
                    $0[index].lastUpdated = Date()
                }
                return contacts[index]
            }
            
            throw ContactsClientError.contactNotFound("Contact with ID \(contactId) not found")
        },
        
        updateContactPingStatus: { contactId, hasIncoming, hasOutgoing in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(200))
            
            @Shared(.contacts) var contacts
            if let index = contacts.firstIndex(where: { $0.id == contactId }) {
                $contacts.withLock { 
                    $0[index].hasIncomingPing = hasIncoming
                    $0[index].hasOutgoingPing = hasOutgoing
                    $0[index].incomingPingTimestamp = hasIncoming ? Date() : nil
                    $0[index].outgoingPingTimestamp = hasOutgoing ? Date() : nil
                    $0[index].lastUpdated = Date()
                }
                return contacts[index]
            }
            
            throw ContactsClientError.contactNotFound("Contact with ID \(contactId) not found")
        },
        
        
        streamingStatus: {
            return .connected
        },
        
        startStreaming: {
            // Mock streaming start - always succeeds
        },
        
        stopStreaming: {
            // Mock streaming stop - always succeeds
        },
        
        contactUpdates: {
            AsyncStream { continuation in
                // Mock stream that doesn't emit any updates
                continuation.finish()
            }
        },
        
    )
}

extension DependencyValues {
    var contactsClient: ContactsClient {
        get { self[ContactsClient.self] }
        set { self[ContactsClient.self] = newValue }
    }
}