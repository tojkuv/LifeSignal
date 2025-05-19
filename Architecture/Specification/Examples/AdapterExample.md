# TCA Adapter Example: FirebaseCheckInAdapter

**Navigation:** [Back to Examples](README.md) | [Feature Example](FeatureExample.md) | [View Example](ViewExample.md) | [Client Example](ClientExample.md)

---

## Overview

This document provides a complete example of an adapter implementation for the FirebaseCheckInAdapter in the LifeSignal iOS application. The FirebaseCheckInAdapter is responsible for implementing the CheckInClient interface using Firebase as the backend service.

## Adapter Structure

An adapter consists of the following components:
- Implementation: Implements a client interface using a specific backend service
- Error handling: Defines and handles backend-specific errors
- Data conversion: Converts between backend data models and domain models

## Adapter Implementation

```swift
// FirebaseCheckInAdapter.swift

import FirebaseFirestore
import FirebaseAuth
import Foundation

/// Adapter for implementing CheckInClient using Firebase
struct FirebaseCheckInAdapter {
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    
    /// Collection names
    private enum Collection {
        static let checkIns = "checkIns"
        static let users = "users"
    }
    
    /// Field names
    private enum Field {
        static let id = "id"
        static let timestamp = "timestamp"
        static let userId = "userId"
        static let lastCheckInTime = "lastCheckInTime"
        static let checkInInterval = "checkInInterval"
        static let reminderInterval = "reminderInterval"
    }
    
    /// Record a new check-in for the current user
    func checkIn() async throws -> Date {
        guard let userId = auth.currentUser?.uid else {
            throw CheckInError.notAuthenticated
        }
        
        let checkInTime = Date()
        let checkInId = UUID().uuidString
        
        let checkInData: [String: Any] = [
            Field.id: checkInId,
            Field.timestamp: Timestamp(date: checkInTime),
            Field.userId: userId
        ]
        
        do {
            // Create a new check-in record
            try await db.collection(Collection.checkIns).document(checkInId).setData(checkInData)
            
            // Update user's last check-in time
            try await db.collection(Collection.users).document(userId).updateData([
                Field.lastCheckInTime: Timestamp(date: checkInTime)
            ])
            
            return checkInTime
        } catch let error as NSError {
            switch error.domain {
            case NSURLErrorDomain:
                throw CheckInError.networkError
            default:
                if error.code == FirestoreErrorCode.unavailable.rawValue {
                    throw CheckInError.serverError
                } else {
                    throw CheckInError.unknownError(error)
                }
            }
        }
    }
    
    /// Get the user's check-in history
    func getCheckInHistory() async throws -> [CheckInRecord] {
        guard let userId = auth.currentUser?.uid else {
            throw CheckInError.notAuthenticated
        }
        
        do {
            let snapshot = try await db.collection(Collection.checkIns)
                .whereField(Field.userId, isEqualTo: userId)
                .order(by: Field.timestamp, descending: true)
                .limit(to: 10)
                .getDocuments()
            
            return snapshot.documents.compactMap { document -> CheckInRecord? in
                guard 
                    let id = document.data()[Field.id] as? String,
                    let timestamp = document.data()[Field.timestamp] as? Timestamp,
                    let userId = document.data()[Field.userId] as? String
                else {
                    return nil
                }
                
                return CheckInRecord(
                    id: id,
                    timestamp: timestamp.dateValue(),
                    userId: userId
                )
            }
        } catch let error as NSError {
            switch error.domain {
            case NSURLErrorDomain:
                throw CheckInError.networkError
            default:
                if error.code == FirestoreErrorCode.unavailable.rawValue {
                    throw CheckInError.serverError
                } else {
                    throw CheckInError.unknownError(error)
                }
            }
        }
    }
    
    /// Get the user's current check-in interval in seconds
    func getCheckInInterval() async throws -> TimeInterval {
        guard let userId = auth.currentUser?.uid else {
            throw CheckInError.notAuthenticated
        }
        
        do {
            let document = try await db.collection(Collection.users).document(userId).getDocument()
            
            guard 
                let data = document.data(),
                let interval = data[Field.checkInInterval] as? TimeInterval
            else {
                return 86400 // Default to 24 hours
            }
            
            return interval
        } catch let error as NSError {
            switch error.domain {
            case NSURLErrorDomain:
                throw CheckInError.networkError
            default:
                if error.code == FirestoreErrorCode.unavailable.rawValue {
                    throw CheckInError.serverError
                } else {
                    throw CheckInError.unknownError(error)
                }
            }
        }
    }
    
    /// Set the user's check-in interval in seconds
    func setCheckInInterval(_ interval: TimeInterval) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw CheckInError.notAuthenticated
        }
        
        do {
            try await db.collection(Collection.users).document(userId).updateData([
                Field.checkInInterval: interval
            ])
        } catch let error as NSError {
            switch error.domain {
            case NSURLErrorDomain:
                throw CheckInError.networkError
            default:
                if error.code == FirestoreErrorCode.unavailable.rawValue {
                    throw CheckInError.serverError
                } else {
                    throw CheckInError.unknownError(error)
                }
            }
        }
    }
    
    /// Get the user's current reminder interval in seconds
    func getReminderInterval() async throws -> TimeInterval {
        guard let userId = auth.currentUser?.uid else {
            throw CheckInError.notAuthenticated
        }
        
        do {
            let document = try await db.collection(Collection.users).document(userId).getDocument()
            
            guard 
                let data = document.data(),
                let interval = data[Field.reminderInterval] as? TimeInterval
            else {
                return 7200 // Default to 2 hours
            }
            
            return interval
        } catch let error as NSError {
            switch error.domain {
            case NSURLErrorDomain:
                throw CheckInError.networkError
            default:
                if error.code == FirestoreErrorCode.unavailable.rawValue {
                    throw CheckInError.serverError
                } else {
                    throw CheckInError.unknownError(error)
                }
            }
        }
    }
    
    /// Set the user's reminder interval in seconds
    func setReminderInterval(_ interval: TimeInterval) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw CheckInError.notAuthenticated
        }
        
        do {
            try await db.collection(Collection.users).document(userId).updateData([
                Field.reminderInterval: interval
            ])
        } catch let error as NSError {
            switch error.domain {
            case NSURLErrorDomain:
                throw CheckInError.networkError
            default:
                if error.code == FirestoreErrorCode.unavailable.rawValue {
                    throw CheckInError.serverError
                } else {
                    throw CheckInError.unknownError(error)
                }
            }
        }
    }
}

/// Errors that can occur during check-in operations
enum CheckInError: Error, LocalizedError {
    case notAuthenticated
    case serverError
    case networkError
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You are not signed in. Please sign in to continue."
        case .serverError:
            return "The server is currently unavailable. Please try again later."
        case .networkError:
            return "A network error occurred. Please check your internet connection and try again."
        case let .unknownError(error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}
```

## Client Integration

```swift
// CheckInClient+DependencyKey.swift

import Dependencies

extension CheckInClient: DependencyKey {
    static var liveValue: Self {
        let adapter = FirebaseCheckInAdapter()
        
        return Self(
            checkIn: {
                try await adapter.checkIn()
            },
            getCheckInHistory: {
                try await adapter.getCheckInHistory()
            },
            getCheckInInterval: {
                try await adapter.getCheckInInterval()
            },
            setCheckInInterval: { interval in
                try await adapter.setCheckInInterval(interval)
            },
            getReminderInterval: {
                try await adapter.getReminderInterval()
            },
            setReminderInterval: { interval in
                try await adapter.setReminderInterval(interval)
            }
        )
    }
    
    // Test and preview values...
}
```

## Error Handling

```swift
// CheckInFeature.swift

@Reducer
struct CheckInFeature {
    // State and actions...
    
    @Dependency(\.checkInClient) var checkInClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .checkInButtonTapped:
                state.isCheckingIn = true
                return .run { send in
                    do {
                        let checkInTime = try await checkInClient.checkIn()
                        await send(.checkInResponse(.success(checkInTime)))
                    } catch let error as CheckInError {
                        // Handle specific error types
                        switch error {
                        case .notAuthenticated:
                            await send(.signOutRequired)
                        case .networkError, .serverError:
                            await send(.checkInResponse(.failure(error)))
                        case .unknownError:
                            await send(.checkInResponse(.failure(error)))
                        }
                    } catch {
                        await send(.checkInResponse(.failure(error)))
                    }
                }
                
            case let .checkInResponse(.success(checkInTime)):
                state.isCheckingIn = false
                state.lastCheckInTime = checkInTime
                state.nextCheckInTime = checkInTime.addingTimeInterval(state.checkInInterval)
                state.error = nil
                return .none
                
            case let .checkInResponse(.failure(error)):
                state.isCheckingIn = false
                state.error = error.localizedDescription
                return .none
                
            // Other action handlers...
            }
        }
    }
}
```

## Testing the Adapter

```swift
// FirebaseCheckInAdapterTests.swift

import XCTest
import FirebaseFirestore
import FirebaseAuth
@testable import LifeSignal

final class FirebaseCheckInAdapterTests: XCTestCase {
    // Mock Firebase dependencies
    private var mockAuth: MockAuth!
    private var mockFirestore: MockFirestore!
    private var adapter: FirebaseCheckInAdapter!
    
    override func setUp() {
        super.setUp()
        mockAuth = MockAuth()
        mockFirestore = MockFirestore()
        adapter = FirebaseCheckInAdapter(
            db: mockFirestore,
            auth: mockAuth
        )
    }
    
    func testCheckIn_WhenAuthenticated_ShouldSucceed() async throws {
        // Arrange
        let userId = "user123"
        let currentUser = MockUser(uid: userId)
        mockAuth.currentUser = currentUser
        
        mockFirestore.setDataHandler = { _, _ in
            // Simulate successful write
        }
        
        mockFirestore.updateDataHandler = { _, _ in
            // Simulate successful update
        }
        
        // Act
        let checkInTime = try await adapter.checkIn()
        
        // Assert
        XCTAssertNotNil(checkInTime)
        XCTAssertEqual(mockFirestore.lastCollection, "checkIns")
        XCTAssertTrue(mockFirestore.lastUpdateData.keys.contains("lastCheckInTime"))
    }
    
    func testCheckIn_WhenNotAuthenticated_ShouldThrowError() async {
        // Arrange
        mockAuth.currentUser = nil
        
        // Act & Assert
        do {
            _ = try await adapter.checkIn()
            XCTFail("Expected error to be thrown")
        } catch let error as CheckInError {
            XCTAssertEqual(error, CheckInError.notAuthenticated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testCheckIn_WhenNetworkError_ShouldThrowNetworkError() async {
        // Arrange
        let userId = "user123"
        let currentUser = MockUser(uid: userId)
        mockAuth.currentUser = currentUser
        
        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        mockFirestore.setDataHandler = { _, _ in
            throw networkError
        }
        
        // Act & Assert
        do {
            _ = try await adapter.checkIn()
            XCTFail("Expected error to be thrown")
        } catch let error as CheckInError {
            XCTAssertEqual(error, CheckInError.networkError)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // Additional tests for other methods...
}

// Mock implementations for testing
private class MockAuth {
    var currentUser: MockUser?
}

private class MockUser {
    let uid: String
    
    init(uid: String) {
        self.uid = uid
    }
}

private class MockFirestore {
    var lastCollection: String?
    var lastDocument: String?
    var lastData: [String: Any]?
    var lastUpdateData: [String: Any]?
    
    var setDataHandler: ((String, [String: Any]) throws -> Void)?
    var updateDataHandler: ((String, [String: Any]) throws -> Void)?
    var getDocumentHandler: ((String) throws -> MockDocumentSnapshot)?
    
    func collection(_ collectionPath: String) -> MockCollectionReference {
        lastCollection = collectionPath
        return MockCollectionReference(firestore: self, path: collectionPath)
    }
}

private class MockCollectionReference {
    let firestore: MockFirestore
    let path: String
    
    init(firestore: MockFirestore, path: String) {
        self.firestore = firestore
        self.path = path
    }
    
    func document(_ documentPath: String) -> MockDocumentReference {
        firestore.lastDocument = documentPath
        return MockDocumentReference(firestore: firestore, path: "\(path)/\(documentPath)")
    }
    
    func whereField(_ field: String, isEqualTo: Any) -> MockQuery {
        return MockQuery(firestore: firestore)
    }
}

private class MockDocumentReference {
    let firestore: MockFirestore
    let path: String
    
    init(firestore: MockFirestore, path: String) {
        self.firestore = firestore
        self.path = path
    }
    
    func setData(_ data: [String: Any]) async throws {
        firestore.lastData = data
        try firestore.setDataHandler?(path, data)
    }
    
    func updateData(_ data: [String: Any]) async throws {
        firestore.lastUpdateData = data
        try firestore.updateDataHandler?(path, data)
    }
    
    func getDocument() async throws -> MockDocumentSnapshot {
        if let handler = firestore.getDocumentHandler {
            return try handler(path)
        }
        return MockDocumentSnapshot(exists: false, data: nil)
    }
}

private class MockQuery {
    let firestore: MockFirestore
    
    init(firestore: MockFirestore) {
        self.firestore = firestore
    }
    
    func order(by: String, descending: Bool) -> MockQuery {
        return self
    }
    
    func limit(to: Int) -> MockQuery {
        return self
    }
    
    func getDocuments() async throws -> MockQuerySnapshot {
        return MockQuerySnapshot(documents: [])
    }
}

private class MockQuerySnapshot {
    let documents: [MockDocumentSnapshot]
    
    init(documents: [MockDocumentSnapshot]) {
        self.documents = documents
    }
}

private class MockDocumentSnapshot {
    let exists: Bool
    let documentData: [String: Any]?
    
    init(exists: Bool, data: [String: Any]?) {
        self.exists = exists
        self.documentData = data
    }
    
    func data() -> [String: Any]? {
        return documentData
    }
}
```

## Best Practices

1. **Adapter Design**
   - Keep adapters focused on a single backend service
   - Use clear, descriptive method names
   - Use async/await for asynchronous operations
   - Use strong typing for parameters and return values

2. **Error Handling**
   - Define domain-specific error types
   - Map backend errors to domain errors
   - Provide meaningful error messages
   - Handle network and server errors appropriately

3. **Data Conversion**
   - Convert between backend data models and domain models
   - Handle missing or invalid data gracefully
   - Provide default values when appropriate

4. **Testing**
   - Mock backend dependencies for testing
   - Test success and failure cases
   - Test error mapping
   - Test data conversion

5. **Dependency Injection**
   - Inject backend dependencies for testability
   - Use dependency injection to provide the adapter to clients

## Conclusion

This example demonstrates a complete implementation of an adapter for the FirebaseCheckInAdapter in the LifeSignal iOS application. It shows how to implement a client interface using a specific backend service, handle errors, convert data, and test the adapter.

When implementing a new adapter, use this example as a reference to ensure consistency and adherence to the established architectural patterns.
