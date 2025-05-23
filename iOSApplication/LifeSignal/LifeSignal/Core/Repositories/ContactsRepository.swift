import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation

// MARK: - Contact Repository

@DependencyClient
struct ContactRepository {
    var getContacts: @Sendable () async throws -> [Contact]
    var addContact: @Sendable (String) async throws -> Contact
    var updateContactStatus: @Sendable (UUID, Contact.Status) async throws -> Contact
    var updateContactOptimistically: @Sendable (Contact, Contact.Status) async throws -> Contact
    var removeContact: @Sendable (UUID) async throws -> Void
    var startContactStream: @Sendable () -> AsyncStream<Contact> = { AsyncStream { _ in } }
    var stopContactStream: @Sendable () -> Void
    var syncOfflineActions: @Sendable () async throws -> Void
    var queueOfflineAction: @Sendable (OfflineAction) async -> Void
}

extension ContactRepository: DependencyKey {
    static let liveValue: ContactRepository = {
        @Dependency(\.grpcClient) var grpc
        @Dependency(\.firebaseAuth) var auth
        @Dependency(\.retryClient) var retry
        @Dependency(\.analytics) var analytics
        @Dependency(\.performance) var performance
        @Dependency(\.featureFlags) var featureFlags
        @Dependency(\.connectivity) var connectivity
        
        return ContactRepository(
            getContacts: {
                let trace = performance.startTrace("contacts.get")
                defer { performance.endTrace(trace, [:]) }
                
                let request = GetContactsRequest(firebaseUID: auth.getCurrentUID() ?? "")
                let response = try await retry.withRetry(
                    { try await grpc.contactService.getContacts(request) },
                    maxAttempts: 3,
                    baseDelay: .seconds(1)
                ) as? GetContactsResponse
                
                guard let response = response else {
                    throw ContactRepositoryError.networkError
                }
                return response.contacts.map { $0.toDomain() }
            },
            
            addContact: { phoneNumber in
                let trace = performance.startTrace("contacts.add")
                defer { performance.endTrace(trace, ["phoneNumber": phoneNumber]) }
                
                let request = AddContactRequest(
                    firebaseUID: auth.getCurrentUID() ?? "",
                    phoneNumber: phoneNumber,
                    relationship: .responder
                )
                let proto = try await grpc.contactService.addContact(request)
                let contact = proto.toDomain()
                
                await analytics.track(.contactAdded(phoneNumber: phoneNumber))
                
                return contact
            },
            
            updateContactStatus: { contactID, status in
                let trace = performance.startTrace("contacts.update_status")
                defer { performance.endTrace(trace, ["contact_id": contactID.uuidString, "status": status.rawValue]) }
                
                let request = UpdateContactStatusRequest(
                    contactID: contactID.uuidString,
                    status: status.toProto()
                )
                let proto = try await grpc.contactService.updateContactStatus(request)
                return proto.toDomain()
            },
            
            updateContactOptimistically: { contact, status in
                // For optimistic updates with rollback capability
                let oldStatus = contact.status
                let request = UpdateContactStatusRequest(
                    contactID: contact.id.uuidString,
                    status: status.toProto()
                )
                
                do {
                    let proto = try await grpc.contactService.updateContactStatus(request)
                    let updatedContact = proto.toDomain()
                    
                    await analytics.track(.contactStatusChanged(from: oldStatus, to: status))
                    
                    return updatedContact
                } catch {
                    // Rollback will be handled by the calling feature
                    throw error
                }
            },
            
            removeContact: { contactID in
                let trace = performance.startTrace("contacts.remove")
                defer { performance.endTrace(trace, ["contact_id": contactID.uuidString]) }
                
                let request = RemoveContactRequest(contactID: contactID.uuidString)
                try await grpc.contactService.removeContact(request)
            },
            
            startContactStream: {
                let request = StreamContactUpdatesRequest(firebaseUID: auth.getCurrentUID() ?? "")
                let protoStream = grpc.contactService.streamContactUpdates(request)
                return AsyncStream<Contact> { continuation in
                    Task {
                        for await protoContact in protoStream {
                            continuation.yield(protoContact.toDomain())
                        }
                        continuation.finish()
                    }
                }
            },
            
            stopContactStream: {
                // gRPC streams cancelled via Task cancellation
            },
            
            syncOfflineActions: {
                // Implementation for syncing queued offline actions
                let trace = performance.startTrace("contacts.sync_offline")
                defer { performance.endTrace(trace, [:]) }
                
                // This would read from local storage and replay actions
                print("🔄 Syncing offline actions...")
            },
            
            queueOfflineAction: { action in
                // Implementation for queuing offline actions
                print("📝 Queued offline action: \(action)")
            }
        )
    }()
    
    static let testValue = ContactRepository(
        getContacts: { Contact.mockContacts() },
        addContact: { phoneNumber in
            Contact(
                id: UUID(),
                userID: UUID(),
                name: "New Contact",
                phoneNumber: phoneNumber,
                relationship: .responder,
                status: .active,
                lastUpdated: Date(),
                qrCodeId: UUID().uuidString,
                lastCheckIn: nil,
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
        updateContactStatus: { _, status in
            var contact = Contact.mockContacts().first!
            contact.status = status
            return contact
        },
        updateContactOptimistically: { contact, status in
            var updatedContact = contact
            updatedContact.status = status
            return updatedContact
        },
        removeContact: { _ in },
        startContactStream: {
            AsyncStream { continuation in
                continuation.finish()
            }
        },
        stopContactStream: { },
        syncOfflineActions: { },
        queueOfflineAction: { _ in }
    )
}

extension DependencyValues {
    var contactRepository: ContactRepository {
        get { self[ContactRepository.self] }
        set { self[ContactRepository.self] = newValue }
    }
}

// MARK: - Error Types

enum ContactRepositoryError: Error, LocalizedError {
    case networkError
    case contactNotFound
    case addFailed
    case updateFailed
    
    var errorDescription: String? {
        switch self {
        case .networkError: return "Network error occurred"
        case .contactNotFound: return "Contact not found"
        case .addFailed: return "Failed to add contact"
        case .updateFailed: return "Failed to update contact"
        }
    }
}