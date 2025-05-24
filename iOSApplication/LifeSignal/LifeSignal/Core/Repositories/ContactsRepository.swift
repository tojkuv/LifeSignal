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
}

// MARK: - Repository

@DependencyClient
struct ContactRepository {
    var getContacts: @Sendable () async throws -> [Contact] = { [] }
    var getContact: @Sendable (UUID) async throws -> Contact? = { _ in nil }
    var addContact: @Sendable (String) async throws -> Contact = { _ in
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
    var saveContact: @Sendable (Contact) async throws -> Contact = { contact in contact }
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
}

extension ContactRepository: DependencyKey {
    static let liveValue = ContactRepository(
        getContacts: {
            // Simulate network delay
            try await Task.sleep(for: .milliseconds(500))
            return []
        },
        
        getContact: { id in
            // Simulate network delay
            try await Task.sleep(for: .milliseconds(300))
            return nil
        },
        
        addContact: { phoneNumber in
            @Dependency(\.analytics) var analytics
            
            // Simulate network delay
            try await Task.sleep(for: .milliseconds(800))
            
            let contact = Contact(
                id: UUID(),
                name: "",
                phoneNumber: phoneNumber,
                isResponder: true,
                isDependent: false,
                lastUpdated: Date(),
                emergencyNote: "",
                lastCheckInTime: nil,
                interval: 24 * 60 * 60, // 24 hours
                hasIncomingPing: false,
                hasOutgoingPing: false,
                manualAlertActive: false,
                incomingPingTimestamp: nil,
                outgoingPingTimestamp: nil,
                manualAlertTimestamp: nil
            )
            
            await analytics.track(.contactAdded(phoneNumber: phoneNumber))
            return contact
        },
        
        updateContact: { contact in
            @Dependency(\.analytics) var analytics
            
            // Simulate network delay
            try await Task.sleep(for: .milliseconds(500))
            
            var updatedContact = contact
            updatedContact.lastUpdated = Date()
            
            await analytics.track(.contactUpdated(contactId: contact.id, changeDescription: "contact updated"))
            return updatedContact
        },
        
        removeContact: { id in
            @Dependency(\.analytics) var analytics
            
            // Simulate network delay
            try await Task.sleep(for: .milliseconds(500))
            
            await analytics.track(.contactUpdated(contactId: id, changeDescription: "contact removed"))
        },
        
        saveContact: { contact in
            @Dependency(\.analytics) var analytics
            
            // Simulate network delay
            try await Task.sleep(for: .milliseconds(600))
            
            var savedContact = contact
            savedContact.lastUpdated = Date()
            
            await analytics.track(.contactUpdated(contactId: contact.id, changeDescription: "contact saved"))
            return savedContact
        },
        
        updateContactResponder: { contactId, isResponder in
            @Dependency(\.analytics) var analytics
            
            // Simulate network delay
            try await Task.sleep(for: .milliseconds(400))
            
            // In a real implementation, this would fetch the contact, update it, and save
            let updatedContact = Contact(
                id: contactId,
                name: "Updated Contact",
                phoneNumber: "+1234567890",
                isResponder: isResponder,
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
            
            await analytics.track(.contactResponderStatusChanged(contactId: contactId, isResponder: isResponder))
            return updatedContact
        },
        
        updateContactDependent: { contactId, isDependent in
            @Dependency(\.analytics) var analytics
            
            // Simulate network delay
            try await Task.sleep(for: .milliseconds(400))
            
            let updatedContact = Contact(
                id: contactId,
                name: "Updated Contact",
                phoneNumber: "+1234567890",
                isResponder: true,
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
            
            await analytics.track(.contactDependentStatusChanged(contactId: contactId, isDependent: isDependent))
            return updatedContact
        },
        
        updateContactPingStatus: { contactId, hasIncoming, hasOutgoing in
            @Dependency(\.analytics) var analytics
            
            // Simulate network delay
            try await Task.sleep(for: .milliseconds(400))
            
            let updatedContact = Contact(
                id: contactId,
                name: "Updated Contact",
                phoneNumber: "+1234567890",
                isResponder: true,
                isDependent: false,
                lastUpdated: Date(),
                emergencyNote: "",
                lastCheckInTime: nil,
                interval: 24 * 60 * 60,
                hasIncomingPing: hasIncoming,
                hasOutgoingPing: hasOutgoing,
                manualAlertActive: false,
                incomingPingTimestamp: hasIncoming ? Date() : nil,
                outgoingPingTimestamp: hasOutgoing ? Date() : nil,
                manualAlertTimestamp: nil
            )
            
            await analytics.track(.contactPingStatusChanged(contactId: contactId, hasIncoming: hasIncoming, hasOutgoing: hasOutgoing))
            return updatedContact
        },
        
        updateContactManualAlert: { contactId, isActive in
            @Dependency(\.analytics) var analytics
            
            // Simulate network delay
            try await Task.sleep(for: .milliseconds(400))
            
            let updatedContact = Contact(
                id: contactId,
                name: "Updated Contact",
                phoneNumber: "+1234567890",
                isResponder: true,
                isDependent: false,
                lastUpdated: Date(),
                emergencyNote: "",
                lastCheckInTime: nil,
                interval: 24 * 60 * 60,
                hasIncomingPing: false,
                hasOutgoingPing: false,
                manualAlertActive: isActive,
                incomingPingTimestamp: nil,
                outgoingPingTimestamp: nil,
                manualAlertTimestamp: isActive ? Date() : nil
            )
            
            await analytics.track(.contactManualAlertToggled(contactId: contactId, isActive: isActive))
            return updatedContact
        },
        
        updateContactCheckIn: { contactId, timestamp in
            @Dependency(\.analytics) var analytics
            
            // Simulate network delay
            try await Task.sleep(for: .milliseconds(400))
            
            let updatedContact = Contact(
                id: contactId,
                name: "Updated Contact",
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
            
            await analytics.track(.contactCheckInRecorded(contactId: contactId, timestamp: timestamp))
            return updatedContact
        },
        
        updateContactInterval: { contactId, interval in
            @Dependency(\.analytics) var analytics
            
            // Simulate network delay
            try await Task.sleep(for: .milliseconds(400))
            
            let updatedContact = Contact(
                id: contactId,
                name: "Updated Contact",
                phoneNumber: "+1234567890",
                isResponder: true,
                isDependent: false,
                lastUpdated: Date(),
                emergencyNote: "",
                lastCheckInTime: nil,
                interval: interval,
                hasIncomingPing: false,
                hasOutgoingPing: false,
                manualAlertActive: false,
                incomingPingTimestamp: nil,
                outgoingPingTimestamp: nil,
                manualAlertTimestamp: nil
            )
            
            await analytics.track(.contactIntervalChanged(contactId: contactId, newInterval: interval))
            return updatedContact
        },
        
        updateContactNote: { contactId, note in
            @Dependency(\.analytics) var analytics
            
            // Simulate network delay
            try await Task.sleep(for: .milliseconds(400))
            
            let updatedContact = Contact(
                id: contactId,
                name: "Updated Contact",
                phoneNumber: "+1234567890",
                isResponder: true,
                isDependent: false,
                lastUpdated: Date(),
                emergencyNote: note,
                lastCheckInTime: nil,
                interval: 24 * 60 * 60,
                hasIncomingPing: false,
                hasOutgoingPing: false,
                manualAlertActive: false,
                incomingPingTimestamp: nil,
                outgoingPingTimestamp: nil,
                manualAlertTimestamp: nil
            )
            
            await analytics.track(.contactUpdated(contactId: contactId, changeDescription: "emergency note updated"))
            return updatedContact
        },
        
        searchContacts: { query in
            // Simulate network delay
            try await Task.sleep(for: .milliseconds(300))
            return [] // In real implementation, this would search and return matching contacts
        }
    )
    
    static let testValue = ContactRepository()
}

extension DependencyValues {
    var contactRepository: ContactRepository {
        get { self[ContactRepository.self] }
        set { self[ContactRepository.self] = newValue }
    }
}
