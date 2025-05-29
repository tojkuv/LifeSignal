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
    let biometricAuthEnabled: Bool
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
    let biometricAuthEnabled: Bool
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

struct User_Proto: Sendable, Codable {
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
    var biometricAuthEnabled: Bool
}

// MARK: - Mock User Backend Service

/// Simple mock backend for user data persistence
final class MockUserBackendService: Sendable {
    
    // Simple data storage keys
    private static let usersKey = "MockUserBackend_Users"
    private static let avatarDataKey = "MockUserBackend_AvatarData"
    
    // MARK: - Data Persistence
    
    private func getStoredUsers() -> [String: User] {
        guard let data = UserDefaults.standard.data(forKey: Self.usersKey),
              let decoded = try? JSONDecoder().decode([String: User].self, from: data) else {
            return [:]
        }
        return decoded
    }
    
    private func storeUsers(_ users: [String: User]) {
        guard let data = try? JSONEncoder().encode(users) else { return }
        UserDefaults.standard.set(data, forKey: Self.usersKey)
    }
    
    private func getAvatarData() -> [String: Data] {
        guard let data = UserDefaults.standard.data(forKey: Self.avatarDataKey),
              let decoded = try? JSONDecoder().decode([String: Data].self, from: data) else {
            return [:]
        }
        return decoded
    }
    
    private func storeAvatarData(_ avatarData: [String: Data]) {
        guard let data = try? JSONEncoder().encode(avatarData) else { return }
        UserDefaults.standard.set(data, forKey: Self.avatarDataKey)
    }
    
    // MARK: - Simple Operations
    
    func getUser(uid: String) -> User? {
        let storedUsers = getStoredUsers()
        return storedUsers[uid]
    }
    
    func createUser(_ user: User) {
        var storedUsers = getStoredUsers()
        storedUsers[user.id.uuidString] = user
        storeUsers(storedUsers)
    }
    
    func updateUser(_ user: User) {
        var storedUsers = getStoredUsers()
        var updatedUser = user
        updatedUser.lastModified = Date()
        storedUsers[user.id.uuidString] = updatedUser
        storeUsers(storedUsers)
    }
    
    func deleteUser(userId: String) {
        var storedUsers = getStoredUsers()
        storedUsers.removeValue(forKey: userId)
        storeUsers(storedUsers)
        
        // Remove avatar data
        var avatarData = getAvatarData()
        avatarData.removeValue(forKey: userId)
        storeAvatarData(avatarData)
    }
    
    func updateAvatarData(userId: String, imageData: Data) {
        var avatarData = getAvatarData()
        avatarData[userId] = imageData
        storeAvatarData(avatarData)
    }
    
    func deleteAvatarData(userId: String) {
        var avatarData = getAvatarData()
        avatarData.removeValue(forKey: userId)
        storeAvatarData(avatarData)
    }
    
    func getAvatarData(userId: String) -> Data? {
        let avatarData = getAvatarData()
        return avatarData[userId]
    }
    
    // Helper method to clear all backend data for testing
    static func clearAllBackendData() {
        UserDefaults.standard.removeObject(forKey: usersKey)
        UserDefaults.standard.removeObject(forKey: avatarDataKey)
    }
}

// MARK: - Simple User Service Protocol (for mock implementation)

protocol SimpleUserServiceProtocol: Sendable {
    func getUser(uid: String, authToken: String) async throws -> User?
    func createUser(uid: String, name: String, phoneNumber: String, phoneRegion: String, authToken: String) async throws -> User
    func updateUser(_ user: User, authToken: String) async throws -> User
    func deleteUser(userId: String, authToken: String) async throws
    func checkIn(userId: String, timestamp: Date, authToken: String) async throws -> User?
    func updateAvatarData(userId: String, imageData: Data, authToken: String) async throws
    func deleteAvatarData(userId: String, authToken: String) async throws
    func getAvatarData(userId: String) -> Data?
    static func clearAllMockData()
}

// MARK: - Mock User Service (Simple interface)

final class MockUserService: SimpleUserServiceProtocol, Sendable {
    
    private let backend = MockUserBackendService()
    
    func getUser(uid: String, authToken: String) async throws -> User? {
        try await Task.sleep(for: .milliseconds(500))
        return backend.getUser(uid: uid)
    }
    
    func createUser(uid: String, name: String, phoneNumber: String, phoneRegion: String, authToken: String) async throws -> User {
        try await Task.sleep(for: .milliseconds(800))
        
        let newUser = User(
            id: UUID(uuidString: uid) ?? UUID(),
            name: name,
            phoneNumber: phoneNumber,
            phoneRegion: phoneRegion,
            emergencyNote: "",
            checkInInterval: 86400, // 24 hours default
            lastCheckedIn: Date(),
            notificationPreference: .thirtyMinutes,
            isEmergencyAlertEnabled: true,
            emergencyAlertTimestamp: nil,
            qrCodeId: UUID(),
            avatarURL: nil,
            lastModified: Date(),
            biometricAuthEnabled: false
        )
        
        backend.createUser(newUser)
        return newUser
    }
    
    func updateUser(_ user: User, authToken: String) async throws -> User {
        try await Task.sleep(for: .milliseconds(600))
        backend.updateUser(user)
        return user
    }
    
    func deleteUser(userId: String, authToken: String) async throws {
        try await Task.sleep(for: .milliseconds(500))
        backend.deleteUser(userId: userId)
    }
    
    func checkIn(userId: String, timestamp: Date, authToken: String) async throws -> User? {
        try await Task.sleep(for: .milliseconds(400))
        
        guard var user = backend.getUser(uid: userId) else {
            throw UserClientError.userNotFound
        }
        
        user.lastCheckedIn = timestamp
        backend.updateUser(user)
        return user
    }
    
    func updateAvatarData(userId: String, imageData: Data, authToken: String) async throws {
        try await Task.sleep(for: .milliseconds(1500))
        backend.updateAvatarData(userId: userId, imageData: imageData)
    }
    
    func deleteAvatarData(userId: String, authToken: String) async throws {
        try await Task.sleep(for: .milliseconds(800))
        backend.deleteAvatarData(userId: userId)
    }
    
    func getAvatarData(userId: String) -> Data? {
        return backend.getAvatarData(userId: userId)
    }
    
    // Helper method to clear all mock data for testing
    static func clearAllMockData() {
        MockUserBackendService.clearAllBackendData()
    }
}

// MARK: - Mock gRPC Adapter (converts simple service to gRPC protocol)

final class MockUserServiceGRPCAdapter: UserServiceProtocol, Sendable {
    
    private let simpleService = MockUserService()
    
    func getUser(_ request: GetUserRequest) async throws -> User_Proto {
        guard let user = try await simpleService.getUser(uid: request.uid, authToken: request.authToken) else {
            throw UserClientError.userNotFound
        }
        return user.toProto()
    }
    
    func createUser(_ request: CreateUserRequest) async throws -> User_Proto {
        let user = try await simpleService.createUser(
            uid: request.uid,
            name: request.name,
            phoneNumber: request.phoneNumber,
            phoneRegion: request.phoneRegion,
            authToken: request.authToken
        )
        return user.toProto()
    }
    
    func updateUser(_ request: UpdateUserRequest) async throws -> User_Proto {
        let user = User(
            id: request.id,
            name: request.name,
            phoneNumber: request.phoneNumber,
            phoneRegion: request.phoneRegion,
            emergencyNote: request.emergencyNote,
            checkInInterval: request.checkInInterval,
            lastCheckedIn: request.lastCheckedIn,
            notificationPreference: request.notificationPreference,
            isEmergencyAlertEnabled: request.isEmergencyAlertEnabled,
            emergencyAlertTimestamp: nil,
            qrCodeId: request.qrCodeId,
            avatarURL: request.avatarURL.isEmpty ? nil : request.avatarURL,
            lastModified: Date(),
            biometricAuthEnabled: request.biometricAuthEnabled
        )
        
        let updatedUser = try await simpleService.updateUser(user, authToken: request.authToken)
        return updatedUser.toProto()
    }
    
    func deleteUser(_ request: DeleteUserRequest) async throws -> Empty_Proto {
        try await simpleService.deleteUser(userId: request.userId.uuidString, authToken: request.authToken)
        return Empty_Proto()
    }
    
    func checkIn(_ request: CheckInRequest) async throws -> User_Proto {
        guard let user = try await simpleService.checkIn(
            userId: request.userId.uuidString,
            timestamp: Date(timeIntervalSince1970: TimeInterval(request.timestamp)),
            authToken: request.authToken
        ) else {
            throw UserClientError.userNotFound
        }
        return user.toProto()
    }
    
    func updateAvatar(_ request: UpdateAvatarRequest) async throws -> UpdateAvatarResponse {
        try await simpleService.updateAvatarData(
            userId: request.userId.uuidString,
            imageData: request.imageData,
            authToken: request.authToken
        )
        
        // Mock response - in real implementation this would return the actual URL from storage
        let mockAvatarURL = "mock://avatar/\(request.userId.uuidString)"
        let updatedUser = try await simpleService.getUser(uid: request.userId.uuidString, authToken: request.authToken)
        
        return UpdateAvatarResponse(
            avatarURL: mockAvatarURL,
            user: updatedUser?.toProto() ?? User_Proto(
                id: request.userId.uuidString,
                name: "Unknown",
                phoneNumber: "",
                phoneRegion: "",
                emergencyNote: "",
                checkInInterval: 86400,
                lastCheckedIn: nil,
                notificationPreference: .thirtyMinutes,
                isEmergencyAlertEnabled: false,
                emergencyAlertTimestamp: nil,
                qrCodeId: UUID().uuidString,
                avatarURL: mockAvatarURL,
                lastModified: Int64(Date().timeIntervalSince1970),
                biometricAuthEnabled: false
            )
        )
    }
    
    func deleteAvatar(_ request: DeleteAvatarRequest) async throws -> User_Proto {
        try await simpleService.deleteAvatarData(userId: request.userId.uuidString, authToken: request.authToken)
        
        guard let user = try await simpleService.getUser(uid: request.userId.uuidString, authToken: request.authToken) else {
            throw UserClientError.userNotFound
        }
        return user.toProto()
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
            lastModified: Date(timeIntervalSince1970: TimeInterval(lastModified)),
            biometricAuthEnabled: biometricAuthEnabled
        )
    }
}

extension User {
    func toProto() -> User_Proto {
        User_Proto(
            id: id.uuidString,
            name: name,
            phoneNumber: phoneNumber,
            phoneRegion: phoneRegion,
            emergencyNote: emergencyNote,
            checkInInterval: Int64(checkInInterval),
            lastCheckedIn: lastCheckedIn.map { Int64($0.timeIntervalSince1970) },
            notificationPreference: notificationPreference,
            isEmergencyAlertEnabled: isEmergencyAlertEnabled,
            emergencyAlertTimestamp: emergencyAlertTimestamp.map { Int64($0.timeIntervalSince1970) },
            qrCodeId: qrCodeId.uuidString,
            avatarURL: avatarURL ?? "",
            lastModified: Int64(lastModified.timeIntervalSince1970),
            biometricAuthEnabled: biometricAuthEnabled
        )
    }
}

// MARK: - User QR Code Generation Extension

extension User {
    /// Generates QR code images and returns them for storage in shared state
    func generateQRCodeImages() -> (qrImage: QRImageWithMetadata?, shareableImage: QRImageWithMetadata?) {
        let qrData = qrCodeId.uuidString
        let metadata = ImageMetadata(qrCodeId: qrCodeId)
        
        // Generate basic QR code image
        let qrImage: UIImage
        do {
            qrImage = try UserClient.generateQRCodeImage(from: qrData, size: 300)
        } catch {
            // Fallback to mock only on error
            qrImage = UserClient.generateMockQRCodeImage(data: qrData, size: 300)
        }
        
        // Generate styled shareable QR code image
        let shareableImage: UIImage
        do {
            shareableImage = try UserClient.generateShareableQRCodeImage(qrImage: qrImage, userName: name)
        } catch {
            // Fallback to mock only on error
            shareableImage = UserClient.generateMockShareableQRCodeImage(qrImage: qrImage, userName: name)
        }
        
        // Return images with metadata for external storage
        let qrImageWithMetadata = qrImage.pngData().map { QRImageWithMetadata(image: $0, metadata: metadata) }
        let shareableImageWithMetadata = shareableImage.pngData().map { QRImageWithMetadata(image: $0, metadata: metadata) }
        
        return (qrImageWithMetadata, shareableImageWithMetadata)
    }
}

// MARK: - User Shared State

struct UserClientState: Equatable {
    var currentUser: User?
    var isLoading: Bool
    var lastSyncTimestamp: Date?
    
    // Image cache data (consolidated from separate shared states)
    // Note: Images are excluded from Codable to prevent encoding issues
    var qrCodeImage: QRImageWithMetadata?
    var shareableQRCodeImage: QRImageWithMetadata?
    var avatarImage: AvatarImageWithMetadata?
    
    init(
        currentUser: User? = nil, 
        isLoading: Bool = false, 
        lastSyncTimestamp: Date? = nil,
        qrCodeImage: QRImageWithMetadata? = nil,
        shareableQRCodeImage: QRImageWithMetadata? = nil,
        avatarImage: AvatarImageWithMetadata? = nil
    ) {
        self.currentUser = currentUser
        self.isLoading = isLoading
        self.lastSyncTimestamp = lastSyncTimestamp
        self.qrCodeImage = qrCodeImage
        self.shareableQRCodeImage = shareableQRCodeImage
        self.avatarImage = avatarImage
    }
}

// MARK: - Custom Codable Implementation for UserClientState

extension UserClientState: Codable {
    private enum CodingKeys: String, CodingKey {
        case currentUser
        case isLoading
        case lastSyncTimestamp
        // Image data is intentionally excluded from encoding to prevent memory issues
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentUser = try container.decodeIfPresent(User.self, forKey: .currentUser)
        isLoading = try container.decodeIfPresent(Bool.self, forKey: .isLoading) ?? false
        lastSyncTimestamp = try container.decodeIfPresent(Date.self, forKey: .lastSyncTimestamp)
        
        // Image data is not persisted, starts as nil and gets regenerated
        qrCodeImage = nil
        shareableQRCodeImage = nil
        avatarImage = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(currentUser, forKey: .currentUser)
        try container.encode(isLoading, forKey: .isLoading)
        try container.encodeIfPresent(lastSyncTimestamp, forKey: .lastSyncTimestamp)
        
        // Image data is intentionally not encoded to prevent memory issues and crashes
        // Images will be regenerated when needed
    }
}

// MARK: - Clean Shared Key Implementation (FileStorage)

extension SharedReaderKey where Self == FileStorageKey<UserClientState>.Default {
    static var userInternalState: Self {
        Self[.fileStorage(.documentsDirectory.appending(component: "userInternalState.json")), default: UserClientState()]
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

struct QRImageWithMetadata: Codable, Equatable {
    let image: Data
    let metadata: ImageMetadata
}

struct AvatarImageWithMetadata: Codable, Equatable {
    let image: Data
    let metadata: ImageMetadata
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
    var biometricAuthEnabled: Bool
    
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
struct UserClient: ClientContext {
    
    // gRPC service integration (uses adapter for mock)
    var userService: UserServiceProtocol = MockUserServiceGRPCAdapter()
    
    // Core User Operations - Features must pass auth tokens
    var getUser: @Sendable (String, String) async throws -> User? = { _, _ in nil }
    var createUser: @Sendable (String, String, String, String, String) async throws -> Void = { _, _, _, _, _ in throw UserClientError.operationFailed }
    var updateUser: @Sendable (User, String) async throws -> Void = { _, _ in throw UserClientError.operationFailed }
    var deleteUser: @Sendable (UUID, String) async throws -> Void = { _, _ in throw UserClientError.operationFailed }
    
    // Avatar operations - Features must pass auth tokens
    var updateAvatarData: @Sendable (UUID, Data, String) async throws -> Void = { _, _, _ in throw UserClientError.operationFailed }
    var downloadAvatarData: @Sendable (String) async throws -> Data = { _ in throw UserClientError.operationFailed }
    var deleteAvatarData: @Sendable (UUID, String) async throws -> Void = { _, _ in throw UserClientError.operationFailed }
    
    // QR Code operations - Features must pass auth tokens  
    var resetQRCode: @Sendable (String) async throws -> Void = { _ in throw UserClientError.operationFailed }
    var updateQRCodeImages: @Sendable () async -> Void = { }
    var clearQRCodeImages: @Sendable () async -> Void = { }
    
    // State management operations
    var clearUserState: @Sendable () async throws -> Void = { }
    var regenerateImagesIfNeeded: @Sendable () async -> Void = { }
}

// MARK: - TCA Dependency Registration

extension UserClient: DependencyKey {
    static let liveValue: UserClient = UserClient()
    static let testValue = UserClient()
    
    static let mockValue = UserClient(
        userService: MockUserServiceGRPCAdapter(),
        
        getUser: { authToken, uid in
            let service = MockUserService()
            let user = try await service.getUser(uid: uid, authToken: authToken)
            
            if let user = user {
                // Generate QR code images first
                let qrImages = user.generateQRCodeImages()
                
                // Update shared state atomically
                @Shared(.userInternalState) var sharedUserState
                $sharedUserState.withLock { state in
                    state.currentUser = user
                    state.isLoading = false
                    state.lastSyncTimestamp = Date()
                    state.qrCodeImage = qrImages.qrImage
                    state.shareableQRCodeImage = qrImages.shareableImage
                }
                
                // Load avatar if available
                if let avatarData = service.getAvatarData(userId: uid) {
                    Task {
                        let metadata = ImageMetadata(avatarURL: user.avatarURL)
                        // Update avatar in unified state
                        @Shared(.userInternalState) var sharedUserState
                        $sharedUserState.withLock { state in
                            let avatarImageWithMetadata = AvatarImageWithMetadata(image: avatarData, metadata: metadata)
                            state.avatarImage = avatarImageWithMetadata
                        }
                    }
                }
            }
            
            return user
        },
        
        createUser: { firebaseUID, name, phoneNumber, phoneRegion, authToken in
            let service = MockUserService()
            let newUser = try await service.createUser(uid: firebaseUID, name: name, phoneNumber: phoneNumber, phoneRegion: phoneRegion, authToken: authToken)
            
            // Generate QR code images for new user
            let qrImages = newUser.generateQRCodeImages()
            
            // Update shared state
            @Shared(.userInternalState) var sharedUserState
            $sharedUserState.withLock { state in
                state.currentUser = newUser
                state.isLoading = false
                state.lastSyncTimestamp = Date()
                state.qrCodeImage = qrImages.qrImage
                state.shareableQRCodeImage = qrImages.shareableImage
            }
            
        },
        
        updateUser: { user, authToken in
            let service = MockUserService()
            let updatedUser = try await service.updateUser(user, authToken: authToken)
            
            // Update shared state
            @Shared(.userInternalState) var sharedUserState
            $sharedUserState.withLock { state in
                state.currentUser = updatedUser
                state.isLoading = false
                state.lastSyncTimestamp = Date()
            }
            
        },
        
        deleteUser: { userID, authToken in
            let service = MockUserService()
            try await service.deleteUser(userId: userID.uuidString, authToken: authToken)
            
            // Clear shared state
            @Shared(.userInternalState) var sharedUserState
            $sharedUserState.withLock { state in
                state.currentUser = nil
                state.isLoading = false
                state.lastSyncTimestamp = Date()
            }
            
        },
        
        updateAvatarData: { userID, imageData, authToken in
            let service = MockUserService()
            try await service.updateAvatarData(userId: userID.uuidString, imageData: imageData, authToken: authToken)
            
            // Update shared state with avatar image
            @Shared(.userInternalState) var sharedUserState
            $sharedUserState.withLock { state in
                let metadata = ImageMetadata(avatarURL: "mock://avatar/\(userID.uuidString)")
                let avatarImageWithMetadata = AvatarImageWithMetadata(image: imageData, metadata: metadata)
                state.avatarImage = avatarImageWithMetadata
                state.lastSyncTimestamp = Date()
            }
            
        },
        
        downloadAvatarData: { avatarURL in
            // For mock, return the stored avatar data
            try await Task.sleep(for: .milliseconds(500))
            
            // Extract user ID from mock URL format
            if let userID = extractUserIDFromAvatarURL(avatarURL) {
                let service = MockUserService()
                if let data = service.getAvatarData(userId: userID) {
                    return data
                }
            }
            
            throw UserClientError.operationFailed
        },
        
        deleteAvatarData: { userID, authToken in
            let service = MockUserService()
            try await service.deleteAvatarData(userId: userID.uuidString, authToken: authToken)
            
            // Update shared state with cleared avatar
            @Shared(.userInternalState) var sharedUserState
            $sharedUserState.withLock { state in
                state.avatarImage = nil
                state.lastSyncTimestamp = Date()
            }
            
        },
        
        
        resetQRCode: { authToken in
            @Shared(.userInternalState) var sharedUserState
            guard var user = sharedUserState.currentUser else {
                throw UserClientError.userNotFound
            }
            
            // Generate new QR code ID
            let newQRCodeId = UUID()
            user.qrCodeId = newQRCodeId
            user.lastModified = Date()
            
            // Update user profile via gRPC to sync new QR ID with server
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
                biometricAuthEnabled: user.biometricAuthEnabled,
                authToken: authToken
            )
            
            // Call gRPC to update user profile with new QR ID
            let updatedUser = try await service.updateUser(user, authToken: authToken)
            
            // Generate fresh QR code images after reset
            let qrImages = updatedUser.generateQRCodeImages()
            
            // Update shared state
            $sharedUserState.withLock { state in
                state.currentUser = updatedUser
                state.isLoading = false
                state.lastSyncTimestamp = Date()
                state.qrCodeImage = qrImages.qrImage
                state.shareableQRCodeImage = qrImages.shareableImage
            }
            
        },
        
        updateQRCodeImages: {
            @Shared(.userInternalState) var sharedUserState
            guard let user = sharedUserState.currentUser else { return }
            let qrImages = user.generateQRCodeImages()
            $sharedUserState.withLock { state in
                state.qrCodeImage = qrImages.qrImage
                state.shareableQRCodeImage = qrImages.shareableImage
            }
        },
        
        clearQRCodeImages: {
            // Clear QR code images in unified state
            @Shared(.userInternalState) var sharedUserState
            $sharedUserState.withLock { state in
                state.qrCodeImage = nil
                state.shareableQRCodeImage = nil
            }
        },
        
        clearUserState: {
            // Clear all user state - used during sign out
            @Shared(.userInternalState) var sharedUserState
            $sharedUserState.withLock { state in
                state.currentUser = nil
                state.isLoading = false
                state.lastSyncTimestamp = nil
                state.qrCodeImage = nil
                state.shareableQRCodeImage = nil
                state.avatarImage = nil
            }
        },
        
        regenerateImagesIfNeeded: {
            @Shared(.userInternalState) var sharedUserState
            guard let user = sharedUserState.currentUser else { return }
            
            // Check if images need regeneration (they're nil after state reload)
            if sharedUserState.qrCodeImage == nil || sharedUserState.shareableQRCodeImage == nil {
                let qrImages = user.generateQRCodeImages()
                $sharedUserState.withLock { state in
                    if state.qrCodeImage == nil {
                        state.qrCodeImage = qrImages.qrImage
                    }
                    if state.shareableQRCodeImage == nil {
                        state.shareableQRCodeImage = qrImages.shareableImage
                    }
                }
            }
        }
    )
}

extension DependencyValues {
    var userClient: UserClient {
        get { self[UserClient.self] }
        set { self[UserClient.self] = newValue }
    }
}

// MARK: - Helper Functions

private func extractUserIDFromAvatarURL(_ avatarURL: String) -> String? {
    // Extract user ID from mock URL format: "mock://avatar/{userID}"
    if avatarURL.hasPrefix("mock://avatar/") {
        return String(avatarURL.dropFirst("mock://avatar/".count))
    }
    return nil
}

// MARK: - Mock Data Extensions

extension User {
    /// Mock user data for testing
    static let mock = User(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "Test User",
        phoneNumber: "+1234567890",
        phoneRegion: "US",
        emergencyNote: "Test emergency note",
        checkInInterval: 115200, // 32 hours
        lastCheckedIn: Date().addingTimeInterval(-3600), // 1 hour ago
        notificationPreference: .thirtyMinutes,
        isEmergencyAlertEnabled: false,
        emergencyAlertTimestamp: nil,
        qrCodeId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        avatarURL: nil,
        lastModified: Date(),
        biometricAuthEnabled: false
    )
    
    /// Mock user with active emergency alert
    static let mockWithAlert = User(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "Test User",
        phoneNumber: "+1234567890",
        phoneRegion: "US",
        emergencyNote: "Test emergency note",
        checkInInterval: 115200, // 32 hours
        lastCheckedIn: Date().addingTimeInterval(-3600), // 1 hour ago
        notificationPreference: .thirtyMinutes,
        isEmergencyAlertEnabled: true,
        emergencyAlertTimestamp: Date().addingTimeInterval(-600), // 10 minutes ago
        qrCodeId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        avatarURL: nil,
        lastModified: Date(),
        biometricAuthEnabled: false
    )
    
    /// Mock user with overdue check-in
    static let mockOverdue = User(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "Test User",
        phoneNumber: "+1234567890",
        phoneRegion: "US",
        emergencyNote: "Test emergency note",
        checkInInterval: 115200, // 32 hours
        lastCheckedIn: Date().addingTimeInterval(-86400), // 24 hours ago (overdue)
        notificationPreference: .thirtyMinutes,
        isEmergencyAlertEnabled: false,
        emergencyAlertTimestamp: nil,
        qrCodeId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        avatarURL: nil,
        lastModified: Date(),
        biometricAuthEnabled: false
    )
    
    /// Create a mock user with specific characteristics for testing
    static func mockUser(
        id: UUID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: String = "Test User",
        phoneNumber: String = "+1234567890",
        phoneRegion: String = "US",
        emergencyNote: String = "Test emergency note",
        checkInInterval: TimeInterval = 115200,
        lastCheckedIn: Date? = nil,
        notificationPreference: NotificationPreference = .thirtyMinutes,
        isEmergencyAlertEnabled: Bool = false,
        emergencyAlertTimestamp: Date? = nil,
        qrCodeId: UUID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        avatarURL: String? = nil,
        biometricAuthEnabled: Bool = false
    ) -> User {
        User(
            id: id,
            name: name,
            phoneNumber: phoneNumber,
            phoneRegion: phoneRegion,
            emergencyNote: emergencyNote,
            checkInInterval: checkInInterval,
            lastCheckedIn: lastCheckedIn,
            notificationPreference: notificationPreference,
            isEmergencyAlertEnabled: isEmergencyAlertEnabled,
            emergencyAlertTimestamp: emergencyAlertTimestamp,
            qrCodeId: qrCodeId,
            avatarURL: avatarURL,
            lastModified: Date(),
            biometricAuthEnabled: biometricAuthEnabled
        )
    }
}