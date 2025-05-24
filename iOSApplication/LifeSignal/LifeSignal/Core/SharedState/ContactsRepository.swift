import Foundation
import ComposableArchitecture
import Dependencies
import DependenciesMacros

// MARK: - Domain Model

struct Contact: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var phoneNumber: String
    var isResponder: Bool
    var isDependent: Bool
    var lastUpdated: Date
    var emergencyNote: String
    var lastCheckInTime: Date?
    var interval: TimeInterval
    var hasIncomingPing: Bool
    var hasOutgoingPing: Bool
    var manualAlertActive: Bool
    var incomingPingTimestamp: Date?
    var outgoingPingTimestamp: Date?
    var manualAlertTimestamp: Date?
    
    // Additional properties for UI compatibility
    var note: String { emergencyNote }
    var checkInInterval: TimeInterval { interval }
}

// MARK: - Contact Repository Error

enum ContactRepositoryError: Error, LocalizedError {
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

// MARK: - Unified Contact Repository

@DependencyClient
struct ContactRepository {
    // CRUD operations
    var getContacts: @Sendable () async throws -> [Contact] = { [] }
    var getContact: @Sendable (UUID) async throws -> Contact? = { _ in nil }
    var addContact: @Sendable (String, String, Bool, Bool) async throws -> Contact = { _, _, _, _ in
        Contact(
            id: UUID(),
            name: "",
            phoneNumber: "",
            isResponder: true,
            isDependent: false,
            lastUpdated: Date(),
            emergencyNote: "",
            lastCheckInTime: nil,
            interval: 24 * 60 * 60,
            hasIncomingPing: false,
            hasOutgoingPing: false,
            manualAlertActive: false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil,
            manualAlertTimestamp: nil
        )
    }
    var updateContact: @Sendable (Contact) async throws -> Contact = { contact in contact }
    var removeContact: @Sendable (UUID) async throws -> Void = { _ in }

    // Specific update operations
    var updateContactResponder: @Sendable (UUID, Bool) async throws -> Contact = { _, _ in
        Contact(
            id: UUID(),
            name: "",
            phoneNumber: "",
            isResponder: true,
            isDependent: false,
            lastUpdated: Date(),
            emergencyNote: "",
            lastCheckInTime: nil,
            interval: 24 * 60 * 60,
            hasIncomingPing: false,
            hasOutgoingPing: false,
            manualAlertActive: false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil,
            manualAlertTimestamp: nil
        )
    }
    var updateContactDependent: @Sendable (UUID, Bool) async throws -> Contact = { _, _ in
        Contact(
            id: UUID(),
            name: "",
            phoneNumber: "",
            isResponder: true,
            isDependent: false,
            lastUpdated: Date(),
            emergencyNote: "",
            lastCheckInTime: nil,
            interval: 24 * 60 * 60,
            hasIncomingPing: false,
            hasOutgoingPing: false,
            manualAlertActive: false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil,
            manualAlertTimestamp: nil
        )
    }
    var updateContactPingStatus: @Sendable (UUID, Bool, Bool) async throws -> Contact = { _, _, _ in
        Contact(
            id: UUID(),
            name: "",
            phoneNumber: "",
            isResponder: true,
            isDependent: false,
            lastUpdated: Date(),
            emergencyNote: "",
            lastCheckInTime: nil,
            interval: 24 * 60 * 60,
            hasIncomingPing: false,
            hasOutgoingPing: false,
            manualAlertActive: false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil,
            manualAlertTimestamp: nil
        )
    }
    var updateContactManualAlert: @Sendable (UUID, Bool) async throws -> Contact = { _, _ in
        Contact(
            id: UUID(),
            name: "",
            phoneNumber: "",
            isResponder: true,
            isDependent: false,
            lastUpdated: Date(),
            emergencyNote: "",
            lastCheckInTime: nil,
            interval: 24 * 60 * 60,
            hasIncomingPing: false,
            hasOutgoingPing: false,
            manualAlertActive: false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil,
            manualAlertTimestamp: nil
        )
    }
    var updateContactCheckIn: @Sendable (UUID, Date) async throws -> Contact = { _, _ in
        Contact(
            id: UUID(),
            name: "",
            phoneNumber: "",
            isResponder: true,
            isDependent: false,
            lastUpdated: Date(),
            emergencyNote: "",
            lastCheckInTime: nil,
            interval: 24 * 60 * 60,
            hasIncomingPing: false,
            hasOutgoingPing: false,
            manualAlertActive: false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil,
            manualAlertTimestamp: nil
        )
    }
    var updateContactInterval: @Sendable (UUID, TimeInterval) async throws -> Contact = { _, _ in
        Contact(
            id: UUID(),
            name: "",
            phoneNumber: "",
            isResponder: true,
            isDependent: false,
            lastUpdated: Date(),
            emergencyNote: "",
            lastCheckInTime: nil,
            interval: 24 * 60 * 60,
            hasIncomingPing: false,
            hasOutgoingPing: false,
            manualAlertActive: false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil,
            manualAlertTimestamp: nil
        )
    }
    var updateContactNote: @Sendable (UUID, String) async throws -> Contact = { _, _ in
        Contact(
            id: UUID(),
            name: "",
            phoneNumber: "",
            isResponder: true,
            isDependent: false,
            lastUpdated: Date(),
            emergencyNote: "",
            lastCheckInTime: nil,
            interval: 24 * 60 * 60,
            hasIncomingPing: false,
            hasOutgoingPing: false,
            manualAlertActive: false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil,
            manualAlertTimestamp: nil
        )
    }
    var searchContacts: @Sendable (String) async throws -> [Contact] = { _ in [] }

    // Real-time streaming - integrated into repository
    var streamingStatus: @Sendable () async -> ContactStreamingStatus = { .disconnected }
    var startStreaming: @Sendable () async throws -> Void = { }
    var stopStreaming: @Sendable () async -> Void = { }
    var contactUpdates: @Sendable () -> AsyncStream<Contact> = {
        AsyncStream { _ in }
    }

    // Shared state management
    var observeContacts: @Sendable () -> AsyncStream<[Contact]> = {
        AsyncStream { _ in }
    }
    var getCurrentContacts: @Sendable () async -> [Contact] = { [] }
}

extension ContactRepository: DependencyKey {
    static let liveValue: ContactRepository = ContactRepository()
    static let testValue = ContactRepository()
    
    static let mockValue = ContactRepository(
        getContacts: {
            // Return mock contacts for demonstration
            return [
                Contact(
                    id: UUID(),
                    name: "Alice Johnson",
                    phoneNumber: "+1234567890",
                    isResponder: true,
                    isDependent: false,
                    lastUpdated: Date().addingTimeInterval(-3600),
                    emergencyNote: "Primary emergency contact",
                    lastCheckInTime: Date().addingTimeInterval(-1800),
                    interval: 24 * 60 * 60,
                    hasIncomingPing: false,
                    hasOutgoingPing: false,
                    manualAlertActive: false,
                    incomingPingTimestamp: nil,
                    outgoingPingTimestamp: nil,
                    manualAlertTimestamp: nil
                ),
                Contact(
                    id: UUID(),
                    name: "Bob Smith",
                    phoneNumber: "+1987654321",
                    isResponder: false,
                    isDependent: true,
                    lastUpdated: Date().addingTimeInterval(-7200),
                    emergencyNote: "Elderly parent, check daily",
                    lastCheckInTime: Date().addingTimeInterval(-43200),
                    interval: 12 * 60 * 60,
                    hasIncomingPing: true,
                    hasOutgoingPing: false,
                    manualAlertActive: false,
                    incomingPingTimestamp: Date().addingTimeInterval(-1800),
                    outgoingPingTimestamp: nil,
                    manualAlertTimestamp: nil
                ),
                Contact(
                    id: UUID(),
                    name: "Carol Davis",
                    phoneNumber: "+1555123456",
                    isResponder: true,
                    isDependent: false,
                    lastUpdated: Date().addingTimeInterval(-1800),
                    emergencyNote: "Backup contact",
                    lastCheckInTime: Date().addingTimeInterval(-900),
                    interval: 48 * 60 * 60,
                    hasIncomingPing: false,
                    hasOutgoingPing: false,
                    manualAlertActive: false,
                    incomingPingTimestamp: nil,
                    outgoingPingTimestamp: nil,
                    manualAlertTimestamp: nil
                )
            ]
        },
        
        getContact: { contactId in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(300))
            
            return Contact(
                id: contactId,
                name: "Mock Contact \(String(contactId.uuidString.prefix(8)))",
                phoneNumber: "+1234567890",
                isResponder: true,
                isDependent: false,
                lastUpdated: Date(),
                emergencyNote: "Mock contact for testing",
                lastCheckInTime: Date().addingTimeInterval(-3600),
                interval: 24 * 60 * 60,
                hasIncomingPing: false,
                hasOutgoingPing: false,
                manualAlertActive: false,
                incomingPingTimestamp: nil,
                outgoingPingTimestamp: nil,
                manualAlertTimestamp: nil
            )
        },
        
        addContact: { name, phoneNumber, isResponder, isDependent in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(500))
            
            return Contact(
                id: UUID(),
                name: name,
                phoneNumber: phoneNumber,
                isResponder: isResponder,
                isDependent: isDependent,
                lastUpdated: Date(),
                emergencyNote: "",
                lastCheckInTime: nil,
                interval: 24 * 60 * 60,
                hasIncomingPing: false,
                hasOutgoingPing: false,
                manualAlertActive: false,
                incomingPingTimestamp: nil,
                outgoingPingTimestamp: nil,
                manualAlertTimestamp: nil
            )
        },
        
        updateContact: { contact in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(400))
            
            // Return updated contact with new lastUpdated timestamp
            var updatedContact = contact
            updatedContact.lastUpdated = Date()
            return updatedContact
        },
        
        removeContact: { contactId in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(300))
            // Mock removal always succeeds
        },
        
        updateContactResponder: { contactId, isResponder in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(300))
            
            return Contact(
                id: contactId,
                name: "Updated Mock Contact",
                phoneNumber: "+1234567890",
                isResponder: isResponder,
                isDependent: false,
                lastUpdated: Date(),
                emergencyNote: "",
                lastCheckInTime: Date(),
                interval: 24 * 60 * 60,
                hasIncomingPing: false,
                hasOutgoingPing: false,
                manualAlertActive: false,
                incomingPingTimestamp: nil,
                outgoingPingTimestamp: nil,
                manualAlertTimestamp: nil
            )
        },
        
        updateContactDependent: { contactId, isDependent in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(300))
            
            return Contact(
                id: contactId,
                name: "Updated Mock Contact",
                phoneNumber: "+1234567890",
                isResponder: false,
                isDependent: isDependent,
                lastUpdated: Date(),
                emergencyNote: "",
                lastCheckInTime: Date(),
                interval: 24 * 60 * 60,
                hasIncomingPing: false,
                hasOutgoingPing: false,
                manualAlertActive: false,
                incomingPingTimestamp: nil,
                outgoingPingTimestamp: nil,
                manualAlertTimestamp: nil
            )
        },
        
        updateContactPingStatus: { contactId, hasIncoming, hasOutgoing in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(200))
            
            return Contact(
                id: contactId,
                name: "Updated Mock Contact",
                phoneNumber: "+1234567890",
                isResponder: true,
                isDependent: false,
                lastUpdated: Date(),
                emergencyNote: "",
                lastCheckInTime: Date(),
                interval: 24 * 60 * 60,
                hasIncomingPing: hasIncoming,
                hasOutgoingPing: hasOutgoing,
                manualAlertActive: false,
                incomingPingTimestamp: hasIncoming ? Date() : nil,
                outgoingPingTimestamp: hasOutgoing ? Date() : nil,
                manualAlertTimestamp: nil
            )
        },
        
        updateContactManualAlert: { contactId, isActive in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(200))
            
            return Contact(
                id: contactId,
                name: "Updated Mock Contact",
                phoneNumber: "+1234567890",
                isResponder: true,
                isDependent: false,
                lastUpdated: Date(),
                emergencyNote: "",
                lastCheckInTime: Date(),
                interval: 24 * 60 * 60,
                hasIncomingPing: false,
                hasOutgoingPing: false,
                manualAlertActive: isActive,
                incomingPingTimestamp: nil,
                outgoingPingTimestamp: nil,
                manualAlertTimestamp: isActive ? Date() : nil
            )
        },
        
        updateContactCheckIn: { contactId, timestamp in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(200))
            
            return Contact(
                id: contactId,
                name: "Updated Mock Contact",
                phoneNumber: "+1234567890",
                isResponder: true,
                isDependent: false,
                lastUpdated: Date(),
                emergencyNote: "",
                lastCheckInTime: timestamp,
                interval: 24 * 60 * 60,
                hasIncomingPing: false,
                hasOutgoingPing: false,
                manualAlertActive: false,
                incomingPingTimestamp: nil,
                outgoingPingTimestamp: nil,
                manualAlertTimestamp: nil
            )
        },
        
        updateContactInterval: { contactId, interval in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(200))
            
            return Contact(
                id: contactId,
                name: "Updated Mock Contact",
                phoneNumber: "+1234567890",
                isResponder: true,
                isDependent: false,
                lastUpdated: Date(),
                emergencyNote: "",
                lastCheckInTime: Date(),
                interval: interval,
                hasIncomingPing: false,
                hasOutgoingPing: false,
                manualAlertActive: false,
                incomingPingTimestamp: nil,
                outgoingPingTimestamp: nil,
                manualAlertTimestamp: nil
            )
        },
        
        updateContactNote: { contactId, note in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(200))
            
            return Contact(
                id: contactId,
                name: "Updated Mock Contact",
                phoneNumber: "+1234567890",
                isResponder: true,
                isDependent: false,
                lastUpdated: Date(),
                emergencyNote: note,
                lastCheckInTime: Date(),
                interval: 24 * 60 * 60,
                hasIncomingPing: false,
                hasOutgoingPing: false,
                manualAlertActive: false,
                incomingPingTimestamp: nil,
                outgoingPingTimestamp: nil,
                manualAlertTimestamp: nil
            )
        },
        
        searchContacts: { query in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(400))
            
            // Return filtered mock contacts based on query
            let mockContacts = [
                Contact(id: UUID(), name: "Alice Johnson", phoneNumber: "+1234567890", isResponder: true, isDependent: false, lastUpdated: Date(), emergencyNote: "", lastCheckInTime: nil, interval: 86400, hasIncomingPing: false, hasOutgoingPing: false, manualAlertActive: false, incomingPingTimestamp: nil, outgoingPingTimestamp: nil, manualAlertTimestamp: nil),
                Contact(id: UUID(), name: "Bob Smith", phoneNumber: "+1987654321", isResponder: false, isDependent: true, lastUpdated: Date(), emergencyNote: "", lastCheckInTime: nil, interval: 86400, hasIncomingPing: false, hasOutgoingPing: false, manualAlertActive: false, incomingPingTimestamp: nil, outgoingPingTimestamp: nil, manualAlertTimestamp: nil)
            ]
            return mockContacts.filter { contact in
                contact.name.localizedCaseInsensitiveContains(query) ||
                contact.phoneNumber.contains(query)
            }
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
        
        observeContacts: {
            AsyncStream { continuation in
                Task {
                    let mockContacts = [
                        Contact(id: UUID(), name: "Alice Johnson", phoneNumber: "+1234567890", isResponder: true, isDependent: false, lastUpdated: Date(), emergencyNote: "", lastCheckInTime: nil, interval: 86400, hasIncomingPing: false, hasOutgoingPing: false, manualAlertActive: false, incomingPingTimestamp: nil, outgoingPingTimestamp: nil, manualAlertTimestamp: nil)
                    ]
                    continuation.yield(mockContacts)
                    continuation.finish()
                }
            }
        },
        
        getCurrentContacts: {
            return [
                Contact(id: UUID(), name: "Alice Johnson", phoneNumber: "+1234567890", isResponder: true, isDependent: false, lastUpdated: Date(), emergencyNote: "", lastCheckInTime: nil, interval: 86400, hasIncomingPing: false, hasOutgoingPing: false, manualAlertActive: false, incomingPingTimestamp: nil, outgoingPingTimestamp: nil, manualAlertTimestamp: nil)
            ]
        }
    )
}

extension DependencyValues {
    var contactRepository: ContactRepository {
        get { self[ContactRepository.self] }
        set { self[ContactRepository.self] = newValue }
    }
}
