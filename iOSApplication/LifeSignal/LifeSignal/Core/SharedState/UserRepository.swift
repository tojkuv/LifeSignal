import Foundation
import ComposableArchitecture
import Dependencies
import DependenciesMacros
import UIKit

// MARK: - Repository Errors

enum UserRepositoryError: Error, LocalizedError {
    case userNotFound(String)
    case saveFailed(String)
    case deleteFailed(String)
    case uploadFailed(String)
    case downloadFailed(String)
    case invalidData(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotFound(let details):
            return "User not found: \(details)"
        case .saveFailed(let details):
            return "Save failed: \(details)"
        case .deleteFailed(let details):
            return "Delete failed: \(details)"
        case .uploadFailed(let details):
            return "Upload failed: \(details)"
        case .downloadFailed(let details):
            return "Download failed: \(details)"
        case .invalidData(let details):
            return "Invalid data: \(details)"
        case .networkError(let details):
            return "Network error: \(details)"
        }
    }
}

// MARK: - Domain Model

struct User: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var phoneNumber: String
    var phoneRegion: String
    var emergencyNote: String
    var checkInInterval: TimeInterval
    var lastCheckedIn: Date?
    var isNotificationsEnabled: Bool
    var notify30MinBefore: Bool
    var notify2HoursBefore: Bool
    var qrCodeId: UUID
    var avatarURL: String?
    var avatarImageData: Data?
    var lastModified: Date

    init(
        id: UUID = UUID(),
        name: String,
        phoneNumber: String,
        phoneRegion: String = "US",
        emergencyNote: String = "",
        checkInInterval: TimeInterval = 86400, // 24 hours default
        lastCheckedIn: Date? = nil,
        isNotificationsEnabled: Bool = true,
        notify30MinBefore: Bool = true,
        notify2HoursBefore: Bool = true,
        qrCodeId: UUID = UUID(),
        avatarURL: String? = nil,
        avatarImageData: Data? = nil,
        lastModified: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.phoneRegion = phoneRegion
        self.emergencyNote = emergencyNote
        self.checkInInterval = checkInInterval
        self.lastCheckedIn = lastCheckedIn
        self.isNotificationsEnabled = isNotificationsEnabled
        self.notify30MinBefore = notify30MinBefore
        self.notify2HoursBefore = notify2HoursBefore
        self.qrCodeId = qrCodeId
        self.avatarURL = avatarURL
        self.avatarImageData = avatarImageData
        self.lastModified = lastModified
    }

    /// Update the user's name
    func withName(_ newName: String) -> User {
        var updated = self
        updated.name = newName
        updated.lastModified = Date()
        return updated
    }

    /// Update the user's phone number
    func withPhone(_ phoneNumber: String, region: String = "US") -> User {
        var updated = self
        updated.phoneNumber = phoneNumber
        updated.phoneRegion = region
        updated.lastModified = Date()
        return updated
    }

    /// Update the user's avatar image
    func withAvatarImage(_ image: UIImage?) -> User {
        var updated = self
        if let image = image {
            updated.avatarImageData = image.jpegData(compressionQuality: 0.8)
        } else {
            updated.avatarImageData = nil
        }
        updated.lastModified = Date()
        return updated
    }

    /// Update the user's emergency note
    func withEmergencyNote(_ newNote: String) -> User {
        var updated = self
        updated.emergencyNote = newNote
        updated.lastModified = Date()
        return updated
    }

    /// Update the user's check-in interval
    func withCheckInInterval(_ newInterval: TimeInterval) -> User {
        var updated = self
        updated.checkInInterval = newInterval
        updated.lastModified = Date()
        return updated
    }

    /// Update the user's notification settings
    func withNotificationSettings(
        enabled: Bool? = nil,
        notify30Min: Bool? = nil,
        notify2Hours: Bool? = nil
    ) -> User {
        var updated = self
        if let enabled = enabled {
            updated.isNotificationsEnabled = enabled
        }
        if let notify30Min = notify30Min {
            updated.notify30MinBefore = notify30Min
        }
        if let notify2Hours = notify2Hours {
            updated.notify2HoursBefore = notify2Hours
        }
        updated.lastModified = Date()
        return updated
    }

    /// Mark the user as checked in
    func withCheckIn() -> User {
        var updated = self
        updated.lastCheckedIn = Date()
        updated.lastModified = Date()
        return updated
    }

    /// Update the user's QR code ID
    func withNewQRCode() -> User {
        var updated = self
        updated.qrCodeId = UUID()
        updated.lastModified = Date()
        return updated
    }

    var isOverdue: Bool {
        guard let lastCheckIn = lastCheckedIn else { return true }
        let timeSinceLastCheckIn = Date().timeIntervalSince(lastCheckIn)
        return timeSinceLastCheckIn > checkInInterval
    }

    var timeUntilNextCheckIn: TimeInterval? {
        guard let lastCheckIn = lastCheckedIn else { return nil }
        let elapsed = Date().timeIntervalSince(lastCheckIn)
        let remaining = checkInInterval - elapsed
        return remaining > 0 ? remaining : 0
    }
    
    /// Computed property to get UIImage from avatarImageData
    var avatarImage: UIImage? {
        guard let imageData = avatarImageData else { return nil }
        return UIImage(data: imageData)
    }
}

// MARK: - User Repository Client

@DependencyClient
struct UserRepository {
    // User data operations
    var getCurrentUser: @Sendable () async -> User? = { nil }
    var getUser: @Sendable (String) async throws -> User? = { _ in nil }
    var createUser: @Sendable (String, String, String, String) async throws -> User = { _, _, _, _ in throw UserRepositoryError.saveFailed("User") }
    var updateProfile: @Sendable (User) async throws -> User = { _ in throw UserRepositoryError.saveFailed("User") }
    var deleteUser: @Sendable (UUID) async throws -> Void = { _ in throw UserRepositoryError.deleteFailed("User") }

    // Avatar operations
    var uploadAvatar: @Sendable (UUID, Data) async throws -> URL = { _, _ in throw UserRepositoryError.uploadFailed("Avatar") }
    var downloadAvatarData: @Sendable (String) async throws -> Data = { _ in throw UserRepositoryError.downloadFailed("Avatar") }

    // Cache operations
    var getCachedUser: @Sendable () async -> User? = { nil }
    var setCachedUser: @Sendable (User) async -> Void = { _ in }
    var clearCachedUser: @Sendable () async -> Void = { }

    // User existence check
    var userExists: @Sendable (String) async throws -> Bool = { _ in false }
}

extension UserRepository: DependencyKey {
    static let liveValue: UserRepository = UserRepository()
    static let testValue = UserRepository()
    
    static let mockValue = UserRepository(
        getCurrentUser: {
            // Return a mock current user
            return User(
                id: UUID(),
                name: "Mock User",
                phoneNumber: "+1234567890",
                phoneRegion: "US",
                emergencyNote: "This is a mock emergency note for testing purposes.",
                checkInInterval: 86400, // 24 hours
                lastCheckedIn: Date().addingTimeInterval(-3600), // 1 hour ago
                isNotificationsEnabled: true,
                notify30MinBefore: true,
                notify2HoursBefore: false,
                qrCodeId: UUID(),
                avatarURL: nil,
                avatarImageData: nil,
                lastModified: Date()
            )
        },
        
        getUser: { userID in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(300))
            
            // Return mock user for any ID
            return User(
                id: UUID(),
                name: "Mock User \(String(userID.prefix(8)))",
                phoneNumber: "+1234567890",
                phoneRegion: "US",
                emergencyNote: "Mock emergency note",
                checkInInterval: 86400,
                lastCheckedIn: Date(),
                isNotificationsEnabled: true,
                notify30MinBefore: true,
                notify2HoursBefore: false,
                qrCodeId: UUID(),
                avatarURL: nil,
                avatarImageData: nil,
                lastModified: Date()
            )
        },
        
        createUser: { firebaseUID, name, phoneNumber, phoneRegion in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(800))
            
            return User(
                id: UUID(),
                name: name,
                phoneNumber: phoneNumber,
                phoneRegion: phoneRegion,
                emergencyNote: "",
                checkInInterval: 86400, // 24 hours default
                lastCheckedIn: nil,
                isNotificationsEnabled: true,
                notify30MinBefore: true,
                notify2HoursBefore: false,
                qrCodeId: UUID(),
                avatarURL: nil,
                avatarImageData: nil,
                lastModified: Date()
            )
        },
        
        updateProfile: { user in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(500))
            
            // Return updated user with new lastModified timestamp
            var updatedUser = user
            updatedUser.lastModified = Date()
            return updatedUser
        },
        
        deleteUser: { userID in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(400))
            // Mock delete always succeeds
        },
        
        uploadAvatar: { userID, imageData in
            // Simulate delay for upload
            try await Task.sleep(for: .milliseconds(2000))
            
            // Return mock avatar URL
            guard let url = URL(string: "https://mock.lifesignal.app/avatars/\(userID.uuidString).jpg") else {
                throw UserRepositoryError.uploadFailed("Failed to create mock avatar URL")
            }
            return url
        },
        
        downloadAvatarData: { avatarURL in
            // Simulate delay for download
            try await Task.sleep(for: .milliseconds(1000))
            
            // Return mock avatar image data (1x1 pixel PNG)
            let mockImageData = Data([
                0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
                0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
                0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
                0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0x0F, 0x00, 0x00,
                0x01, 0x00, 0x01, 0x5C, 0xCF, 0x80, 0x64, 0x00, 0x00, 0x00, 0x00, 0x49,
                0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
            ])
            return mockImageData
        },
        
        getCachedUser: {
            // Return nil for mock - no cached user initially
            return nil
        },
        
        setCachedUser: { user in
            // Mock cache set - does nothing
        },
        
        clearCachedUser: {
            // Mock cache clear - does nothing
        },
        
        userExists: { userID in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(200))
            
            // Return true for mock - user always exists
            return true
        }
    )
}

extension DependencyValues {
    var userRepository: UserRepository {
        get { self[UserRepository.self] }
        set { self[UserRepository.self] = newValue }
    }
}