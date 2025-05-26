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
    func checkIn(_ request: CheckInRequest) async throws -> User_Proto
    func updateAvatar(_ request: UpdateAvatarRequest) async throws -> UpdateAvatarResponse
    func deleteAvatar(_ request: DeleteAvatarRequest) async throws -> User_Proto
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
    let notificationPreference: NotificationPreference
    let isEmergencyAlertEnabled: Bool
    let authToken: String
}

struct UpdateUserRequest: Sendable {
    let id: UUID
    let name: String
    let phoneNumber: String
    let phoneRegion: String
    let emergencyNote: String
    let checkInInterval: TimeInterval
    let lastCheckedIn: Date?
    let notificationPreference: NotificationPreference
    let isEmergencyAlertEnabled: Bool
    let qrCodeId: UUID
    let avatarURL: String
    let authToken: String
}

struct CheckInRequest: Sendable {
    let userId: UUID
    let timestamp: Int64
    let authToken: String
}

struct DeleteUserRequest: Sendable {
    let userId: UUID
    let authToken: String
}

struct UpdateAvatarRequest: Sendable {
    let userId: UUID
    let imageData: Data
    let authToken: String
}

struct UpdateAvatarResponse: Sendable {
    let avatarURL: String // Supabase storage URL
    let user: User_Proto // Updated user with new avatar URL
}

struct DeleteAvatarRequest: Sendable {
    let userId: UUID
    let authToken: String
}

// MARK: - Notification Preference Enum

enum NotificationPreference: String, Codable, CaseIterable, Sendable {
    case disabled = "disabled"
    case thirtyMinutes = "30_minutes"
    case twoHours = "2_hours"
    
    var displayName: String {
        switch self {
        case .disabled:
            return "Disabled"
        case .thirtyMinutes:
            return "30 minutes before"
        case .twoHours:
            return "2 hours before"
        }
    }
    
    var timeInterval: TimeInterval? {
        switch self {
        case .disabled:
            return nil
        case .thirtyMinutes:
            return 30 * 60 // 30 minutes in seconds
        case .twoHours:
            return 2 * 60 * 60 // 2 hours in seconds
        }
    }
}


// MARK: - gRPC Proto Types

struct User_Proto: Sendable {
    var id: String
    var name: String
    var phoneNumber: String
    var phoneRegion: String
    var emergencyNote: String
    var checkInInterval: Int64
    var lastCheckedIn: Int64?
    var notificationPreference: NotificationPreference
    var isEmergencyAlertEnabled: Bool
    var emergencyAlertTimestamp: Int64?
    var qrCodeId: String
    var avatarURL: String
    var lastModified: Int64
}

// MARK: - Mock gRPC Service

final class MockUserService: UserServiceProtocol {
    func getUser(_ request: GetUserRequest) async throws -> User_Proto {
        try await Task.sleep(for: .milliseconds(500))
        
        // Create a mock user with recent check-in for testing
        let now = Date()
        let recentCheckIn = now.addingTimeInterval(-3600) // 1 hour ago
        
        return User_Proto(
            id: request.uid,
            name: "Mock User",
            phoneNumber: "+1234567890",
            phoneRegion: "US",
            emergencyNote: "",
            checkInInterval: 28800, // 8 hours (minimum interval)
            lastCheckedIn: Int64(recentCheckIn.timeIntervalSince1970),
            notificationPreference: .thirtyMinutes,
            isEmergencyAlertEnabled: false,
            emergencyAlertTimestamp: nil,
            qrCodeId: UUID().uuidString,
            avatarURL: "",
            lastModified: Int64(Date().timeIntervalSince1970)
        )
    }
    
    func checkIn(_ request: CheckInRequest) async throws -> User_Proto {
        try await Task.sleep(for: .milliseconds(400))
        return User_Proto(
            id: request.userId.uuidString,
            name: "Mock User",
            phoneNumber: "+1234567890",
            phoneRegion: "US",
            emergencyNote: "",
            checkInInterval: 28800, // 8 hours (minimum interval)
            lastCheckedIn: request.timestamp,
            notificationPreference: .thirtyMinutes,
            isEmergencyAlertEnabled: false,
            emergencyAlertTimestamp: nil,
            qrCodeId: UUID().uuidString,
            avatarURL: "",
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
            checkInInterval: 28800, // 8 hours (minimum interval) (instead of 24 hours)
            lastCheckedIn: Int64(Date().timeIntervalSince1970),
            notificationPreference: request.notificationPreference,
            isEmergencyAlertEnabled: request.isEmergencyAlertEnabled,
            emergencyAlertTimestamp: nil,
            qrCodeId: UUID().uuidString,
            avatarURL: "",
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
            lastCheckedIn: request.lastCheckedIn.map { Int64($0.timeIntervalSince1970) },
            notificationPreference: request.notificationPreference,
            isEmergencyAlertEnabled: request.isEmergencyAlertEnabled,
            emergencyAlertTimestamp: request.isEmergencyAlertEnabled ? Int64(Date().timeIntervalSince1970) : nil,
            qrCodeId: request.qrCodeId.uuidString,
            avatarURL: request.avatarURL,
            lastModified: Int64(Date().timeIntervalSince1970)
        )
    }

    func deleteUser(_ request: DeleteUserRequest) async throws -> Empty_Proto {
        try await Task.sleep(for: .milliseconds(500))
        return Empty_Proto()
    }

    func updateAvatar(_ request: UpdateAvatarRequest) async throws -> UpdateAvatarResponse {
        try await Task.sleep(for: .milliseconds(1500))
        
        // Simulate Supabase storage URL
        let supabaseAvatarURL = "https://your-project.supabase.co/storage/v1/object/public/avatars/\(request.userId.uuidString)/avatar.jpg"
        
        // Return updated user with new avatar URL
        let updatedUser = User_Proto(
            id: request.userId.uuidString,
            name: "Mock User",
            phoneNumber: "+1234567890",
            phoneRegion: "US",
            emergencyNote: "",
            checkInInterval: 28800, // 8 hours (minimum interval)
            lastCheckedIn: nil,
            notificationPreference: .thirtyMinutes,
            isEmergencyAlertEnabled: true,
            emergencyAlertTimestamp: nil,
            qrCodeId: UUID().uuidString,
            avatarURL: supabaseAvatarURL,
            lastModified: Int64(Date().timeIntervalSince1970)
        )
        
        return UpdateAvatarResponse(
            avatarURL: supabaseAvatarURL,
            user: updatedUser
        )
    }
    
    func deleteAvatar(_ request: DeleteAvatarRequest) async throws -> User_Proto {
        try await Task.sleep(for: .milliseconds(800))
        
        // Simulate deletion from Supabase storage and return updated user
        return User_Proto(
            id: request.userId.uuidString,
            name: "Mock User",
            phoneNumber: "+1234567890",
            phoneRegion: "US",
            emergencyNote: "",
            checkInInterval: 28800, // 8 hours (minimum interval)
            lastCheckedIn: nil,
            notificationPreference: .thirtyMinutes,
            isEmergencyAlertEnabled: true,
            emergencyAlertTimestamp: nil,
            qrCodeId: UUID().uuidString,
            avatarURL: "", // Cleared avatar URL after Supabase deletion
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
            notificationPreference: notificationPreference,
            isEmergencyAlertEnabled: isEmergencyAlertEnabled,
            emergencyAlertTimestamp: emergencyAlertTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            qrCodeId: UUID(uuidString: qrCodeId) ?? UUID(),
            avatarURL: avatarURL.isEmpty ? nil : avatarURL,
            lastModified: Date(timeIntervalSince1970: TimeInterval(lastModified))
        )
    }
}

// MARK: - User QR Code Generation Extension

extension User {
    /// Generates QR code images and stores them in shared state with metadata
    func generateAndCacheQRCodeImages() {
        let qrData = qrCodeId.uuidString
        let metadata = ImageMetadata(qrCodeId: qrCodeId)
        
        // Generate basic QR code image
        let qrImage: UIImage
        #if DEBUG
        qrImage = UserClient.generateMockQRCodeImage(data: qrData, size: 300)
        #else
        do {
            qrImage = try UserClient.generateQRCodeImage(from: qrData, size: 300)
        } catch {
            qrImage = UserClient.generateMockQRCodeImage(data: qrData, size: 300)
        }
        #endif
        
        // Generate styled shareable QR code image
        let shareableImage: UIImage
        #if DEBUG
        shareableImage = UserClient.generateMockShareableQRCodeImage(qrImage: qrImage, userName: name)
        #else
        do {
            shareableImage = try UserClient.generateShareableQRCodeImage(qrImage: qrImage, userName: name)
        } catch {
            shareableImage = UserClient.generateMockShareableQRCodeImage(qrImage: qrImage, userName: name)
        }
        #endif
        
        // Store in shared state with metadata
        @Shared(.userQRCodeImage) var qrCodeImage
        @Shared(.userShareableQRCodeImage) var shareableQRCodeImage
        
        if let qrImageData = qrImage.pngData() {
            $qrCodeImage.withLock { $0 = QRImageWithMetadata(image: qrImageData, metadata: metadata) }
        }
        
        if let shareableImageData = shareableImage.pngData() {
            $shareableQRCodeImage.withLock { $0 = QRImageWithMetadata(image: shareableImageData, metadata: metadata) }
        }
    }
}

// MARK: - User Shared State

extension SharedReaderKey where Self == InMemoryKey<User?>.Default {
    static var currentUser: Self {
        Self[.inMemory("currentUser"), default: nil]
    }
}

// MARK: - Image Metadata for Cache Validation

struct ImageMetadata: Codable, Equatable {
    let qrCodeId: UUID?
    let avatarURL: String?
    let lastGenerated: Date
    
    init(qrCodeId: UUID? = nil, avatarURL: String? = nil) {
        self.qrCodeId = qrCodeId
        self.avatarURL = avatarURL
        self.lastGenerated = Date()
    }
}

struct QRImageWithMetadata: Codable {
    let image: Data
    let metadata: ImageMetadata
}

struct AvatarImageWithMetadata: Codable, Equatable {
    let image: Data
    let metadata: ImageMetadata
}

extension SharedReaderKey where Self == InMemoryKey<QRImageWithMetadata?>.Default {
    static var userQRCodeImage: Self {
        Self[.inMemory("userQRCodeImage"), default: nil]
    }
    
    static var userShareableQRCodeImage: Self {
        Self[.inMemory("userShareableQRCodeImage"), default: nil]
    }
}

extension SharedReaderKey where Self == InMemoryKey<AvatarImageWithMetadata?>.Default {
    static var userAvatarImage: Self {
        Self[.inMemory("userAvatarImage"), default: nil]
    }
}


// MARK: - User Domain Model
//
// This model exactly matches User_Proto with these additions:
// - avatarImageData: Local cache of avatar image (not sent over gRPC)
// - qrCodeImageData: Local cache of QR code image (not sent over gRPC)

struct User: Codable, Equatable, Identifiable, Sendable {
    // MARK: - Core Properties (matches User_Proto)
    let id: UUID
    var name: String
    var phoneNumber: String
    var phoneRegion: String
    var emergencyNote: String
    var checkInInterval: TimeInterval
    var lastCheckedIn: Date?
    var notificationPreference: NotificationPreference
    var isEmergencyAlertEnabled: Bool
    var emergencyAlertTimestamp: Date?
    var qrCodeId: UUID
    var avatarURL: String?
    var lastModified: Date
    
    // MARK: - Helper Methods
    
    /// Updates emergency alert enabled status, resetting timestamp if disabled
    mutating func setEmergencyAlertEnabled(_ enabled: Bool) {
        isEmergencyAlertEnabled = enabled
        if !enabled {
            emergencyAlertTimestamp = nil // Reset timestamp when disabled
        }
        lastModified = Date()
    }
}

// MARK: - Client Errors

enum UserClientError: Error, LocalizedError {
    case userNotFound
    case operationFailed
    case networkError
    case qrCodeGenerationFailed
    case authenticationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found"
        case .operationFailed:
            return "Operation failed"
        case .networkError:
            return "Network error"
        case .qrCodeGenerationFailed:
            return "QR code generation failed"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        }
    }
}

// MARK: - User Client

// MARK: - UserClient Internal Helpers

extension UserClient {
    /// Gets the authenticated user info for UserClient operations
    private static func getAuthenticatedUserInfo() async throws -> (token: String, uid: String) {
        @Shared(.authenticationToken) var authToken
        @Shared(.internalAuthUID) var authUID
        
        guard let token = authToken else {
            throw UserClientError.authenticationFailed("No authentication token available")
        }
        
        guard let uid = authUID else {
            throw UserClientError.authenticationFailed("No authenticated user")
        }
        
        return (token: token, uid: uid)
    }
    
    // MARK: - QR Code Generation Helpers
    
    static func generateQRCodeImage(from data: String, size: CGFloat = 300) throws -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        guard let qrData = data.data(using: .ascii) else {
            throw UserClientError.qrCodeGenerationFailed
        }
        
        filter.setValue(qrData, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        
        guard let outputImage = filter.outputImage else {
            throw UserClientError.qrCodeGenerationFailed
        }
        
        let scaleX = size / outputImage.extent.size.width
        let scaleY = size / outputImage.extent.size.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            throw UserClientError.qrCodeGenerationFailed
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
    
    static func generateMockShareableQRCodeImage(qrImage: UIImage, userName: String) -> UIImage {
        // Portrait mode aspect ratio (3:4)
        let size = CGSize(width: 400, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Title
            let titleText = "MOCK - LifeSignal QR Code"
            let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.red
            ]
            let titleSize = titleText.size(withAttributes: titleAttributes)
            titleText.draw(at: CGPoint(x: (size.width - titleSize.width) / 2, y: 40), withAttributes: titleAttributes)
            
            // QR Code (centered)
            let qrSize: CGFloat = 300
            let qrX = (size.width - qrSize) / 2
            let qrY: CGFloat = 150
            qrImage.draw(in: CGRect(x: qrX, y: qrY, width: qrSize, height: qrSize))
            
            // User name
            let nameText = "\(userName)'s Emergency Contact Code (MOCK)"
            let nameFont = UIFont.systemFont(ofSize: 18, weight: .medium)
            let nameAttributes: [NSAttributedString.Key: Any] = [
                .font: nameFont,
                .foregroundColor: UIColor.darkGray
            ]
            let nameSize = nameText.size(withAttributes: nameAttributes)
            nameText.draw(at: CGPoint(x: (size.width - nameSize.width) / 2, y: qrY + qrSize + 30), withAttributes: nameAttributes)
            
            // Instructions
            let instructionText = "Scan to add as emergency contact"
            let instructionFont = UIFont.systemFont(ofSize: 16, weight: .regular)
            let instructionAttributes: [NSAttributedString.Key: Any] = [
                .font: instructionFont,
                .foregroundColor: UIColor.gray
            ]
            let instructionSize = instructionText.size(withAttributes: instructionAttributes)
            instructionText.draw(at: CGPoint(x: (size.width - instructionSize.width) / 2, y: qrY + qrSize + 70), withAttributes: instructionAttributes)
        }
    }
}

@DependencyClient
struct UserClient {
    // gRPC service integration
    var userService: UserServiceProtocol = MockUserService()
    
    // Core User Operations (update shared state only)
    var getUser: @Sendable () async throws -> User? = { nil }
    var createUser: @Sendable (String, String, String, String) async throws -> Void = { _, _, _, _ in throw UserClientError.operationFailed }
    var updateUser: @Sendable (User) async throws -> Void = { _ in throw UserClientError.operationFailed }
    var deleteUser: @Sendable (UUID) async throws -> Void = { _ in throw UserClientError.operationFailed }
    
    
    
    // Avatar operations (Supabase storage via gRPC)
    var updateAvatarData: @Sendable (UUID, Data) async throws -> Void = { _, _ in throw UserClientError.operationFailed }
    var downloadAvatarData: @Sendable (String) async throws -> Data = { _ in throw UserClientError.operationFailed }
    var deleteAvatarData: @Sendable (UUID) async throws -> Void = { _ in throw UserClientError.operationFailed }
    
    // QR Code operations
    var resetQRCode: @Sendable () async throws -> Void = { throw UserClientError.operationFailed }
    var updateQRCodeImages: @Sendable () async -> Void = { }
    var clearQRCodeImages: @Sendable () async -> Void = { }
}

extension UserClient: DependencyKey {
    static let liveValue: UserClient = UserClient()
    static let testValue = UserClient()
    
    static let mockValue = UserClient(
        userService: MockUserService(),
        
        getUser: {
            // Make gRPC call to get current user data
            @Shared(.authenticationToken) var authToken
            guard let token = authToken else {
                throw UserClientError.networkError
            }
            
            // Get user ID from shared authentication state
            @Shared(.internalAuthUID) var internalAuthUID
            guard let firebaseUID = internalAuthUID else {
                throw UserClientError.userNotFound
            }
            
            let service = MockUserService()
            let request = GetUserRequest(uid: firebaseUID, authToken: token)
            
            let userProto = try await service.getUser(request)
            let user = userProto.toDomain()
            
            // Update shared state
            @Shared(.currentUser) var currentUser
            $currentUser.withLock { $0 = user }
            
            // Generate QR code images
            user.generateAndCacheQRCodeImages()
            
            // Download avatar if available
            if let avatarURL = user.avatarURL {
                Task {
                    do {
                        // Mock avatar download simulation
                        try await Task.sleep(for: .milliseconds(500))
                        let imageData = Data() // Mock image data
                        let metadata = ImageMetadata(avatarURL: avatarURL)
                        @Shared(.userAvatarImage) var avatarImage
                        $avatarImage.withLock { 
                            $0 = AvatarImageWithMetadata(image: imageData, metadata: metadata)
                        }
                    } catch {
                        // Handle download error silently
                    }
                }
            }
            
            return user
        },
        
        createUser: { firebaseUID, name, phoneNumber, phoneRegion in
            let authInfo = try await Self.getAuthenticatedUserInfo()
            let service = MockUserService()
            let request = CreateUserRequest(
                uid: firebaseUID,
                name: name,
                phoneNumber: phoneNumber,
                phoneRegion: phoneRegion,
                notificationPreference: .thirtyMinutes, // Default to 30 minutes
                isEmergencyAlertEnabled: false, // Default disabled
                authToken: authInfo.token
            )
            
            let userProto = try await service.createUser(request)
            let newUser = userProto.toDomain()
            
            // Generate QR code images for new user
            newUser.generateAndCacheQRCodeImages()
            
            // Update shared state
            @Shared(.currentUser) var currentUser
            $currentUser.withLock { $0 = newUser }
        },
        
        updateUser: { user in
            let authInfo = try await Self.getAuthenticatedUserInfo()
            let service = MockUserService()
            let request = UpdateUserRequest(
                id: user.id,
                name: user.name,
                phoneNumber: user.phoneNumber,
                phoneRegion: user.phoneRegion,
                emergencyNote: user.emergencyNote,
                checkInInterval: user.checkInInterval,
                lastCheckedIn: user.lastCheckedIn,
                notificationPreference: user.notificationPreference,
                isEmergencyAlertEnabled: user.isEmergencyAlertEnabled,
                qrCodeId: user.qrCodeId,
                avatarURL: user.avatarURL ?? "",
                authToken: authInfo.token
            )
            
            let userProto = try await service.updateUser(request)
            let updatedUser = userProto.toDomain()
            
            // Update shared state
            @Shared(.currentUser) var currentUser
            $currentUser.withLock { $0 = updatedUser }
        },
        
        deleteUser: { userID in
            let authInfo = try await Self.getAuthenticatedUserInfo()
            let service = MockUserService()
            let request = DeleteUserRequest(userId: userID, authToken: authInfo.token)
            
            _ = try await service.deleteUser(request)
            
            // Clear shared state
            @Shared(.currentUser) var currentUser
            $currentUser.withLock { $0 = nil }
        },
        
        
        updateAvatarData: { userID, imageData in
            let authInfo = try await Self.getAuthenticatedUserInfo()
            let service = MockUserService()
            let request = UpdateAvatarRequest(userId: userID, imageData: imageData, authToken: authInfo.token)
            
            let response = try await service.updateAvatar(request)
            let updatedUser = response.user.toDomain()
            
            // Cache the uploaded image in shared state with metadata
            let metadata = ImageMetadata(avatarURL: response.avatarURL)
            @Shared(.userAvatarImage) var avatarImage
            $avatarImage.withLock { 
                $0 = AvatarImageWithMetadata(image: imageData, metadata: metadata)
            }
            
            // Update shared state with new user data
            @Shared(.currentUser) var currentUser
            $currentUser.withLock { $0 = updatedUser }
        },
        
        downloadAvatarData: { avatarURL in
            // Simulate downloading from Supabase storage
            try await Task.sleep(for: .milliseconds(1000))
            
            // In production, this would fetch from the Supabase storage URL
            // For now, return mock avatar image data (1x1 pixel PNG)
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
        
        deleteAvatarData: { userID in
            let authInfo = try await Self.getAuthenticatedUserInfo()
            let service = MockUserService()
            let request = DeleteAvatarRequest(userId: userID, authToken: authInfo.token)
            
            let userProto = try await service.deleteAvatar(request)
            let updatedUser = userProto.toDomain()
            
            // Clear avatar from shared state
            @Shared(.userAvatarImage) var avatarImage
            $avatarImage.withLock { $0 = nil }
            
            // Update shared state with updated user
            @Shared(.currentUser) var currentUser
            $currentUser.withLock { $0 = updatedUser }
        },
        
        
        resetQRCode: {
            @Shared(.currentUser) var currentUser
            guard var user = currentUser else {
                throw UserClientError.userNotFound
            }
            
            // Generate new QR code ID
            let newQRCodeId = UUID()
            user.qrCodeId = newQRCodeId
            user.lastModified = Date()
            
            // Update user profile via gRPC to sync new QR ID with server
            let authInfo = try await Self.getAuthenticatedUserInfo()
            let service = MockUserService()
            let request = UpdateUserRequest(
                id: user.id,
                name: user.name,
                phoneNumber: user.phoneNumber,
                phoneRegion: user.phoneRegion,
                emergencyNote: user.emergencyNote,
                checkInInterval: user.checkInInterval,
                lastCheckedIn: user.lastCheckedIn,
                notificationPreference: user.notificationPreference,
                isEmergencyAlertEnabled: user.isEmergencyAlertEnabled,
                qrCodeId: newQRCodeId,
                avatarURL: user.avatarURL ?? "",
                authToken: authInfo.token
            )
            
            // Call gRPC to update user profile with new QR ID
            let userProto = try await service.updateUser(request)
            let updatedUser = userProto.toDomain()
            
            // Generate fresh QR code images after reset
            updatedUser.generateAndCacheQRCodeImages()
            
            // Update shared state with new user data and fresh QR images
            $currentUser.withLock { $0 = updatedUser }
        },
        
        updateQRCodeImages: {
            @Shared(.currentUser) var currentUser
            guard let user = currentUser else { return }
            user.generateAndCacheQRCodeImages()
        },
        
        clearQRCodeImages: {
            @Shared(.userQRCodeImage) var qrCodeImage
            @Shared(.userShareableQRCodeImage) var shareableQRCodeImage
            
            $qrCodeImage.withLock { $0 = nil }
            $shareableQRCodeImage.withLock { $0 = nil }
        }
    )
}

extension DependencyValues {
    var userClient: UserClient {
        get { self[UserClient.self] }
        set { self[UserClient.self] = newValue }
    }
}