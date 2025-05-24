import Foundation
import ComposableArchitecture
import Dependencies
import DependenciesMacros
import UIKit

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

    // MARK: - Computed Properties

    /// Get the avatar image from stored data
    var avatarImage: UIImage? {
        guard let data = avatarImageData else { return nil }
        return UIImage(data: data)
    }

    /// Whether the user is using the default avatar
    var isUsingDefaultAvatar: Bool {
        return avatarImageData == nil
    }

    // MARK: - Initialization

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

    // MARK: - Mutation Methods

    /// Update the user's name
    func withName(_ name: String) -> User {
        var updated = self
        updated.name = name
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

    /// Update the user's notification settings
    func withNotificationSettings(enabled: Bool, notify30Min: Bool? = nil, notify2Hours: Bool? = nil) -> User {
        var updated = self
        updated.isNotificationsEnabled = enabled
        if let notify30Min = notify30Min {
            updated.notify30MinBefore = notify30Min
        }
        if let notify2Hours = notify2Hours {
            updated.notify2HoursBefore = notify2Hours
        }
        updated.lastModified = Date()
        return updated
    }

    /// Update check-in interval
    func withCheckInInterval(_ interval: TimeInterval) -> User {
        var updated = self
        updated.checkInInterval = interval
        updated.lastModified = Date()
        return updated
    }

    /// Update last check-in time
    func withLastCheckIn(_ date: Date) -> User {
        var updated = self
        updated.lastCheckedIn = date
        updated.lastModified = Date()
        return updated
    }

    /// Generate a new QR code ID
    func withNewQRCodeId() -> User {
        var updated = self
        updated.qrCodeId = UUID()
        updated.lastModified = Date()
        return updated
    }
}

// MARK: - User Repository

@DependencyClient
struct UserRepository {
    var getCurrentUser: @Sendable () async -> User? = { nil }
    var sendVerificationCode: @Sendable (String) async throws -> String = { _ in throw AppError.authentication(.verificationCodeInvalid) }
    var verifyPhoneNumber: @Sendable (String, String) async throws -> User = { _, _ in throw AppError.authentication(.verificationCodeInvalid) }
    var createAccountWithPhone: @Sendable (String, String, String) async throws -> User = { _, _, _ in throw AppError.repository(.saveFailed("User")) }
    var updateProfile: @Sendable (User) async throws -> User = { _ in throw AppError.repository(.saveFailed("User")) }
    var uploadAvatar: @Sendable (Data) async throws -> URL = { _ in throw AppError.storage(.uploadFailed("Avatar")) }
    var deleteAccount: @Sendable () async throws -> Void = { throw AppError.repository(.deleteFailed("Account")) }
    var signOut: @Sendable () async throws -> Void = { throw AppError.authentication(.notAuthenticated) }
}

extension UserRepository: DependencyKey {
    static let liveValue: UserRepository = {
        @Dependency(\.grpcClient) var grpc
        @Dependency(\.firebaseAuth) var auth
        @Dependency(\.retryClient) var retry
        @Dependency(\.analytics) var analytics
        @Dependency(\.performance) var performance
        @Dependency(\.cache) var cache

        return UserRepository(
            getCurrentUser: {
                do {
                    guard let uid = auth.getCurrentUID() else { return nil }

                    // Try cache first
                    let cacheKey = CacheKey(namespace: "user", identifier: uid)
                    if let cached = await cache.get(cacheKey, User.self) as? User {
                        return cached
                    }

                    let trace = performance.startTrace("user.get")
                    defer { performance.endTrace(trace, ["cached": false]) }

                    let request = GetUserRequest(uid: uid)
                    let proto = try await retry.withRetry(
                        { try await grpc.userService.getUser(request) },
                        maxAttempts: 3,
                        baseDelay: .seconds(1)
                    ) as? User_Proto

                    guard let proto = proto else {
                        throw AppError.network(.invalidResponse)
                    }
                    let user = proto.toDomain()

                    // Cache the result
                    await cache.set(cacheKey, user, TTL(seconds: 300))

                    return user
                } catch {
                    return nil
                }
            },

            sendVerificationCode: { phoneNumber in
                let trace = performance.startTrace("user.send_verification")
                defer { performance.endTrace(trace, ["method": "phone"]) }

                let verificationID = try await auth.sendVerificationCode(phoneNumber)

                await analytics.track(.verificationCodeSent(phoneNumber: phoneNumber))

                return verificationID
            },

            verifyPhoneNumber: { verificationID, code in
                let trace = performance.startTrace("user.verify_phone")
                defer { performance.endTrace(trace, ["method": "phone"]) }

                let uid = try await auth.verifyPhoneNumber(verificationID, code)
                let request = GetUserRequest(uid: uid)

                do {
                    let proto = try await grpc.userService.getUser(request)
                    let user = proto.toDomain()

                    await analytics.track(.userSignedIn(method: "phone"))
                    await analytics.setUserProperties([
                        "user_id": user.id.uuidString,
                        "phone_number": user.phoneNumber,
                        "phone_region": user.phoneRegion
                    ])

                    return user
                } catch {
                    // User doesn't exist, will need to create account
                    throw AppError.authentication(.accountNotFound)
                }
            },

            createAccountWithPhone: { name, phoneNumber, phoneRegion in
                let trace = performance.startTrace("user.create_with_phone")
                defer { performance.endTrace(trace, ["method": "phone"]) }

                guard let uid = auth.getCurrentUID() else {
                    throw AppError.authentication(.notAuthenticated)
                }

                let request = CreateUserRequest(
                    uid: uid,
                    name: name,
                    phoneNumber: phoneNumber,
                    phoneRegion: phoneRegion,
                    isNotificationsEnabled: true,
                    notify30MinBefore: true,
                    notify2HoursBefore: true
                )
                let proto = try await grpc.userService.createUser(request)
                let user = proto.toDomain()

                await analytics.track(.userSignedIn(method: "signup"))
                await analytics.setUserProperties([
                    "user_id": user.id.uuidString,
                    "phone_number": phoneNumber,
                    "phone_region": phoneRegion,
                    "name": name
                ])

                return user
            },

            updateProfile: { user in
                let trace = performance.startTrace("user.update")
                defer { performance.endTrace(trace, ["user_id": user.id.uuidString]) }

                let request = UpdateUserRequest(
                    id: user.id,
                    name: user.name,
                    phoneNumber: user.phoneNumber,
                    phoneRegion: user.phoneRegion,
                    emergencyNote: user.emergencyNote,
                    checkInInterval: user.checkInInterval,
                    isNotificationsEnabled: user.isNotificationsEnabled,
                    notify30MinBefore: user.notify30MinBefore,
                    notify2HoursBefore: user.notify2HoursBefore,
                    avatarURL: user.avatarURL ?? ""
                )
                let proto = try await grpc.userService.updateUser(request)
                let updatedUser = proto.toDomain()

                // Invalidate cache
                let cacheKey = CacheKey(namespace: "user", identifier: user.id.uuidString)
                await cache.invalidate(CachePattern(namespace: "user", prefix: user.id.uuidString))

                await analytics.track(.userProfileUpdated(userId: user.id.uuidString))

                return updatedUser
            },

            uploadAvatar: { imageData in
                let trace = performance.startTrace("user.upload_avatar")
                defer { performance.endTrace(trace, ["size": imageData.count]) }

                guard let currentUser = await getCurrentUser() else {
                    throw AppError.authentication(.notAuthenticated)
                }

                let request = UploadAvatarRequest(
                    userId: currentUser.id,
                    imageData: imageData
                )
                let response = try await grpc.userService.uploadAvatar(request)

                await analytics.track(.avatarUploaded(userId: currentUser.id.uuidString, size: imageData.count))

                return URL(string: response.url)!
            },

            deleteAccount: {
                guard let currentUser = await getCurrentUser() else {
                    throw AppError.authentication(.notAuthenticated)
                }

                let trace = performance.startTrace("user.delete")
                defer { performance.endTrace(trace, ["user_id": currentUser.id.uuidString]) }

                let request = DeleteUserRequest(userId: currentUser.id)
                _ = try await grpc.userService.deleteUser(request)
                try await auth.signOut()

                // Clear cache
                await cache.invalidate(CachePattern(namespace: "user", prefix: currentUser.id.uuidString))

                await analytics.track(.userAccountDeleted(userId: currentUser.id.uuidString))
            },

            signOut: {
                if let currentUser = await getCurrentUser() {
                    await analytics.track(.userSignedOut(userId: currentUser.id.uuidString))
                    // Clear all user-related cache
                    await cache.invalidate(CachePattern(namespace: "user", prefix: currentUser.id.uuidString))
                }
                try await auth.signOut()
            }
        )
    }()

    static let testValue = UserRepository(
        getCurrentUser: {
            return User(
                name: "Test User",
                phoneNumber: "+1234567890",
                phoneRegion: "US",
                qrCodeId: UUID()
            )
        },
        sendVerificationCode: { _ in "test-verification-id" },
        verifyPhoneNumber: { _, _ in
            User(
                name: "Test User",
                phoneNumber: "+1234567890",
                phoneRegion: "US",
                qrCodeId: UUID()
            )
        },
        createAccountWithPhone: { name, phoneNumber, phoneRegion in
            User(
                name: name,
                phoneNumber: phoneNumber,
                phoneRegion: phoneRegion,
                qrCodeId: UUID()
            )
        },
        updateProfile: { user in user },
        uploadAvatar: { _ in URL(string: "https://example.com/avatar.jpg")! },
        deleteAccount: { },
        signOut: { }
    )
}

extension DependencyValues {
    var userRepository: UserRepository {
        get { self[UserRepository.self] }
        set { self[UserRepository.self] = newValue }
    }
}