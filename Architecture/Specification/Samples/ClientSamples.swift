//
// ClientSamples.swift
// Sample implementations of client interfaces for the LifeSignal iOS application
//

import Foundation
import ComposableArchitecture
import FirebaseAuth
import FirebaseFirestore

// MARK: - User Client

/// A client for user operations
struct UserClient: Sendable {
    /// Get the current user
    var currentUser: @Sendable () async throws -> User
    
    /// Update the user's profile
    var updateProfile: @Sendable (String, String, String) async throws -> Void
    
    /// Update the user's profile image
    var updateProfileImage: @Sendable (Data) async throws -> URL
    
    /// Refresh the user's QR code ID
    var refreshQRCodeID: @Sendable () async throws -> UUID
    
    /// Stream user changes
    var userStream: @Sendable () async -> AsyncStream<User>
}

/// User client dependency key
extension UserClient: DependencyKey {
    /// Live implementation
    static var liveValue: Self {
        let adapter = FirebaseUserAdapter()
        
        return Self(
            currentUser: {
                try await adapter.currentUser()
            },
            updateProfile: { firstName, lastName, emergencyNote in
                try await adapter.updateProfile(
                    firstName: firstName,
                    lastName: lastName,
                    emergencyNote: emergencyNote
                )
            },
            updateProfileImage: { imageData in
                try await adapter.updateProfileImage(imageData: imageData)
            },
            refreshQRCodeID: {
                try await adapter.refreshQRCodeID()
            },
            userStream: {
                await adapter.userStream()
            }
        )
    }
    
    /// Test implementation
    static var testValue: Self {
        Self(
            currentUser: {
                User(
                    id: UUID(),
                    firstName: "Test",
                    lastName: "User",
                    phoneNumber: "+15555555555",
                    profileImageURL: nil,
                    emergencyNote: "Test emergency note",
                    checkInInterval: 24 * 3600,
                    reminderInterval: 2 * 3600,
                    lastCheckInTime: nil,
                    status: .active,
                    qrCodeID: UUID()
                )
            },
            updateProfile: { _, _, _ in
                // No-op in test
            },
            updateProfileImage: { _ in
                URL(string: "https://example.com/image.jpg")!
            },
            refreshQRCodeID: {
                UUID()
            },
            userStream: {
                AsyncStream { continuation in
                    let user = User(
                        id: UUID(),
                        firstName: "Test",
                        lastName: "User",
                        phoneNumber: "+15555555555",
                        profileImageURL: nil,
                        emergencyNote: "Test emergency note",
                        checkInInterval: 24 * 3600,
                        reminderInterval: 2 * 3600,
                        lastCheckInTime: nil,
                        status: .active,
                        qrCodeID: UUID()
                    )
                    continuation.yield(user)
                    continuation.finish()
                }
            }
        )
    }
    
    /// Preview implementation
    static var previewValue: Self {
        Self(
            currentUser: {
                User(
                    id: UUID(),
                    firstName: "John",
                    lastName: "Doe",
                    phoneNumber: "+15555555555",
                    profileImageURL: URL(string: "https://example.com/image.jpg"),
                    emergencyNote: "In case of emergency, contact Jane Doe at +15555555556",
                    checkInInterval: 24 * 3600,
                    reminderInterval: 2 * 3600,
                    lastCheckInTime: Date().addingTimeInterval(-12 * 3600),
                    status: .active,
                    qrCodeID: UUID()
                )
            },
            updateProfile: { _, _, _ in
                // No-op in preview
            },
            updateProfileImage: { _ in
                URL(string: "https://example.com/image.jpg")!
            },
            refreshQRCodeID: {
                UUID()
            },
            userStream: {
                AsyncStream { continuation in
                    let user = User(
                        id: UUID(),
                        firstName: "John",
                        lastName: "Doe",
                        phoneNumber: "+15555555555",
                        profileImageURL: URL(string: "https://example.com/image.jpg"),
                        emergencyNote: "In case of emergency, contact Jane Doe at +15555555556",
                        checkInInterval: 24 * 3600,
                        reminderInterval: 2 * 3600,
                        lastCheckInTime: Date().addingTimeInterval(-12 * 3600),
                        status: .active,
                        qrCodeID: UUID()
                    )
                    continuation.yield(user)
                    continuation.finish()
                }
            }
        )
    }
}

/// User client dependency values extension
extension DependencyValues {
    /// User client dependency
    var userClient: UserClient {
        get { self[UserClient.self] }
        set { self[UserClient.self] = newValue }
    }
}

// MARK: - Firebase User Adapter

/// A Firebase adapter for user operations
struct FirebaseUserAdapter {
    /// The Firebase Auth instance
    private let auth = Auth.auth()
    
    /// The Firebase Firestore instance
    private let db = Firestore.firestore()
    
    /// Get the current user
    func currentUser() async throws -> User {
        guard let userID = auth.currentUser?.uid else {
            throw UserError.notAuthenticated
        }
        
        let document = try await db.collection("users").document(userID).getDocument()
        
        guard let data = document.data() else {
            throw UserError.userNotFound
        }
        
        return try mapToUser(data, id: userID)
    }
    
    /// Update the user's profile
    func updateProfile(firstName: String, lastName: String, emergencyNote: String) async throws {
        guard let userID = auth.currentUser?.uid else {
            throw UserError.notAuthenticated
        }
        
        try await db.collection("users").document(userID).updateData([
            "firstName": firstName,
            "lastName": lastName,
            "emergencyNote": emergencyNote,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }
    
    /// Update the user's profile image
    func updateProfileImage(imageData: Data) async throws -> URL {
        guard let userID = auth.currentUser?.uid else {
            throw UserError.notAuthenticated
        }
        
        // Upload image to Firebase Storage
        let storageRef = Storage.storage().reference().child("users/\(userID)/profile.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        // Update user document with profile image URL
        try await db.collection("users").document(userID).updateData([
            "profileImageURL": downloadURL.absoluteString,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        return downloadURL
    }
    
    /// Refresh the user's QR code ID
    func refreshQRCodeID() async throws -> UUID {
        guard let userID = auth.currentUser?.uid else {
            throw UserError.notAuthenticated
        }
        
        let newQRCodeID = UUID()
        
        try await db.collection("users").document(userID).updateData([
            "qrCodeID": newQRCodeID.uuidString,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        return newQRCodeID
    }
    
    /// Stream user changes
    func userStream() async -> AsyncStream<User> {
        AsyncStream { continuation in
            guard let userID = auth.currentUser?.uid else {
                continuation.finish()
                return
            }
            
            let listener = db.collection("users").document(userID)
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        print("Error listening for user updates: \(error)")
                        return
                    }
                    
                    guard let snapshot = snapshot, let data = snapshot.data() else {
                        print("User document does not exist")
                        return
                    }
                    
                    do {
                        let user = try self.mapToUser(data, id: userID)
                        continuation.yield(user)
                    } catch {
                        print("Error mapping user data: \(error)")
                    }
                }
            
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
    
    /// Map Firestore data to a User model
    private func mapToUser(_ data: [String: Any], id: String) throws -> User {
        guard let firstName = data["firstName"] as? String,
              let lastName = data["lastName"] as? String,
              let phoneNumber = data["phoneNumber"] as? String,
              let checkInInterval = data["checkInInterval"] as? TimeInterval,
              let reminderInterval = data["reminderInterval"] as? TimeInterval,
              let statusString = data["status"] as? String,
              let qrCodeIDString = data["qrCodeID"] as? String else {
            throw UserError.invalidData
        }
        
        let profileImageURL = (data["profileImageURL"] as? String).flatMap { URL(string: $0) }
        let emergencyNote = data["emergencyNote"] as? String ?? ""
        
        let lastCheckInTime: Date?
        if let timestamp = data["lastCheckInTime"] as? Timestamp {
            lastCheckInTime = timestamp.dateValue()
        } else {
            lastCheckInTime = nil
        }
        
        guard let userID = UUID(uuidString: id),
              let qrCodeID = UUID(uuidString: qrCodeIDString),
              let status = UserStatus(rawValue: statusString) else {
            throw UserError.invalidData
        }
        
        return User(
            id: userID,
            firstName: firstName,
            lastName: lastName,
            phoneNumber: phoneNumber,
            profileImageURL: profileImageURL,
            emergencyNote: emergencyNote,
            checkInInterval: checkInInterval,
            reminderInterval: reminderInterval,
            lastCheckInTime: lastCheckInTime,
            status: status,
            qrCodeID: qrCodeID
        )
    }
}

// MARK: - User Model

/// A user model
struct User: Equatable, Identifiable, Sendable {
    /// The user's ID
    let id: UUID
    
    /// The user's first name
    var firstName: String
    
    /// The user's last name
    var lastName: String
    
    /// The user's phone number
    var phoneNumber: String
    
    /// The user's profile image URL
    var profileImageURL: URL?
    
    /// The user's emergency note
    var emergencyNote: String
    
    /// The user's check-in interval
    var checkInInterval: TimeInterval
    
    /// The user's reminder interval
    var reminderInterval: TimeInterval
    
    /// The user's last check-in time
    var lastCheckInTime: Date?
    
    /// The user's status
    var status: UserStatus
    
    /// The user's QR code ID
    var qrCodeID: UUID
    
    /// The user's full name
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    /// The user's initials
    var initials: String {
        let firstInitial = firstName.first.map(String.init) ?? ""
        let lastInitial = lastName.first.map(String.init) ?? ""
        return "\(firstInitial)\(lastInitial)"
    }
    
    /// The user's next check-in due time
    var nextCheckInDue: Date? {
        lastCheckInTime?.addingTimeInterval(checkInInterval)
    }
    
    /// Whether the user's check-in is overdue
    var isCheckInOverdue: Bool {
        guard let nextCheckInDue = nextCheckInDue else { return false }
        return nextCheckInDue < Date()
    }
}

/// A user status
enum UserStatus: String, Equatable, Sendable {
    /// The user is active
    case active
    
    /// The user is non-responsive
    case nonResponsive
    
    /// The user has an active alert
    case alertActive
}

// MARK: - User Error

/// An error that can occur during user operations
enum UserError: Error, Equatable {
    /// The user is not authenticated
    case notAuthenticated
    
    /// The user was not found
    case userNotFound
    
    /// The data is invalid
    case invalidData
    
    /// A network error occurred
    case networkError
    
    /// The user does not have permission
    case permissionDenied
    
    /// An unknown error occurred
    case unknown(String)
    
    /// Compare two user errors for equality
    static func == (lhs: UserError, rhs: UserError) -> Bool {
        switch (lhs, rhs) {
        case (.notAuthenticated, .notAuthenticated):
            return true
        case (.userNotFound, .userNotFound):
            return true
        case (.invalidData, .invalidData):
            return true
        case (.networkError, .networkError):
            return true
        case (.permissionDenied, .permissionDenied):
            return true
        case let (.unknown(lhsString), .unknown(rhsString)):
            return lhsString == rhsString
        default:
            return false
        }
    }
}

// MARK: - Contact Client

/// A client for contact operations
struct ContactClient: Sendable {
    /// Get all contacts
    var getContacts: @Sendable () async throws -> [Contact]
    
    /// Get a contact by ID
    var getContact: @Sendable (UUID) async throws -> Contact
    
    /// Add a contact
    var addContact: @Sendable (UUID, String, String, String, Bool, Bool) async throws -> Contact
    
    /// Update a contact
    var updateContact: @Sendable (Contact) async throws -> Void
    
    /// Remove a contact
    var removeContact: @Sendable (UUID) async throws -> Void
    
    /// Stream contact changes
    var contactsStream: @Sendable () async -> AsyncStream<[Contact]>
}

/// Contact client dependency key
extension ContactClient: DependencyKey {
    /// Live implementation
    static var liveValue: Self {
        let adapter = FirebaseContactAdapter()
        
        return Self(
            getContacts: {
                try await adapter.getContacts()
            },
            getContact: { contactID in
                try await adapter.getContact(contactID: contactID)
            },
            addContact: { contactID, firstName, lastName, phoneNumber, isResponder, isDependent in
                try await adapter.addContact(
                    contactID: contactID,
                    firstName: firstName,
                    lastName: lastName,
                    phoneNumber: phoneNumber,
                    isResponder: isResponder,
                    isDependent: isDependent
                )
            },
            updateContact: { contact in
                try await adapter.updateContact(contact: contact)
            },
            removeContact: { contactID in
                try await adapter.removeContact(contactID: contactID)
            },
            contactsStream: {
                await adapter.contactsStream()
            }
        )
    }
    
    /// Test implementation
    static var testValue: Self {
        Self(
            getContacts: {
                []
            },
            getContact: { _ in
                Contact(
                    id: UUID(),
                    userID: UUID(),
                    contactID: UUID(),
                    firstName: "Test",
                    lastName: "Contact",
                    phoneNumber: "+15555555555",
                    profileImageURL: nil,
                    isResponder: true,
                    isDependent: false,
                    status: .active,
                    lastCheckInTime: nil,
                    dateAdded: Date()
                )
            },
            addContact: { _, _, _, _, _, _ in
                Contact(
                    id: UUID(),
                    userID: UUID(),
                    contactID: UUID(),
                    firstName: "Test",
                    lastName: "Contact",
                    phoneNumber: "+15555555555",
                    profileImageURL: nil,
                    isResponder: true,
                    isDependent: false,
                    status: .active,
                    lastCheckInTime: nil,
                    dateAdded: Date()
                )
            },
            updateContact: { _ in
                // No-op in test
            },
            removeContact: { _ in
                // No-op in test
            },
            contactsStream: {
                AsyncStream { continuation in
                    continuation.yield([])
                    continuation.finish()
                }
            }
        )
    }
    
    /// Preview implementation
    static var previewValue: Self {
        Self(
            getContacts: {
                [
                    Contact(
                        id: UUID(),
                        userID: UUID(),
                        contactID: UUID(),
                        firstName: "John",
                        lastName: "Doe",
                        phoneNumber: "+15555555555",
                        profileImageURL: URL(string: "https://example.com/image.jpg"),
                        isResponder: true,
                        isDependent: false,
                        status: .active,
                        lastCheckInTime: Date().addingTimeInterval(-12 * 3600),
                        dateAdded: Date().addingTimeInterval(-7 * 24 * 3600)
                    ),
                    Contact(
                        id: UUID(),
                        userID: UUID(),
                        contactID: UUID(),
                        firstName: "Jane",
                        lastName: "Smith",
                        phoneNumber: "+15555555556",
                        profileImageURL: URL(string: "https://example.com/image2.jpg"),
                        isResponder: false,
                        isDependent: true,
                        status: .nonResponsive,
                        lastCheckInTime: Date().addingTimeInterval(-36 * 3600),
                        dateAdded: Date().addingTimeInterval(-14 * 24 * 3600)
                    )
                ]
            },
            getContact: { _ in
                Contact(
                    id: UUID(),
                    userID: UUID(),
                    contactID: UUID(),
                    firstName: "John",
                    lastName: "Doe",
                    phoneNumber: "+15555555555",
                    profileImageURL: URL(string: "https://example.com/image.jpg"),
                    isResponder: true,
                    isDependent: false,
                    status: .active,
                    lastCheckInTime: Date().addingTimeInterval(-12 * 3600),
                    dateAdded: Date().addingTimeInterval(-7 * 24 * 3600)
                )
            },
            addContact: { _, firstName, lastName, phoneNumber, isResponder, isDependent in
                Contact(
                    id: UUID(),
                    userID: UUID(),
                    contactID: UUID(),
                    firstName: firstName,
                    lastName: lastName,
                    phoneNumber: phoneNumber,
                    profileImageURL: nil,
                    isResponder: isResponder,
                    isDependent: isDependent,
                    status: .active,
                    lastCheckInTime: nil,
                    dateAdded: Date()
                )
            },
            updateContact: { _ in
                // No-op in preview
            },
            removeContact: { _ in
                // No-op in preview
            },
            contactsStream: {
                AsyncStream { continuation in
                    let contacts = [
                        Contact(
                            id: UUID(),
                            userID: UUID(),
                            contactID: UUID(),
                            firstName: "John",
                            lastName: "Doe",
                            phoneNumber: "+15555555555",
                            profileImageURL: URL(string: "https://example.com/image.jpg"),
                            isResponder: true,
                            isDependent: false,
                            status: .active,
                            lastCheckInTime: Date().addingTimeInterval(-12 * 3600),
                            dateAdded: Date().addingTimeInterval(-7 * 24 * 3600)
                        ),
                        Contact(
                            id: UUID(),
                            userID: UUID(),
                            contactID: UUID(),
                            firstName: "Jane",
                            lastName: "Smith",
                            phoneNumber: "+15555555556",
                            profileImageURL: URL(string: "https://example.com/image2.jpg"),
                            isResponder: false,
                            isDependent: true,
                            status: .nonResponsive,
                            lastCheckInTime: Date().addingTimeInterval(-36 * 3600),
                            dateAdded: Date().addingTimeInterval(-14 * 24 * 3600)
                        )
                    ]
                    continuation.yield(contacts)
                    continuation.finish()
                }
            }
        )
    }
}

/// Contact client dependency values extension
extension DependencyValues {
    /// Contact client dependency
    var contactClient: ContactClient {
        get { self[ContactClient.self] }
        set { self[ContactClient.self] = newValue }
    }
}

// MARK: - Firebase Contact Adapter

/// A Firebase adapter for contact operations
struct FirebaseContactAdapter {
    /// The Firebase Auth instance
    private let auth = Auth.auth()
    
    /// The Firebase Firestore instance
    private let db = Firestore.firestore()
    
    /// Get all contacts
    func getContacts() async throws -> [Contact] {
        guard let userID = auth.currentUser?.uid else {
            throw ContactError.notAuthenticated
        }
        
        let snapshot = try await db.collection("users").document(userID)
            .collection("contacts")
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try mapToContact(document.data(), id: document.documentID, userID: userID)
        }
    }
    
    /// Get a contact by ID
    func getContact(contactID: UUID) async throws -> Contact {
        guard let userID = auth.currentUser?.uid else {
            throw ContactError.notAuthenticated
        }
        
        let document = try await db.collection("users").document(userID)
            .collection("contacts")
            .document(contactID.uuidString)
            .getDocument()
        
        guard let data = document.data() else {
            throw ContactError.contactNotFound
        }
        
        return try mapToContact(data, id: document.documentID, userID: userID)
    }
    
    /// Add a contact
    func addContact(contactID: UUID, firstName: String, lastName: String, phoneNumber: String, isResponder: Bool, isDependent: Bool) async throws -> Contact {
        guard let userID = auth.currentUser?.uid else {
            throw ContactError.notAuthenticated
        }
        
        // Validate roles
        if !isResponder && !isDependent {
            throw ContactError.invalidRoles
        }
        
        let contactData: [String: Any] = [
            "contactID": contactID.uuidString,
            "firstName": firstName,
            "lastName": lastName,
            "phoneNumber": phoneNumber,
            "isResponder": isResponder,
            "isDependent": isDependent,
            "status": ContactStatus.active.rawValue,
            "dateAdded": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("users").document(userID)
            .collection("contacts")
            .document(contactID.uuidString)
            .setData(contactData)
        
        return Contact(
            id: contactID,
            userID: UUID(uuidString: userID)!,
            contactID: contactID,
            firstName: firstName,
            lastName: lastName,
            phoneNumber: phoneNumber,
            profileImageURL: nil,
            isResponder: isResponder,
            isDependent: isDependent,
            status: .active,
            lastCheckInTime: nil,
            dateAdded: Date()
        )
    }
    
    /// Update a contact
    func updateContact(contact: Contact) async throws {
        guard let userID = auth.currentUser?.uid else {
            throw ContactError.notAuthenticated
        }
        
        // Validate roles
        if !contact.isResponder && !contact.isDependent {
            throw ContactError.invalidRoles
        }
        
        let contactData: [String: Any] = [
            "firstName": contact.firstName,
            "lastName": contact.lastName,
            "phoneNumber": contact.phoneNumber,
            "isResponder": contact.isResponder,
            "isDependent": contact.isDependent,
            "status": contact.status.rawValue
        ]
        
        try await db.collection("users").document(userID)
            .collection("contacts")
            .document(contact.id.uuidString)
            .updateData(contactData)
    }
    
    /// Remove a contact
    func removeContact(contactID: UUID) async throws {
        guard let userID = auth.currentUser?.uid else {
            throw ContactError.notAuthenticated
        }
        
        try await db.collection("users").document(userID)
            .collection("contacts")
            .document(contactID.uuidString)
            .delete()
    }
    
    /// Stream contact changes
    func contactsStream() async -> AsyncStream<[Contact]> {
        AsyncStream { continuation in
            guard let userID = auth.currentUser?.uid else {
                continuation.yield([])
                continuation.finish()
                return
            }
            
            let listener = db.collection("users").document(userID)
                .collection("contacts")
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        print("Error listening for contact updates: \(error)")
                        return
                    }
                    
                    guard let snapshot = snapshot else {
                        print("Contact snapshot is nil")
                        return
                    }
                    
                    do {
                        let contacts = try snapshot.documents.compactMap { document in
                            try self.mapToContact(document.data(), id: document.documentID, userID: userID)
                        }
                        continuation.yield(contacts)
                    } catch {
                        print("Error mapping contacts: \(error)")
                    }
                }
            
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
    
    /// Map Firestore data to a Contact model
    private func mapToContact(_ data: [String: Any], id: String, userID: String) throws -> Contact {
        guard let contactIDString = data["contactID"] as? String,
              let firstName = data["firstName"] as? String,
              let lastName = data["lastName"] as? String,
              let phoneNumber = data["phoneNumber"] as? String,
              let isResponder = data["isResponder"] as? Bool,
              let isDependent = data["isDependent"] as? Bool,
              let statusString = data["status"] as? String else {
            throw ContactError.invalidData
        }
        
        let profileImageURL = (data["profileImageURL"] as? String).flatMap { URL(string: $0) }
        
        let lastCheckInTime: Date?
        if let timestamp = data["lastCheckInTime"] as? Timestamp {
            lastCheckInTime = timestamp.dateValue()
        } else {
            lastCheckInTime = nil
        }
        
        let dateAdded: Date
        if let timestamp = data["dateAdded"] as? Timestamp {
            dateAdded = timestamp.dateValue()
        } else {
            dateAdded = Date()
        }
        
        guard let contactID = UUID(uuidString: id),
              let userUUID = UUID(uuidString: userID),
              let contactUUID = UUID(uuidString: contactIDString),
              let status = ContactStatus(rawValue: statusString) else {
            throw ContactError.invalidData
        }
        
        return Contact(
            id: contactID,
            userID: userUUID,
            contactID: contactUUID,
            firstName: firstName,
            lastName: lastName,
            phoneNumber: phoneNumber,
            profileImageURL: profileImageURL,
            isResponder: isResponder,
            isDependent: isDependent,
            status: status,
            lastCheckInTime: lastCheckInTime,
            dateAdded: dateAdded
        )
    }
}

// MARK: - Contact Model

/// A contact model
struct Contact: Equatable, Identifiable, Sendable {
    /// The contact's ID
    let id: UUID
    
    /// The user's ID
    let userID: UUID
    
    /// The contact's user ID
    let contactID: UUID
    
    /// The contact's first name
    var firstName: String
    
    /// The contact's last name
    var lastName: String
    
    /// The contact's phone number
    var phoneNumber: String
    
    /// The contact's profile image URL
    var profileImageURL: URL?
    
    /// Whether the contact is a responder
    var isResponder: Bool
    
    /// Whether the contact is a dependent
    var isDependent: Bool
    
    /// The contact's status
    var status: ContactStatus
    
    /// The contact's last check-in time
    var lastCheckInTime: Date?
    
    /// The date the contact was added
    var dateAdded: Date
    
    /// The contact's full name
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    /// The contact's initials
    var initials: String {
        let firstInitial = firstName.first.map(String.init) ?? ""
        let lastInitial = lastName.first.map(String.init) ?? ""
        return "\(firstInitial)\(lastInitial)"
    }
    
    /// Whether the contact has no roles
    var hasNoRoles: Bool {
        !isResponder && !isDependent
    }
}

/// A contact status
enum ContactStatus: String, Equatable, Sendable {
    /// The contact is active
    case active
    
    /// The contact is non-responsive
    case nonResponsive
    
    /// The contact has an active alert
    case alertActive
    
    /// The contact has a pending ping
    case pendingPing
}

// MARK: - Contact Error

/// An error that can occur during contact operations
enum ContactError: Error, Equatable {
    /// The user is not authenticated
    case notAuthenticated
    
    /// The contact was not found
    case contactNotFound
    
    /// The data is invalid
    case invalidData
    
    /// The roles are invalid
    case invalidRoles
    
    /// A network error occurred
    case networkError
    
    /// The user does not have permission
    case permissionDenied
    
    /// An unknown error occurred
    case unknown(String)
    
    /// Compare two contact errors for equality
    static func == (lhs: ContactError, rhs: ContactError) -> Bool {
        switch (lhs, rhs) {
        case (.notAuthenticated, .notAuthenticated):
            return true
        case (.contactNotFound, .contactNotFound):
            return true
        case (.invalidData, .invalidData):
            return true
        case (.invalidRoles, .invalidRoles):
            return true
        case (.networkError, .networkError):
            return true
        case (.permissionDenied, .permissionDenied):
            return true
        case let (.unknown(lhsString), .unknown(rhsString)):
            return lhsString == rhsString
        default:
            return false
        }
    }
}
