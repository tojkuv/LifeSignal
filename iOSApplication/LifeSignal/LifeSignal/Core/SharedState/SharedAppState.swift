import Foundation
import ComposableArchitecture
@_exported import Sharing

// MARK: - Core Shared State

extension SharedReaderKey where Self == InMemoryKey<User?>.Default {
    static var currentUser: Self {
        Self[.inMemory("currentUser"), default: nil]
    }
}

extension SharedReaderKey where Self == InMemoryKey<[Contact]>.Default {
    static var contacts: Self {
        Self[.inMemory("contacts"), default: []]
    }
}

extension SharedReaderKey where Self == InMemoryKey<Bool>.Default {
    static var isOnline: Self {
        Self[.inMemory("isOnline"), default: true]
    }
}

extension SharedReaderKey where Self == InMemoryKey<[OfflineAction]>.Default {
    static var offlineQueue: Self {
        Self[.inMemory("offlineQueue"), default: []]
    }
}

// MARK: - Authentication State

extension SharedReaderKey where Self == InMemoryKey<Bool>.Default {
    static var isAuthenticated: Self {
        Self[.inMemory("isAuthenticated"), default: false]
    }
}

extension SharedReaderKey where Self == InMemoryKey<Bool>.Default {
    static var needsOnboarding: Self {
        Self[.inMemory("needsOnboarding"), default: false]
    }
}

// MARK: - Notifications State

extension SharedReaderKey where Self == InMemoryKey<[NotificationItem]>.Default {
    static var notifications: Self {
        Self[.inMemory("notifications"), default: []]
    }
}

extension SharedReaderKey where Self == InMemoryKey<Int>.Default {
    static var unreadNotificationCount: Self {
        Self[.inMemory("unreadNotificationCount"), default: 0]
    }
}

// MARK: - App State

extension SharedReaderKey where Self == InMemoryKey<Date?>.Default {
    static var lastCheckInDate: Self {
        Self[.inMemory("lastCheckInDate"), default: nil]
    }
}

extension SharedReaderKey where Self == InMemoryKey<Bool>.Default {
    static var hasActiveAlert: Self {
        Self[.inMemory("hasActiveAlert"), default: false]
    }
}

// MARK: - Feature Flags

extension SharedReaderKey where Self == InMemoryKey<[String: Bool]>.Default {
    static var featureFlags: Self {
        Self[.inMemory("featureFlags"), default: [:]]
    }
}