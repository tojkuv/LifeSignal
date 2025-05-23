import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation

// MARK: - User Repository

@DependencyClient
struct UserRepository {
    var getCurrentUser: @Sendable () async -> User?
    var sendVerificationCode: @Sendable (String) async throws -> String
    var verifyPhoneNumber: @Sendable (String, String) async throws -> User
    var createAccountWithPhone: @Sendable (String, String) async throws -> User
    var updateProfile: @Sendable (User) async throws -> User
    var uploadAvatar: @Sendable (Data) async throws -> URL
    var deleteAccount: @Sendable () async throws -> Void
    var signOut: @Sendable () async throws -> Void
    
    // Legacy methods for migration
    var loadUser: @Sendable () async throws -> User?
    var saveUser: @Sendable (User) async throws -> Void
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
                    
                    let request = GetUserRequest(firebaseUID: uid)
                    let proto = try await retry.withRetry(
                        { try await grpc.userService.getUser(request) },
                        maxAttempts: 3,
                        baseDelay: .seconds(1)
                    ) as? User_Proto
                    
                    guard let proto = proto else {
                        throw UserRepositoryError.networkError
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
                let request = GetUserRequest(firebaseUID: uid)
                
                do {
                    let proto = try await grpc.userService.getUser(request)
                    let user = proto.toDomain()
                    
                    await analytics.track(.userSignedIn(method: "phone"))
                    await analytics.setUserProperties([
                        "firebase_uid": uid,
                        "phone_number": user.phoneNumber
                    ])
                    
                    return user
                } catch {
                    // User doesn't exist, will need to create account
                    throw UserRepositoryError.userNotFound
                }
            },
            
            createAccountWithPhone: { name, phoneNumber in
                let trace = performance.startTrace("user.create_with_phone")
                defer { performance.endTrace(trace, ["method": "phone"]) }
                
                guard let uid = auth.getCurrentUID() else {
                    throw UserRepositoryError.authenticationFailed
                }
                
                let request = CreateUserRequest(
                    firebaseUID: uid,
                    name: name,
                    phoneNumber: phoneNumber,
                    isNotificationsEnabled: true
                )
                let proto = try await grpc.userService.createUser(request)
                let user = proto.toDomain()
                
                await analytics.track(.userSignedIn(method: "signup"))
                await analytics.setUserProperties([
                    "firebase_uid": uid,
                    "phone_number": phoneNumber,
                    "name": name
                ])
                
                return user
            },
            
            updateProfile: { user in
                let trace = performance.startTrace("user.update")
                defer { performance.endTrace(trace, ["user_id": user.id.uuidString]) }
                
                let request = UpdateUserRequest(
                    firebaseUID: user.firebaseUID,
                    name: user.name,
                    phoneNumber: user.phoneNumber,
                    isNotificationsEnabled: user.isNotificationsEnabled,
                    avatarURL: user.avatarURL ?? ""
                )
                let proto = try await grpc.userService.updateUser(request)
                let updatedUser = proto.toDomain()
                
                // Invalidate cache
                let cacheKey = CacheKey(namespace: "user", identifier: user.firebaseUID)
                await cache.invalidate(CachePattern(namespace: "user", prefix: user.firebaseUID))
                
                return updatedUser
            },
            
            uploadAvatar: { imageData in
                let trace = performance.startTrace("user.upload_avatar")
                defer { performance.endTrace(trace, ["size": imageData.count]) }
                
                let request = UploadAvatarRequest(
                    firebaseUID: auth.getCurrentUID() ?? "",
                    imageData: imageData
                )
                let response = try await grpc.userService.uploadAvatar(request)
                return URL(string: response.url)!
            },
            
            deleteAccount: {
                guard let uid = auth.getCurrentUID() else { throw UserRepositoryError.userNotFound }
                
                let trace = performance.startTrace("user.delete")
                defer { performance.endTrace(trace, ["user_id": uid]) }
                
                let request = DeleteUserRequest(firebaseUID: uid)
                try await grpc.userService.deleteUser(request)
                try await auth.signOut()
                
                // Clear cache
                await cache.invalidate(CachePattern(namespace: "user", prefix: uid))
            },
            
            signOut: {
                try await auth.signOut()
                // Clear all user-related cache
                await cache.invalidate(CachePattern(namespace: "user", prefix: nil))
            },
            
            // Legacy methods
            loadUser: {
                // Check if user exists in UserDefaults (migration from mock app)
                if UserDefaults.standard.object(forKey: "userName") != nil {
                    return User.fromUserDefaults()
                }
                return nil
            },
            
            saveUser: { user in
                // Legacy save to UserDefaults for compatibility
                let defaults = UserDefaults.standard
                defaults.set(user.name, forKey: "userName")
                defaults.set(user.phoneNumber, forKey: "userPhone")
                defaults.set(user.profileDescription, forKey: "userProfileDescription")
                defaults.set(user.avatarImageData, forKey: "userAvatarImage")
                defaults.set(user.qrCodeId, forKey: "userQRCodeId")
                defaults.set(user.checkInInterval, forKey: "userCheckInInterval")
                defaults.set(user.isNotificationsEnabled, forKey: "userNotificationsEnabled")
                defaults.set(user.notify30MinBefore, forKey: "userNotify30MinBefore")
                defaults.set(user.notify2HoursBefore, forKey: "userNotify2HoursBefore")
            }
        )
    }()
    
    static let testValue = UserRepository(
        getCurrentUser: {
            return User(
                firebaseUID: "test-uid",
                name: "Test User",
                phoneNumber: "+1234567890"
            )
        },
        sendVerificationCode: { _ in "test-verification-id" },
        verifyPhoneNumber: { _, _ in
            User(
                firebaseUID: "test-uid",
                name: "Test User",
                phoneNumber: "+1234567890"
            )
        },
        createAccountWithPhone: { name, phoneNumber in
            User(
                firebaseUID: "test-uid",
                name: name,
                phoneNumber: phoneNumber
            )
        },
        updateProfile: { user in user },
        uploadAvatar: { _ in URL(string: "https://example.com/avatar.jpg")! },
        deleteAccount: { },
        signOut: { },
        loadUser: { nil },
        saveUser: { _ in }
    )
}

extension DependencyValues {
    var userRepository: UserRepository {
        get { self[UserRepository.self] }
        set { self[UserRepository.self] = newValue }
    }
}

// MARK: - Error Types

enum UserRepositoryError: Error, LocalizedError {
    case networkError
    case authenticationFailed
    case userNotFound
    case updateFailed
    
    var errorDescription: String? {
        switch self {
        case .networkError: return "Network error occurred"
        case .authenticationFailed: return "Login failed"
        case .userNotFound: return "User not found"
        case .updateFailed: return "Update failed"
        }
    }
}