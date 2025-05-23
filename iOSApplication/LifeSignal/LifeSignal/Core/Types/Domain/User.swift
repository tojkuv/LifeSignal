import Foundation
import UIKit

// MARK: - Domain Model

struct User: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let firebaseUID: String
    var name: String
    var phoneNumber: String
    var profileDescription: String
    var isNotificationsEnabled: Bool
    var avatarURL: String?
    var avatarImageData: Data?
    var lastModified: Date
    
    // MARK: - Legacy Properties (for migration)
    var qrCodeId: String
    var checkInInterval: TimeInterval
    var notify30MinBefore: Bool
    var notify2HoursBefore: Bool
    
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
        firebaseUID: String,
        name: String,
        phoneNumber: String,
        profileDescription: String = "",
        isNotificationsEnabled: Bool = true,
        avatarURL: String? = nil,
        avatarImageData: Data? = nil,
        lastModified: Date = Date(),
        qrCodeId: String = UUID().uuidString.uppercased(),
        checkInInterval: TimeInterval = 24 * 60 * 60,
        notify30MinBefore: Bool = false,
        notify2HoursBefore: Bool = true
    ) {
        self.id = id
        self.firebaseUID = firebaseUID
        self.name = name
        self.phoneNumber = phoneNumber
        self.profileDescription = profileDescription
        self.isNotificationsEnabled = isNotificationsEnabled
        self.avatarURL = avatarURL
        self.avatarImageData = avatarImageData
        self.lastModified = lastModified
        self.qrCodeId = qrCodeId
        self.checkInInterval = checkInInterval
        self.notify30MinBefore = notify30MinBefore
        self.notify2HoursBefore = notify2HoursBefore
    }
    
    // MARK: - Mutation Methods
    
    /// Update the user's avatar image
    func withAvatarImage(_ image: UIImage?) -> User {
        var updated = self
        if let image = image {
            updated.avatarImageData = image.jpegData(compressionQuality: 0.8)
        } else {
            updated.avatarImageData = nil
        }
        return updated
    }
    
    /// Update the user's name
    func withName(_ newName: String) -> User {
        var updated = self
        updated.name = newName
        return updated
    }
    
    /// Update the user's phone
    func withPhone(_ newPhone: String) -> User {
        var updated = self
        updated.phoneNumber = newPhone
        updated.lastModified = Date()
        return updated
    }
    
    /// Update the user's profile description
    func withProfileDescription(_ newDescription: String) -> User {
        var updated = self
        updated.profileDescription = newDescription
        return updated
    }
    
    /// Update the user's QR code ID
    func withNewQRCodeId() -> User {
        var updated = self
        updated.qrCodeId = UUID().uuidString.uppercased()
        return updated
    }
    
    /// Update the user's check-in interval
    func withCheckInInterval(_ interval: TimeInterval) -> User {
        var updated = self
        updated.checkInInterval = interval
        return updated
    }
    
    /// Update the user's notification settings
    func withNotificationSettings(
        enabled: Bool,
        notify30MinBefore: Bool,
        notify2HoursBefore: Bool
    ) -> User {
        var updated = self
        updated.isNotificationsEnabled = enabled
        updated.notify30MinBefore = notify30MinBefore
        updated.notify2HoursBefore = notify2HoursBefore
        updated.lastModified = Date()
        return updated
    }
}

// MARK: - UserDefaults Migration Support

extension User {
    /// Create a User from legacy UserDefaults data
    static func fromUserDefaults() -> User {
        let defaults = UserDefaults.standard
        
        let name = defaults.string(forKey: "userName") ?? "Sarah Johnson"
        let phone = defaults.string(forKey: "userPhone") ?? "+1 (555) 987-6543"
        let profileDescription = defaults.string(forKey: "userProfileDescription") ?? "I have type 1 diabetes. My insulin and supplies are in the refrigerator. Emergency contacts: Mom (555-111-2222), Roommate Jen (555-333-4444). Allergic to penicillin. My doctor is Dr. Martinez at City Medical Center (555-777-8888)."
        let avatarImageData = defaults.data(forKey: "userAvatarImage")
        let qrCodeId = defaults.string(forKey: "userQRCodeId") ?? UUID().uuidString.uppercased()
        let checkInInterval = defaults.object(forKey: "userCheckInInterval") as? TimeInterval ?? (24 * 60 * 60)
        let notificationsEnabled = defaults.object(forKey: "userNotificationsEnabled") != nil ? defaults.bool(forKey: "userNotificationsEnabled") : true
        let notify30MinBefore = defaults.bool(forKey: "userNotify30MinBefore")
        let notify2HoursBefore = defaults.object(forKey: "userNotify2HoursBefore") != nil ? defaults.bool(forKey: "userNotify2HoursBefore") : true
        
        return User(
            firebaseUID: "", // Will be set during authentication
            name: name,
            phoneNumber: phone,
            profileDescription: profileDescription,
            isNotificationsEnabled: notificationsEnabled,
            avatarImageData: avatarImageData,
            qrCodeId: qrCodeId,
            checkInInterval: checkInInterval,
            notify30MinBefore: notify30MinBefore,
            notify2HoursBefore: notify2HoursBefore
        )
    }
}