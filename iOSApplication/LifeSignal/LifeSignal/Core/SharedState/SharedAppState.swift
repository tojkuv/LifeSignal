import Foundation
import ComposableArchitecture
@_exported import Sharing

// MARK: - Core Shared State

extension PersistenceKey where Self == PersistenceKeyDefault<InMemoryKey<User?>> {
    static var currentUser: Self {
        PersistenceKeyDefault(.inMemory("currentUser"), nil)
    }
}

extension PersistenceKey where Self == PersistenceKeyDefault<InMemoryKey<[Contact]>> {
    static var contacts: Self {
        PersistenceKeyDefault(.inMemory("contacts"), [])
    }
}

extension PersistenceKey where Self == PersistenceKeyDefault<InMemoryKey<Bool>> {
    static var isOnline: Self {
        PersistenceKeyDefault(.inMemory("isOnline"), true)
    }
}

extension PersistenceKey where Self == PersistenceKeyDefault<InMemoryKey<[OfflineAction]>> {
    static var offlineQueue: Self {
        PersistenceKeyDefault(.inMemory("offlineQueue"), [])
    }
}

// MARK: - Authentication State

extension PersistenceKey where Self == PersistenceKeyDefault<InMemoryKey<Bool>> {
    static var isAuthenticated: Self {
        PersistenceKeyDefault(.inMemory("isAuthenticated"), false)
    }
}

extension PersistenceKey where Self == PersistenceKeyDefault<InMemoryKey<Bool>> {
    static var needsOnboarding: Self {
        PersistenceKeyDefault(.inMemory("needsOnboarding"), false)
    }
}

// MARK: - Notifications State

extension PersistenceKey where Self == PersistenceKeyDefault<InMemoryKey<[NotificationItem]>> {
    static var notifications: Self {
        PersistenceKeyDefault(.inMemory("notifications"), [])
    }
}

extension PersistenceKey where Self == PersistenceKeyDefault<InMemoryKey<Int>> {
    static var unreadNotificationCount: Self {
        PersistenceKeyDefault(.inMemory("unreadNotificationCount"), 0)
    }
}

// MARK: - App State

extension PersistenceKey where Self == PersistenceKeyDefault<InMemoryKey<Date?>> {
    static var lastCheckInDate: Self {
        PersistenceKeyDefault(.inMemory("lastCheckInDate"), nil)
    }
}

extension PersistenceKey where Self == PersistenceKeyDefault<InMemoryKey<Bool>> {
    static var hasActiveAlert: Self {
        PersistenceKeyDefault(.inMemory("hasActiveAlert"), false)
    }
}

// MARK: - Feature Flags

extension PersistenceKey where Self == PersistenceKeyDefault<InMemoryKey<[String: Bool]>> {
    static var featureFlags: Self {
        PersistenceKeyDefault(.inMemory("featureFlags"), [:])
    }
}