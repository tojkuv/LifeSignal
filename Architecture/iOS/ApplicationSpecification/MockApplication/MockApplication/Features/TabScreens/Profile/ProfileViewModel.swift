import Foundation
import SwiftUI
import Combine
import UserNotifications
import UIKit

/// View model for the profile screen
class ProfileViewModel: ObservableObject {
    // MARK: - Published Properties

    // User Profile Properties
    @Published var name: String = "Sarah Johnson"
    @Published var phone: String = "+1 (555) 987-6543"
    @Published var profileDescription: String = "I have type 1 diabetes. My insulin and supplies are in the refrigerator. Emergency contacts: Mom (555-111-2222), Roommate Jen (555-333-4444). Allergic to penicillin. My doctor is Dr. Martinez at City Medical Center (555-777-8888)."

    // Avatar Properties
    @Published var avatarImage: UIImage? = nil

    // Sheet Presentation States
    @Published var showEditDescriptionSheet: Bool = false
    @Published var showEditNameSheet: Bool = false
    @Published var showEditAvatarSheet: Bool = false
    @Published var showImagePicker: Bool = false
    @Published var showDeleteAvatarConfirmation: Bool = false
    @Published var showPhoneNumberChangeSheetView: Bool = false
    @Published var showSignOutConfirmation: Bool = false
    @Published var showCheckInConfirmation: Bool = false

    // Phone Number Change Properties
    @Published var editingPhone: String = ""
    @Published var editingPhoneRegion: String = "US"
    @Published var isCodeSent: Bool = false
    @Published var verificationCode: String = ""
    @Published var isPhoneNumberFieldFocused: Bool = false
    @Published var isVerificationCodeFieldFocused: Bool = false
    @Published var phoneErrorMessage: String? = nil

    // Editing States
    @Published var newDescription: String = ""
    @Published var newName: String = ""
    @Published var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary

    // Loading State
    @Published var isLoading: Bool = false

    // Focus States (for SwiftUI @FocusState binding)
    @Published var isNameFieldFocused: Bool = false
    @Published var isDescriptionFieldFocused: Bool = false

    // MARK: - Computed Properties

    /// Whether the user is using the default avatar
    var isUsingDefaultAvatar: Bool {
        return avatarImage == nil
    }

    /// Available phone regions
    let regions = [
        ("US", "+1"),
        ("CA", "+1"),
        ("UK", "+44"),
        ("AU", "+61")
    ]

    /// Computed property to check if the phone number is valid
    var isPhoneNumberValid: Bool {
        // Match login screen validation
        // Allow development testing numbers
        if editingPhone == "1234567890" || editingPhone == "0000000000" || editingPhone == "+11234567890" {
            return true
        }

        // Simple validation: at least 10 digits
        return editingPhone.filter { $0.isNumber }.count >= 10
    }

    /// Computed property to check if the verification code is valid
    var isVerificationCodeValid: Bool {
        // Remove any non-digit characters and check if we have 6 digits
        return verificationCode.filter { $0.isNumber }.count == 6
    }

    /// Get the phone number placeholder based on the selected region
    var phoneNumberPlaceholder: String {
        switch editingPhoneRegion {
        case "US", "CA":
            return "XXX-XXX-XXXX" // Format for US and Canada
        case "UK":
            return "XXXX-XXX-XXX" // Format for UK
        case "AU":
            return "XXXX-XXX-XXX" // Format for Australia
        default:
            return "XXX-XXX-XXXX" // Default format
        }
    }

    // MARK: - Initialization

    init() {
        // Load persisted data from UserDefaults
        loadPersistedData()
    }

    // MARK: - Methods

    /// Prepare to edit the description
    func prepareEditDescription() {
        newDescription = profileDescription
        showEditDescriptionSheet = true
        HapticFeedback.triggerHaptic()

        // Focus the text editor when the sheet appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isDescriptionFieldFocused = true
        }
    }

    /// Save the edited description
    func saveEditedDescription() {
        if newDescription != profileDescription &&
           !newDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            profileDescription = newDescription
            saveProfileDescription()
            HapticFeedback.notificationFeedback(type: .success)
        }
    }

    /// Cancel editing description
    func cancelEditDescription() {
        HapticFeedback.triggerHaptic()
        showEditDescriptionSheet = false
    }

    /// Prepare to edit the name
    func prepareEditName() {
        newName = name
        showEditNameSheet = true
        HapticFeedback.triggerHaptic()

        // Focus the name field when the sheet appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isNameFieldFocused = true
        }
    }

    /// Save the edited name
    func saveEditedName() {
        if newName != name &&
           !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = newName
            saveName()
            HapticFeedback.notificationFeedback(type: .success)
        }
    }

    /// Cancel editing name
    func cancelEditName() {
        HapticFeedback.triggerHaptic()
        showEditNameSheet = false
    }

    /// Show the avatar edit sheet
    func showAvatarEditor() {
        showEditAvatarSheet = true
        HapticFeedback.triggerHaptic()
    }

    /// Close the avatar edit sheet
    func closeAvatarEditor() {
        showEditAvatarSheet = false
    }

    /// Show image picker with specified source type
    func showImagePickerWithSourceType(_ sourceType: UIImagePickerController.SourceType) {
        imagePickerSourceType = sourceType
        showImagePicker = true
        showEditAvatarSheet = false
        HapticFeedback.triggerHaptic()
    }

    /// Set the user's avatar image
    /// - Parameter image: The new avatar image
    func setAvatarImage(_ image: UIImage) {
        self.avatarImage = image
        saveAvatarImage(image)
        HapticFeedback.notificationFeedback(type: .success)
    }

    /// Delete the user's avatar image
    func deleteAvatarImage() {
        self.avatarImage = nil
        removeAvatarImage()
        HapticFeedback.notificationFeedback(type: .success)
    }

    /// Show delete avatar confirmation
    func showDeleteAvatarConfirmationDialog() {
        showDeleteAvatarConfirmation = true
        HapticFeedback.triggerHaptic()
    }

    /// Show the phone number change view
    func showPhoneNumberChange() {
        // Reset phone number change state
        editingPhone = ""
        editingPhoneRegion = "US"
        isCodeSent = false
        verificationCode = ""
        phoneErrorMessage = nil

        HapticFeedback.triggerHaptic()
        showPhoneNumberChangeSheetView = true

        // Focus the phone number field when the view appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isPhoneNumberFieldFocused = true
        }
    }

    /// Cancel phone number change
    func cancelPhoneNumberChange() {
        HapticFeedback.triggerHaptic()
        showPhoneNumberChangeSheetView = false
        isCodeSent = false
    }

    /// Send verification code for phone number change
    func sendPhoneChangeVerificationCode() {
        // In a real app, this would send a verification code to the phone number
        isLoading = true

        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            self.isLoading = false
            self.isCodeSent = true
            HapticFeedback.notificationFeedback(type: .success)

            // Focus the verification code field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isVerificationCodeFieldFocused = true
            }
        }
    }

    /// Verify the phone number change
    func verifyPhoneChange() {
        // In a real app, this would verify the code with the server
        isLoading = true

        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            self.isLoading = false

            // Update the phone number if verification is successful
            if !self.editingPhone.isEmpty && self.verificationCode.count >= 4 {
                let formattedPhone = PhoneFormatter.formatPhoneNumber(self.editingPhone, region: self.editingPhoneRegion)
                self.handlePhoneNumberChanged(newPhone: formattedPhone, region: self.editingPhoneRegion)
                self.showPhoneNumberChangeSheetView = false
                self.isCodeSent = false
            }
        }
    }

    /// Handle phone number text change
    func handlePhoneNumberChange(newValue: String) {
        // Check for development testing number
        if newValue == "+11234567890" || newValue == "1234567890" || newValue == "0000000000" {
            // Allow the development testing number as is
            return
        }

        // Format the phone number based on the selected region
        let filtered = newValue.filter { $0.isNumber }

        switch editingPhoneRegion {
        case "US", "CA":
            // Format for US and Canada: XXX-XXX-XXXX
            formatUSPhoneNumber(filtered)
        case "UK":
            // Format for UK: XXXX-XXX-XXX
            formatUKPhoneNumber(filtered)
        case "AU":
            // Format for Australia: XXXX-XXX-XXX
            formatAUPhoneNumber(filtered)
        default:
            // Default format: XXX-XXX-XXXX
            formatUSPhoneNumber(filtered)
        }
    }

    /// Handle verification code text change
    func handleVerificationCodeChange(newValue: String) {
        // Format the verification code as XXX-XXX
        let filtered = newValue.filter { $0.isNumber }

        // Limit to 6 digits
        let limitedFiltered = String(filtered.prefix(6))

        // Format with hyphen
        if limitedFiltered.count > 3 {
            let firstPart = limitedFiltered.prefix(3)
            let secondPart = limitedFiltered.dropFirst(3)
            verificationCode = "\(firstPart)-\(secondPart)"
        } else if limitedFiltered != verificationCode {
            // Just use the filtered digits if 3 or fewer
            verificationCode = limitedFiltered
        }
    }

    /// Handle region selection change
    func handleRegionChange() {
        HapticFeedback.selectionFeedback()
    }

    /// Handle phone number change
    /// - Parameters:
    ///   - newPhone: The new phone number
    ///   - region: The phone region
    func handlePhoneNumberChanged(newPhone: String, region: String) {
        self.phone = newPhone
        savePhone()
        HapticFeedback.notificationFeedback(type: .success)
    }

    /// Show sign out confirmation
    func confirmSignOut() {
        showSignOutConfirmation = true
        HapticFeedback.triggerHaptic()
    }

    /// Sign out the user
    func signOut() {
        // In a real app, this would sign out the user from the server
        // For now, we'll just reset the user data
        resetUserData()
        HapticFeedback.notificationFeedback(type: .success)
    }

    /// Reset user data when signing out
    func resetUserData() {
        // Clear any user-specific data from UserDefaults
        UserDefaults.standard.removeObject(forKey: "userName")
        UserDefaults.standard.removeObject(forKey: "userPhone")
        UserDefaults.standard.removeObject(forKey: "userProfileDescription")
        UserDefaults.standard.removeObject(forKey: "userAvatarImage")

        // Reset in-memory state
        name = "Sarah Johnson"
        phone = "+1 (555) 987-6543"
        profileDescription = "I have type 1 diabetes. My insulin and supplies are in the refrigerator. Emergency contacts: Mom (555-111-2222), Roommate Jen (555-333-4444). Allergic to penicillin. My doctor is Dr. Martinez at City Medical Center (555-777-8888)."
        avatarImage = nil
    }

    // MARK: - Private Methods

    /// Load persisted data from UserDefaults
    private func loadPersistedData() {
        // Load user name
        if let userName = UserDefaults.standard.string(forKey: "userName") {
            self.name = userName
        }

        // Load user phone
        if let userPhone = UserDefaults.standard.string(forKey: "userPhone") {
            self.phone = userPhone
        }

        // Load profile description
        if let profileDescription = UserDefaults.standard.string(forKey: "userProfileDescription") {
            self.profileDescription = profileDescription
        }

        // Load avatar image if available
        loadAvatarImage()
    }

    /// Save the user name to UserDefaults
    private func saveName() {
        UserDefaults.standard.set(name, forKey: "userName")
    }

    /// Save the user phone to UserDefaults
    private func savePhone() {
        UserDefaults.standard.set(phone, forKey: "userPhone")
    }

    /// Save the profile description to UserDefaults
    private func saveProfileDescription() {
        UserDefaults.standard.set(profileDescription, forKey: "userProfileDescription")
    }

    /// Save the avatar image to UserDefaults
    /// - Parameter image: The image to save
    private func saveAvatarImage(_ image: UIImage) {
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            UserDefaults.standard.set(imageData, forKey: "userAvatarImage")
        }
    }

    /// Load the avatar image from UserDefaults
    private func loadAvatarImage() {
        if let imageData = UserDefaults.standard.data(forKey: "userAvatarImage") {
            self.avatarImage = UIImage(data: imageData)
        }
    }

    /// Remove the avatar image from UserDefaults
    private func removeAvatarImage() {
        UserDefaults.standard.removeObject(forKey: "userAvatarImage")
    }

    /// Format a US/Canada phone number (XXX-XXX-XXXX)
    private func formatUSPhoneNumber(_ filtered: String) {
        // Limit to 10 digits
        let limitedFiltered = String(filtered.prefix(10))

        // Format with hyphens
        if limitedFiltered.count > 6 {
            let areaCode = limitedFiltered.prefix(3)
            let prefix = limitedFiltered.dropFirst(3).prefix(3)
            let lineNumber = limitedFiltered.dropFirst(6)
            editingPhone = "\(areaCode)-\(prefix)-\(lineNumber)"
        } else if limitedFiltered.count > 3 {
            let areaCode = limitedFiltered.prefix(3)
            let prefix = limitedFiltered.dropFirst(3)
            editingPhone = "\(areaCode)-\(prefix)"
        } else if limitedFiltered.count > 0 {
            editingPhone = limitedFiltered
        } else {
            editingPhone = ""
        }
    }

    /// Format a UK phone number (XXXX-XXX-XXX)
    private func formatUKPhoneNumber(_ filtered: String) {
        // Limit to 10 digits
        let limitedFiltered = String(filtered.prefix(10))

        // Format with hyphens
        if limitedFiltered.count > 7 {
            let areaCode = limitedFiltered.prefix(4)
            let prefix = limitedFiltered.dropFirst(4).prefix(3)
            let lineNumber = limitedFiltered.dropFirst(7)
            editingPhone = "\(areaCode)-\(prefix)-\(lineNumber)"
        } else if limitedFiltered.count > 4 {
            let areaCode = limitedFiltered.prefix(4)
            let prefix = limitedFiltered.dropFirst(4)
            editingPhone = "\(areaCode)-\(prefix)"
        } else if limitedFiltered.count > 0 {
            editingPhone = limitedFiltered
        } else {
            editingPhone = ""
        }
    }

    /// Format an Australian phone number (XXXX-XXX-XXX)
    private func formatAUPhoneNumber(_ filtered: String) {
        // Limit to 10 digits
        let limitedFiltered = String(filtered.prefix(10))

        // Format with hyphens
        if limitedFiltered.count > 7 {
            let areaCode = limitedFiltered.prefix(4)
            let prefix = limitedFiltered.dropFirst(4).prefix(3)
            let lineNumber = limitedFiltered.dropFirst(7)
            editingPhone = "\(areaCode)-\(prefix)-\(lineNumber)"
        } else if limitedFiltered.count > 4 {
            let areaCode = limitedFiltered.prefix(4)
            let prefix = limitedFiltered.dropFirst(4)
            editingPhone = "\(areaCode)-\(prefix)"
        } else if limitedFiltered.count > 0 {
            editingPhone = limitedFiltered
        } else {
            editingPhone = ""
        }
    }
}
