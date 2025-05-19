# TCA Client Example: CheckInClient

**Navigation:** [Back to Examples](README.md) | [Feature Example](FeatureExample.md) | [View Example](ViewExample.md) | [Adapter Example](AdapterExample.md)

---

## Overview

This document provides a complete example of a client interface and its implementations for the CheckInClient in the LifeSignal iOS application. The CheckInClient is responsible for managing the user's check-in operations, including recording check-ins and retrieving check-in history.

## Client Structure

A TCA client consists of the following components:
- Interface: Defines the client's API
- Live implementation: Implements the client using real backend services
- Test implementation: Implements the client for testing
- Preview implementation: Implements the client for SwiftUI previews
- Dependency registration: Registers the client with the dependency injection system

## Client Interface

```swift
// CheckInClient.swift

import Dependencies
import Foundation

/// Client for managing user check-ins
struct CheckInClient {
    /// Record a new check-in for the current user
    var checkIn: @Sendable () async throws -> Date
    
    /// Get the user's check-in history
    var getCheckInHistory: @Sendable () async throws -> [CheckInRecord]
    
    /// Get the user's current check-in interval in seconds
    var getCheckInInterval: @Sendable () async throws -> TimeInterval
    
    /// Set the user's check-in interval in seconds
    var setCheckInInterval: @Sendable (TimeInterval) async throws -> Void
    
    /// Get the user's current reminder interval in seconds
    var getReminderInterval: @Sendable () async throws -> TimeInterval
    
    /// Set the user's reminder interval in seconds
    var setReminderInterval: @Sendable (TimeInterval) async throws -> Void
}

/// A record of a user check-in
struct CheckInRecord: Equatable, Sendable, Identifiable {
    var id: String
    var timestamp: Date
    var userId: String
}
```

## Dependency Key

```swift
// CheckInClient+DependencyKey.swift

import Dependencies

extension CheckInClient: DependencyKey {
    static var liveValue: Self {
        return Self(
            checkIn: {
                try await FirebaseCheckInAdapter().checkIn()
            },
            getCheckInHistory: {
                try await FirebaseCheckInAdapter().getCheckInHistory()
            },
            getCheckInInterval: {
                try await FirebaseCheckInAdapter().getCheckInInterval()
            },
            setCheckInInterval: { interval in
                try await FirebaseCheckInAdapter().setCheckInInterval(interval)
            },
            getReminderInterval: {
                try await FirebaseCheckInAdapter().getReminderInterval()
            },
            setReminderInterval: { interval in
                try await FirebaseCheckInAdapter().setReminderInterval(interval)
            }
        )
    }
    
    static var testValue: Self {
        return Self(
            checkIn: unimplemented("CheckInClient.checkIn"),
            getCheckInHistory: unimplemented("CheckInClient.getCheckInHistory"),
            getCheckInInterval: unimplemented("CheckInClient.getCheckInInterval"),
            setCheckInInterval: unimplemented("CheckInClient.setCheckInInterval"),
            getReminderInterval: unimplemented("CheckInClient.getReminderInterval"),
            setReminderInterval: unimplemented("CheckInClient.setReminderInterval")
        )
    }
    
    static var previewValue: Self {
        return Self(
            checkIn: {
                return Date()
            },
            getCheckInHistory: {
                return [
                    CheckInRecord(
                        id: "1",
                        timestamp: Date().addingTimeInterval(-86400), // 1 day ago
                        userId: "user1"
                    ),
                    CheckInRecord(
                        id: "2",
                        timestamp: Date().addingTimeInterval(-172800), // 2 days ago
                        userId: "user1"
                    ),
                    CheckInRecord(
                        id: "3",
                        timestamp: Date().addingTimeInterval(-259200), // 3 days ago
                        userId: "user1"
                    )
                ]
            },
            getCheckInInterval: {
                return 86400 // 24 hours
            },
            setCheckInInterval: { _ in
                // No-op for preview
            },
            getReminderInterval: {
                return 7200 // 2 hours
            },
            setReminderInterval: { _ in
                // No-op for preview
            }
        )
    }
}
```

## Dependency Registration

```swift
// DependencyValues+CheckInClient.swift

import Dependencies

extension DependencyValues {
    var checkInClient: CheckInClient {
        get { self[CheckInClient.self] }
        set { self[CheckInClient.self] = newValue }
    }
}
```

## Live Implementation (Adapter)

```swift
// FirebaseCheckInAdapter.swift

import FirebaseFirestore
import FirebaseAuth
import Foundation

struct FirebaseCheckInAdapter {
    private let db = Firestore.firestore()
    
    func checkIn() async throws -> Date {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw CheckInError.notAuthenticated
        }
        
        let checkInTime = Date()
        let checkInId = UUID().uuidString
        
        let checkInData: [String: Any] = [
            "id": checkInId,
            "timestamp": Timestamp(date: checkInTime),
            "userId": userId
        ]
        
        try await db.collection("checkIns").document(checkInId).setData(checkInData)
        
        // Update user's last check-in time
        try await db.collection("users").document(userId).updateData([
            "lastCheckInTime": Timestamp(date: checkInTime)
        ])
        
        return checkInTime
    }
    
    func getCheckInHistory() async throws -> [CheckInRecord] {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw CheckInError.notAuthenticated
        }
        
        let snapshot = try await db.collection("checkIns")
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .limit(to: 10)
            .getDocuments()
        
        return snapshot.documents.compactMap { document -> CheckInRecord? in
            guard 
                let id = document.data()["id"] as? String,
                let timestamp = document.data()["timestamp"] as? Timestamp,
                let userId = document.data()["userId"] as? String
            else {
                return nil
            }
            
            return CheckInRecord(
                id: id,
                timestamp: timestamp.dateValue(),
                userId: userId
            )
        }
    }
    
    func getCheckInInterval() async throws -> TimeInterval {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw CheckInError.notAuthenticated
        }
        
        let document = try await db.collection("users").document(userId).getDocument()
        
        guard 
            let data = document.data(),
            let interval = data["checkInInterval"] as? TimeInterval
        else {
            return 86400 // Default to 24 hours
        }
        
        return interval
    }
    
    func setCheckInInterval(_ interval: TimeInterval) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw CheckInError.notAuthenticated
        }
        
        try await db.collection("users").document(userId).updateData([
            "checkInInterval": interval
        ])
    }
    
    func getReminderInterval() async throws -> TimeInterval {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw CheckInError.notAuthenticated
        }
        
        let document = try await db.collection("users").document(userId).getDocument()
        
        guard 
            let data = document.data(),
            let interval = data["reminderInterval"] as? TimeInterval
        else {
            return 7200 // Default to 2 hours
        }
        
        return interval
    }
    
    func setReminderInterval(_ interval: TimeInterval) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw CheckInError.notAuthenticated
        }
        
        try await db.collection("users").document(userId).updateData([
            "reminderInterval": interval
        ])
    }
}

enum CheckInError: Error {
    case notAuthenticated
    case serverError
    case networkError
    case unknownError
}
```

## Test Implementation

```swift
// CheckInClient+TestValue.swift

extension CheckInClient {
    static func mock(
        checkIn: @escaping () async throws -> Date = { Date() },
        getCheckInHistory: @escaping () async throws -> [CheckInRecord] = { [] },
        getCheckInInterval: @escaping () async throws -> TimeInterval = { 86400 },
        setCheckInInterval: @escaping (TimeInterval) async throws -> Void = { _ in },
        getReminderInterval: @escaping () async throws -> TimeInterval = { 7200 },
        setReminderInterval: @escaping (TimeInterval) async throws -> Void = { _ in }
    ) -> Self {
        Self(
            checkIn: checkIn,
            getCheckInHistory: getCheckInHistory,
            getCheckInInterval: getCheckInInterval,
            setCheckInInterval: setCheckInInterval,
            getReminderInterval: getReminderInterval,
            setReminderInterval: setReminderInterval
        )
    }
}
```

## Usage in Feature

```swift
// CheckInFeature.swift

@Reducer
struct CheckInFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        // State properties...
    }
    
    enum Action: Equatable, Sendable {
        // Actions...
    }
    
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
                    } catch {
                        await send(.checkInResponse(.failure(error)))
                    }
                }
                
            case let .loadCheckInInterval:
                return .run { send in
                    do {
                        let interval = try await checkInClient.getCheckInInterval()
                        await send(.checkInIntervalResponse(.success(interval)))
                    } catch {
                        await send(.checkInIntervalResponse(.failure(error)))
                    }
                }
                
            // Other action handlers...
            }
        }
    }
}
```

## Testing with Mock Client

```swift
@MainActor
final class CheckInFeatureTests: XCTestCase {
    func testCheckIn() async {
        let store = TestStore(initialState: CheckInFeature.State()) {
            CheckInFeature()
        } withDependencies: {
            $0.checkInClient = .mock(
                checkIn: {
                    return Date(timeIntervalSince1970: 0)
                }
            )
        }
        
        await store.send(.checkInButtonTapped) {
            $0.isCheckingIn = true
        }
        
        await store.receive(.checkInResponse(.success(Date(timeIntervalSince1970: 0)))) {
            $0.isCheckingIn = false
            $0.lastCheckInTime = Date(timeIntervalSince1970: 0)
            $0.nextCheckInTime = Date(timeIntervalSince1970: 86400) // 24 hours later
        }
    }
    
    func testCheckInFailure() async {
        struct CheckInError: Error, Equatable {}
        
        let store = TestStore(initialState: CheckInFeature.State()) {
            CheckInFeature()
        } withDependencies: {
            $0.checkInClient = .mock(
                checkIn: {
                    throw CheckInError()
                }
            )
        }
        
        await store.send(.checkInButtonTapped) {
            $0.isCheckingIn = true
        }
        
        await store.receive(.checkInResponse(.failure(CheckInError()))) {
            $0.isCheckingIn = false
            $0.error = CheckInError().localizedDescription
        }
    }
}
```

## Best Practices

1. **Client Design**
   - Keep clients focused on a single domain
   - Use clear, descriptive method names
   - Use async/await for asynchronous operations
   - Use strong typing for parameters and return values

2. **Dependency Injection**
   - Register clients as dependencies
   - Provide live, test, and preview implementations
   - Use the `unimplemented` function for test values to catch unhandled cases

3. **Error Handling**
   - Define domain-specific error types
   - Provide meaningful error messages
   - Handle errors at the feature level

4. **Testing**
   - Use mock clients for testing
   - Test success and failure cases
   - Test edge cases and error conditions

5. **Adapter Implementation**
   - Keep adapters separate from clients
   - Handle backend-specific details in adapters
   - Convert between backend and domain models

## Conclusion

This example demonstrates a complete implementation of a client interface and its implementations for the CheckInClient in the LifeSignal iOS application. It shows how to define a client interface, implement it for different environments, register it with the dependency injection system, and use it in features.

When implementing a new client, use this example as a reference to ensure consistency and adherence to the established architectural patterns.
