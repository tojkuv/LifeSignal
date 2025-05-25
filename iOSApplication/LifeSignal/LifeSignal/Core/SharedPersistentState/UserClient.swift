import Foundation
import ComposableArchitecture
import Dependencies
import DependenciesMacros
import UIKit
import CoreImage.CIFilterBuiltins
@_exported import Sharing

// MARK: - gRPC Protocol Integration

protocol UserServiceProtocol: Sendable {
    func getUser(_ request: GetUserRequest) async throws -> User_Proto
    func createUser(_ request: CreateUserRequest) async throws -> User_Proto
    func updateUser(_ request: UpdateUserRequest) async throws -> User_Proto
    func deleteUser(_ request: DeleteUserRequest) async throws -> Empty_Proto
    func uploadAvatar(_ request: UploadAvatarRequest) async throws -> UploadAvatarResponse
    func updateFCMToken(_ request: UpdateFCMTokenRequest) async throws -> User_Proto
}

// MARK: - gRPC Request/Response Types

struct GetUserRequest: Sendable {
    let uid: String
    let authToken: String
}

struct CreateUserRequest: Sendable {
    let uid: String
    let name: String
    let phoneNumber: String
    let phoneRegion: String
    let isNotificationsEnabled: Bool
    let notify30MinBefore: Bool
    let notify2HoursBefore: Bool
    let fcmToken: String?
    let authToken: String
}

struct UpdateUserRequest: Sendable {
    let id: UUID
    let name: String
    let phoneNumber: String
    let phoneRegion: String
    let emergencyNote: String
    let checkInInterval: TimeInterval
    let isNotificationsEnabled: Bool
    let notify30MinBefore: Bool
    let notify2HoursBefore: Bool
    let avatarURL: String
    let fcmToken: String?
    let authToken: String
}

struct DeleteUserRequest: Sendable {
    let userId: UUID
    let authToken: String
}

struct UploadAvatarRequest: Sendable {
    let userId: UUID
    let imageData: Data
    let authToken: String
}

struct UploadAvatarResponse: Sendable {
    let url: String
}

struct UpdateFCMTokenRequest: Sendable {
    let userId: UUID
    let fcmToken: String
    let authToken: String
}

struct Empty_Proto: Sendable {}

// MARK: - gRPC Proto Types

struct User_Proto: Sendable {
    var id: String
    var name: String
    var phoneNumber: String
    var phoneRegion: String
    var emergencyNote: String
    var checkInInterval: Int64
    var lastCheckedIn: Int64?
    var isNotificationsEnabled: Bool
    var notify30MinBefore: Bool
    var notify2HoursBefore: Bool
    var qrCodeId: String
    var avatarURL: String
    var fcmToken: String?
    var lastModified: Int64
}

// MARK: - Mock gRPC Service

final class MockUserService: UserServiceProtocol {
    func getUser(_ request: GetUserRequest) async throws -> User_Proto {
        try await Task.sleep(for: .milliseconds(500))
        return User_Proto(
            id: request.uid,
            name: "Mock User",
            phoneNumber: "+1234567890",
            phoneRegion: "US",
            emergencyNote: "",
            checkInInterval: 86400,
            lastCheckedIn: nil,
            isNotificationsEnabled: true,
            notify30MinBefore: true,
            notify2HoursBefore: true,
            qrCodeId: UUID().uuidString,
            avatarURL: "",
            fcmToken: "mock_fcm_token_\(UUID().uuidString)",
            lastModified: Int64(Date().timeIntervalSince1970)
        )
    }

    func createUser(_ request: CreateUserRequest) async throws -> User_Proto {
        try await Task.sleep(for: .milliseconds(800))
        return User_Proto(
            id: request.uid,
            name: request.name,
            phoneNumber: request.phoneNumber,
            phoneRegion: request.phoneRegion,
            emergencyNote: "",
            checkInInterval: 86400,
            lastCheckedIn: nil,
            isNotificationsEnabled: request.isNotificationsEnabled,
            notify30MinBefore: request.notify30MinBefore,
            notify2HoursBefore: request.notify2HoursBefore,
            qrCodeId: UUID().uuidString,
            avatarURL: "",
            fcmToken: request.fcmToken,
            lastModified: Int64(Date().timeIntervalSince1970)
        )
    }

    func updateUser(_ request: UpdateUserRequest) async throws -> User_Proto {
        try await Task.sleep(for: .milliseconds(600))
        return User_Proto(
            id: request.id.uuidString,
            name: request.name,
            phoneNumber: request.phoneNumber,
            phoneRegion: request.phoneRegion,
            emergencyNote: request.emergencyNote,
            checkInInterval: Int64(request.checkInInterval),
            lastCheckedIn: nil,
            isNotificationsEnabled: request.isNotificationsEnabled,
            notify30MinBefore: request.notify30MinBefore,
            notify2HoursBefore: request.notify2HoursBefore,
            qrCodeId: UUID().uuidString,
            avatarURL: request.avatarURL,
            fcmToken: request.fcmToken,
            lastModified: Int64(Date().timeIntervalSince1970)
        )
    }

    func deleteUser(_ request: DeleteUserRequest) async throws -> Empty_Proto {
        try await Task.sleep(for: .milliseconds(500))
        return Empty_Proto()
    }

    func uploadAvatar(_ request: UploadAvatarRequest) async throws -> UploadAvatarResponse {
        try await Task.sleep(for: .milliseconds(1500))
        return UploadAvatarResponse(url: "https://example.com/avatar/\(request.userId.uuidString).jpg")
    }
    
    func updateFCMToken(_ request: UpdateFCMTokenRequest) async throws -> User_Proto {
        try await Task.sleep(for: .milliseconds(300))
        return User_Proto(
            id: request.userId.uuidString,
            name: "Mock User",
            phoneNumber: "+1234567890",
            phoneRegion: "US",
            emergencyNote: "",
            checkInInterval: 86400,
            lastCheckedIn: nil,
            isNotificationsEnabled: true,
            notify30MinBefore: true,
            notify2HoursBefore: true,
            qrCodeId: UUID().uuidString,
            avatarURL: "",
            fcmToken: request.fcmToken,
            lastModified: Int64(Date().timeIntervalSince1970)
        )
    }
}

// MARK: - Proto Mapping Extensions

extension User_Proto {
    func toDomain() -> User {
        User(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            phoneNumber: phoneNumber,
            phoneRegion: phoneRegion,
            emergencyNote: emergencyNote,
            checkInInterval: TimeInterval(checkInInterval),
            lastCheckedIn: lastCheckedIn.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            isNotificationsEnabled: isNotificationsEnabled,
            notify30MinBefore: notify30MinBefore,
            notify2HoursBefore: notify2HoursBefore,
            qrCodeId: UUID(uuidString: qrCodeId) ?? UUID(),
            avatarURL: avatarURL.isEmpty ? nil : avatarURL,
            avatarImageData: nil,
            fcmToken: fcmToken,
            lastModified: Date(timeIntervalSince1970: TimeInterval(lastModified))
        )
    }
}

// MARK: - User Shared State

extension SharedReaderKey where Self == InMemoryKey<User?>.Default {
    static var currentUser: Self {
        Self[.inMemory("currentUser"), default: nil]
    }
}

extension SharedReaderKey where Self == InMemoryKey<[PendingUserAction]>.Default {
    static var pendingUserActions: Self {
        Self[.inMemory("pendingUserActions"), default: []]
    }
}

// MARK: - User Persistence Models

struct PendingUserAction: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var operation: UserOperation
    var payload: Data
    var createdAt: Date
    var attemptCount: Int
    var maxAttempts: Int
    var priority: ActionPriority
    
    enum ActionPriority: Int, Codable, CaseIterable {
        case low = 0
        case standard = 1
        case high = 2
        case critical = 3
    }
    
    enum UserOperation: String, Codable, CaseIterable {
        case createUser = "user.create"
        case updateUser = "user.update"
        case deleteUser = "user.delete"
        case uploadUserAvatar = "user.avatar.upload"
        case recordUserCheckIn = "user.checkin"
    }
    
    init(
        id: UUID = UUID(),
        operation: UserOperation,
        payload: Data,
        createdAt: Date = Date(),
        attemptCount: Int = 0,
        maxAttempts: Int = 3,
        priority: ActionPriority = .standard
    ) {
        self.id = id
        self.operation = operation
        self.payload = payload
        self.createdAt = createdAt
        self.attemptCount = attemptCount
        self.maxAttempts = maxAttempts
        self.priority = priority
    }
    
    var canRetry: Bool {
        attemptCount < maxAttempts
    }
    
    var isExpired: Bool {
        let expiryTime: TimeInterval = priority == .critical ? 86400 : 3600
        return Date().timeIntervalSince(createdAt) > expiryTime
    }
}

// MARK: - User Domain Model

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
    var qrCodeImageData: Data?
    var fcmToken: String?
    var lastModified: Date

    init(
        id: UUID = UUID(),
        name: String,
        phoneNumber: String,
        phoneRegion: String = "US",
        emergencyNote: String = "",
        checkInInterval: TimeInterval = 86400,
        lastCheckedIn: Date? = nil,
        isNotificationsEnabled: Bool = true,
        notify30MinBefore: Bool = true,
        notify2HoursBefore: Bool = true,
        qrCodeId: UUID = UUID(),
        avatarURL: String? = nil,
        avatarImageData: Data? = nil,
        qrCodeImageData: Data? = nil,
        fcmToken: String? = nil,
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
        self.qrCodeImageData = qrCodeImageData
        self.fcmToken = fcmToken
        self.lastModified = lastModified
    }
    
    var avatarImage: UIImage? {
        guard let imageData = avatarImageData else { return nil }
        return UIImage(data: imageData)
    }
    
    var qrCodeImage: UIImage? {
        guard let imageData = qrCodeImageData else { return nil }
        return UIImage(data: imageData)
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
}

// MARK: - Client Errors

enum UserClientError: Error, LocalizedError {
    case userNotFound(String)
    case saveFailed(String)
    case deleteFailed(String)
    case uploadFailed(String)
    case downloadFailed(String)
    case invalidData(String)
    case networkError(String)
    case qrCodeGenerationFailed(String)
    
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
        case .qrCodeGenerationFailed(let details):
            return "QR code generation failed: \(details)"
        }
    }
}

// MARK: - User Client

// MARK: - User Persistence Helpers

extension UserClient {
    static func getAuthenticationToken() async throws -> String {
        @Dependency(\.authenticationClient) var authClient
        guard let token = try await authClient.getIdToken(false) else {
            throw UserClientError.networkError("No authentication token available")
        }
        return token
    }
    
    static func storeUserData(_ user: User, key: String = "currentUser") async {
        // Mock local storage - would use Core Data/file system in production
        try? await Task.sleep(for: .milliseconds(50))
    }
    
    static func retrieveUserData<T>(_ key: String, type: T.Type) async -> T? {
        // Mock retrieval - would load from Core Data/file system in production
        try? await Task.sleep(for: .milliseconds(50))
        return nil
    }
    
    static func addPendingUserAction(_ operation: PendingUserAction.UserOperation, payload: Data, priority: PendingUserAction.ActionPriority) async {
        @Shared(.pendingUserActions) var pending
        let action = PendingUserAction(
            operation: operation,
            payload: payload,
            priority: priority
        )
        $pending.withLock { $0.append(action) }
    }
    
    static func executeWithNetworkFallback<T>(
        _ networkOperation: @escaping () async throws -> T,
        cacheKey: String,
        pendingOperation: PendingUserAction.UserOperation? = nil,
        priority: PendingUserAction.ActionPriority = .standard
    ) async throws -> T {
        @Dependency(\.networkClient) var network
        
        // Check network connectivity
        let isConnected = await network.checkConnectivity()
        
        if isConnected {
            do {
                let result = try await networkOperation()
                // Store successful result locally
                if let user = result as? User {
                    await Self.storeUserData(user, key: cacheKey)
                }
                return result
            } catch {
                // If operation fails and we have a pending operation, queue it
                if let operation = pendingOperation {
                    await Self.addPendingUserAction(operation, payload: Data(), priority: priority)
                }
                throw error
            }
        } else {
            // Try to load from local storage when offline
            if let cachedData = await Self.retrieveUserData(cacheKey, type: T.self) {
                return cachedData
            }
            
            // Queue operation for later synchronization if possible
            if let operation = pendingOperation {
                await Self.addPendingUserAction(operation, payload: Data(), priority: priority)
            }
            
            throw UserClientError.networkError("Operation requires network connectivity")
        }
    }
    
    // MARK: - QR Code Generation Helpers
    
    static func generateQRCodeImage(from data: String, size: CGFloat = 300) throws -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        guard let qrData = data.data(using: .ascii) else {
            throw UserClientError.qrCodeGenerationFailed("Failed to encode QR data")
        }
        
        filter.setValue(qrData, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        
        guard let outputImage = filter.outputImage else {
            throw UserClientError.qrCodeGenerationFailed("Failed to generate QR image")
        }
        
        let scaleX = size / outputImage.extent.size.width
        let scaleY = size / outputImage.extent.size.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            throw UserClientError.qrCodeGenerationFailed("Failed to create CGImage")
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    static func generateShareableQRCodeImage(qrImage: UIImage, userName: String) throws -> UIImage {
        let size = CGSize(width: 400, height: 500)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Title
            let titleText = "LifeSignal QR Code"
            let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]
            let titleSize = titleText.size(withAttributes: titleAttributes)
            titleText.draw(at: CGPoint(x: (size.width - titleSize.width) / 2, y: 20), withAttributes: titleAttributes)
            
            // QR Code
            let qrSize: CGFloat = 300
            let qrX = (size.width - qrSize) / 2
            let qrY: CGFloat = 80
            qrImage.draw(in: CGRect(x: qrX, y: qrY, width: qrSize, height: qrSize))
            
            // User name
            let nameText = "\(userName)'s Emergency Contact Code"
            let nameFont = UIFont.systemFont(ofSize: 16, weight: .medium)
            let nameAttributes: [NSAttributedString.Key: Any] = [
                .font: nameFont,
                .foregroundColor: UIColor.darkGray
            ]
            let nameSize = nameText.size(withAttributes: nameAttributes)
            nameText.draw(at: CGPoint(x: (size.width - nameSize.width) / 2, y: qrY + qrSize + 20), withAttributes: nameAttributes)
            
            // Instructions
            let instructionText = "Scan to add as emergency contact"
            let instructionFont = UIFont.systemFont(ofSize: 14, weight: .regular)
            let instructionAttributes: [NSAttributedString.Key: Any] = [
                .font: instructionFont,
                .foregroundColor: UIColor.gray
            ]
            let instructionSize = instructionText.size(withAttributes: instructionAttributes)
            instructionText.draw(at: CGPoint(x: (size.width - instructionSize.width) / 2, y: qrY + qrSize + 50), withAttributes: instructionAttributes)
        }
    }
    
    static func generateMockQRCodeImage(data: String, size: CGFloat = 300) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: size, height: size)))
            
            // Draw a simple grid pattern to simulate QR code
            UIColor.black.setStroke()
            let gridSize: CGFloat = size / 20
            for i in 0..<20 {
                for j in 0..<20 {
                    if (i + j) % 2 == 0 {
                        let rect = CGRect(x: CGFloat(i) * gridSize, y: CGFloat(j) * gridSize, width: gridSize, height: gridSize)
                        context.fill(rect)
                    }
                }
            }
            
            // Add mock data text in center
            let font = UIFont.systemFont(ofSize: 8)
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.red]
            let text = "MOCK\nQR"
            text.draw(in: CGRect(x: size/2 - 20, y: size/2 - 10, width: 40, height: 20), withAttributes: attributes)
        }
    }
}

@DependencyClient
struct UserClient {
    // gRPC service integration
    var userService: UserServiceProtocol = MockUserService()
    
    // User operations that sync with shared state
    var getCurrentUser: @Sendable () async -> User? = { nil }
    var createUser: @Sendable (String, String, String, String) async throws -> User = { _, _, _, _ in throw UserClientError.saveFailed("User") }
    var updateProfile: @Sendable (User) async throws -> User = { _ in throw UserClientError.saveFailed("User") }
    var deleteUser: @Sendable (UUID) async throws -> Void = { _ in throw UserClientError.deleteFailed("User") }
    var checkIn: @Sendable () async throws -> User = { throw UserClientError.saveFailed("CheckIn") }
    
    // Avatar operations
    var uploadAvatar: @Sendable (UUID, Data) async throws -> URL = { _, _ in throw UserClientError.uploadFailed("Avatar") }
    var downloadAvatarData: @Sendable (String) async throws -> Data = { _ in throw UserClientError.downloadFailed("Avatar") }
    var updateAvatar: @Sendable (UIImage?) async throws -> User = { _ in throw UserClientError.saveFailed("Avatar") }
    
    // Notification settings
    var updateNotificationSettings: @Sendable (Bool, Bool, Bool) async throws -> User = { _, _, _ in throw UserClientError.saveFailed("NotificationSettings") }
    
    // Profile updates
    var updateName: @Sendable (String) async throws -> User = { _ in throw UserClientError.saveFailed("Name") }
    var updatePhone: @Sendable (String, String) async throws -> User = { _, _ in throw UserClientError.saveFailed("Phone") }
    var updateEmergencyNote: @Sendable (String) async throws -> User = { _ in throw UserClientError.saveFailed("EmergencyNote") }
    var updateCheckInInterval: @Sendable (TimeInterval) async throws -> User = { _ in throw UserClientError.saveFailed("CheckInInterval") }
    var regenerateQRCode: @Sendable () async throws -> User = { throw UserClientError.saveFailed("QRCode") }
    
    // QR Code operations
    var getQRCodeImage: @Sendable (CGFloat?) async throws -> UIImage = { _ in throw UserClientError.qrCodeGenerationFailed("QR Code") }
    var getShareableQRCodeImage: @Sendable () async throws -> UIImage = { throw UserClientError.qrCodeGenerationFailed("Shareable QR Code") }
    var refreshQRCodeImage: @Sendable () async throws -> User = { throw UserClientError.saveFailed("QR Code Refresh") }
    
    // FCM Token operations for push notifications
    var updateFCMToken: @Sendable (String) async throws -> User = { _ in throw UserClientError.saveFailed("FCM Token") }
    var getCurrentFCMToken: @Sendable () async -> String? = { nil }
    var clearFCMToken: @Sendable () async throws -> User = { throw UserClientError.saveFailed("FCM Token Clear") }
}

extension UserClient: DependencyKey {
    static let liveValue: UserClient = UserClient()
    static let testValue = UserClient()
    
    static let mockValue = UserClient(
        userService: MockUserService(),
        
        getCurrentUser: {
            @Shared(.currentUser) var currentUser
            return currentUser
        },
        
        createUser: { firebaseUID, name, phoneNumber, phoneRegion in
            return try await Self.executeWithNetworkFallback({
                let authToken = try await Self.getAuthenticationToken()
                let service = MockUserService()
                let request = CreateUserRequest(
                    uid: firebaseUID,
                    name: name,
                    phoneNumber: phoneNumber,
                    phoneRegion: phoneRegion,
                    isNotificationsEnabled: true,
                    notify30MinBefore: true,
                    notify2HoursBefore: false,
                    fcmToken: nil, // Will be set later when FCM token is available
                    authToken: authToken
                )
                
                let userProto = try await service.createUser(request)
                let newUser = userProto.toDomain()
                
                // Update shared state
                @Shared(.currentUser) var currentUser
                $currentUser.withLock { $0 = newUser }
                
                return newUser
            }, cacheKey: "currentUser", pendingOperation: .createUser, priority: .high)
        },
        
        updateProfile: { user in
            return try await Self.executeWithNetworkFallback({
                let authToken = try await Self.getAuthenticationToken()
                let service = MockUserService()
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
                    avatarURL: user.avatarURL ?? "",
                    fcmToken: user.fcmToken,
                    authToken: authToken
                )
                
                let userProto = try await service.updateUser(request)
                let updatedUser = userProto.toDomain()
                
                // Update shared state
                @Shared(.currentUser) var currentUser
                $currentUser.withLock { $0 = updatedUser }
                
                return updatedUser
            }, cacheKey: "currentUser", pendingOperation: .updateUser, priority: .standard)
        },
        
        deleteUser: { userID in
            let authToken = try await Self.getAuthenticationToken()
            let service = MockUserService()
            let request = DeleteUserRequest(userId: userID, authToken: authToken)
            
            _ = try await service.deleteUser(request)
            
            // Clear shared state
            @Shared(.currentUser) var currentUser
            $currentUser.withLock { $0 = nil }
        },
        
        checkIn: {
            @Shared(.currentUser) var currentUser
            @Dependency(\.networkClient) var network
            
            guard var user = currentUser else {
                throw UserClientError.userNotFound("No current user")
            }
            
            let now = Date()
            user.lastCheckedIn = now
            user.lastModified = now
            
            // Always update locally first for immediate feedback
            $currentUser.withLock { $0 = user }
            await Self.storeUserData(user)
            
            // Queue for server sync (check-ins are critical)
            let isConnected = await network.checkConnectivity()
            if !isConnected {
                await Self.addPendingUserAction(.recordUserCheckIn, payload: Data(), priority: .critical)
            }
            
            return user
        },
        
        uploadAvatar: { userID, imageData in
            let authToken = try await Self.getAuthenticationToken()
            let service = MockUserService()
            let request = UploadAvatarRequest(userId: userID, imageData: imageData, authToken: authToken)
            
            let response = try await service.uploadAvatar(request)
            
            guard let url = URL(string: response.url) else {
                throw UserClientError.uploadFailed("Invalid avatar URL returned")
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
        
        updateAvatar: { image in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(500))
            
            @Shared(.currentUser) var currentUser
            guard var user = currentUser else {
                throw UserClientError.userNotFound("No current user")
            }
            
            if let image = image {
                user.avatarImageData = image.jpegData(compressionQuality: 0.8)
            } else {
                user.avatarImageData = nil
            }
            user.lastModified = Date()
            
            $currentUser.withLock { $0 = user }
            return user
        },
        
        updateNotificationSettings: { enabled, notify30Min, notify2Hours in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(300))
            
            @Shared(.currentUser) var currentUser
            guard var user = currentUser else {
                throw UserClientError.userNotFound("No current user")
            }
            
            user.isNotificationsEnabled = enabled
            user.notify30MinBefore = notify30Min
            user.notify2HoursBefore = notify2Hours
            user.lastModified = Date()
            
            $currentUser.withLock { $0 = user }
            return user
        },
        
        updateName: { newName in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(300))
            
            @Shared(.currentUser) var currentUser
            guard var user = currentUser else {
                throw UserClientError.userNotFound("No current user")
            }
            
            user.name = newName
            user.lastModified = Date()
            
            $currentUser.withLock { $0 = user }
            return user
        },
        
        updatePhone: { phoneNumber, region in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(300))
            
            @Shared(.currentUser) var currentUser
            guard var user = currentUser else {
                throw UserClientError.userNotFound("No current user")
            }
            
            user.phoneNumber = phoneNumber
            user.phoneRegion = region
            user.lastModified = Date()
            
            $currentUser.withLock { $0 = user }
            return user
        },
        
        updateEmergencyNote: { note in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(300))
            
            @Shared(.currentUser) var currentUser
            guard var user = currentUser else {
                throw UserClientError.userNotFound("No current user")
            }
            
            user.emergencyNote = note
            user.lastModified = Date()
            
            $currentUser.withLock { $0 = user }
            return user
        },
        
        updateCheckInInterval: { interval in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(300))
            
            @Shared(.currentUser) var currentUser
            guard var user = currentUser else {
                throw UserClientError.userNotFound("No current user")
            }
            
            user.checkInInterval = interval
            user.lastModified = Date()
            
            $currentUser.withLock { $0 = user }
            return user
        },
        
        regenerateQRCode: {
            // Simulate delay
            try await Task.sleep(for: .milliseconds(200))
            
            @Shared(.currentUser) var currentUser
            guard var user = currentUser else {
                throw UserClientError.userNotFound("No current user")
            }
            
            user.qrCodeId = UUID()
            user.qrCodeImageData = nil // Clear cached image so it regenerates
            user.lastModified = Date()
            
            $currentUser.withLock { $0 = user }
            return user
        },
        
        getQRCodeImage: { size in
            @Shared(.currentUser) var currentUser
            guard let user = currentUser else {
                throw UserClientError.userNotFound("No current user")
            }
            
            let requestedSize = size ?? 300
            
            // Check if we have cached QR code image
            if let cachedImageData = user.qrCodeImageData,
               let cachedImage = UIImage(data: cachedImageData) {
                return cachedImage
            }
            
            // Generate new QR code image
            let qrData = user.qrCodeId.uuidString
            let qrImage: UIImage
            
            #if DEBUG
            // Use mock implementation in debug
            qrImage = Self.generateMockQRCodeImage(data: qrData, size: requestedSize)
            #else
            // Use real implementation in production
            qrImage = try Self.generateQRCodeImage(from: qrData, size: requestedSize)
            #endif
            
            // Cache the generated image
            if let imageData = qrImage.pngData() {
                var updatedUser = user
                updatedUser.qrCodeImageData = imageData
                await Self.storeUserData(updatedUser)
                $currentUser.withLock { $0 = updatedUser }
            }
            
            return qrImage
        },
        
        getShareableQRCodeImage: {
            @Shared(.currentUser) var currentUser
            guard let user = currentUser else {
                throw UserClientError.userNotFound("No current user")
            }
            
            // Get the basic QR code first
            let qrImage = try await Self.mockValue.getQRCodeImage(300)
            
            #if DEBUG
            // Mock shareable image
            let size = CGSize(width: 400, height: 500)
            let renderer = UIGraphicsImageRenderer(size: size)
            
            return renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                
                let titleText = "MOCK - LifeSignal QR Code"
                let titleFont = UIFont.systemFont(ofSize: 20, weight: .bold)
                let titleAttributes: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: UIColor.red]
                let titleSize = titleText.size(withAttributes: titleAttributes)
                titleText.draw(at: CGPoint(x: (size.width - titleSize.width) / 2, y: 20), withAttributes: titleAttributes)
                
                let qrSize: CGFloat = 300
                let qrX = (size.width - qrSize) / 2
                let qrY: CGFloat = 80
                qrImage.draw(in: CGRect(x: qrX, y: qrY, width: qrSize, height: qrSize))
                
                let nameText = "\(user.name)'s Emergency Contact Code (MOCK)"
                let nameFont = UIFont.systemFont(ofSize: 16, weight: .medium)
                let nameAttributes: [NSAttributedString.Key: Any] = [.font: nameFont, .foregroundColor: UIColor.darkGray]
                let nameSize = nameText.size(withAttributes: nameAttributes)
                nameText.draw(at: CGPoint(x: (size.width - nameSize.width) / 2, y: qrY + qrSize + 20), withAttributes: nameAttributes)
            }
            #else
            // Use real implementation in production
            return try Self.generateShareableQRCodeImage(qrImage: qrImage, userName: user.name)
            #endif
        },
        
        refreshQRCodeImage: {
            @Shared(.currentUser) var currentUser
            guard var user = currentUser else {
                throw UserClientError.userNotFound("No current user")
            }
            
            // Clear cached QR code image to force regeneration
            user.qrCodeImageData = nil
            user.lastModified = Date()
            
            $currentUser.withLock { $0 = user }
            await Self.storeUserData(user)
            
            return user
        },
        
        // FCM Token operations for push notifications
        updateFCMToken: { token in
            return try await Self.executeWithNetworkFallback({
                let authToken = try await Self.getAuthenticationToken()
                let service = MockUserService()
                
                @Shared(.currentUser) var currentUser
                guard let user = currentUser else {
                    throw UserClientError.userNotFound("No current user")
                }
                
                let request = UpdateFCMTokenRequest(
                    userId: user.id,
                    fcmToken: token,
                    authToken: authToken
                )
                
                let userProto = try await service.updateFCMToken(request)
                let updatedUser = userProto.toDomain()
                
                // Update shared state
                $currentUser.withLock { $0 = updatedUser }
                await Self.storeUserData(updatedUser)
                
                return updatedUser
            }, cacheKey: "currentUser", pendingOperation: .updateUser, priority: .high)
        },
        
        getCurrentFCMToken: {
            @Shared(.currentUser) var currentUser
            return currentUser?.fcmToken
        },
        
        clearFCMToken: {
            @Shared(.currentUser) var currentUser
            guard var user = currentUser else {
                throw UserClientError.userNotFound("No current user")
            }
            
            // Clear FCM token locally first for immediate feedback
            user.fcmToken = nil
            user.lastModified = Date()
            
            $currentUser.withLock { $0 = user }
            await Self.storeUserData(user)
            
            // Also clear on server if connected
            return try await Self.executeWithNetworkFallback({
                let authToken = try await Self.getAuthenticationToken()
                let service = MockUserService()
                
                let request = UpdateFCMTokenRequest(
                    userId: user.id,
                    fcmToken: "", // Empty string to clear
                    authToken: authToken
                )
                
                let userProto = try await service.updateFCMToken(request)
                let updatedUser = userProto.toDomain()
                
                // Update shared state
                $currentUser.withLock { $0 = updatedUser }
                await Self.storeUserData(updatedUser)
                
                return updatedUser
            }, cacheKey: "currentUser", pendingOperation: .updateUser, priority: .standard)
        }
    )
}

extension DependencyValues {
    var userClient: UserClient {
        get { self[UserClient.self] }
        set { self[UserClient.self] = newValue }
    }
}