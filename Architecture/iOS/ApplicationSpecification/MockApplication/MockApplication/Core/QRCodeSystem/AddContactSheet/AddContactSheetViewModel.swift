import Foundation
import SwiftUI

/// View model for adding contacts
class AddContactSheetViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Whether the sheet is presented
    @Published var isSheetPresented: Bool = false

    /// The contact to add
    @Published var contact: Contact = Contact.empty

    /// Whether the contact is being added
    @Published var isAddingContact: Bool = false

    /// The error message
    @Published var errorMessage: String?

    /// Whether to show the error alert
    @Published var showErrorAlert: Bool = false

    // MARK: - Initialization

    /// Initialize with default values
    /// - Parameters:
    ///   - qrCodeId: The QR code ID
    ///   - isSheetPresented: Whether the sheet is presented
    init(qrCodeId: String = "", isSheetPresented: Bool = false) {
        self.contact = Contact.empty
        self.contact.qrCodeId = qrCodeId
        self.isSheetPresented = isSheetPresented

        // If a QR code ID is provided, look up the user
        if !qrCodeId.isEmpty {
            lookupUserByQRCode()
        }
    }

    // MARK: - Methods

    /// Set whether the sheet is presented
    /// - Parameter isPresented: Whether the sheet is presented
    func setSheetPresented(_ isPresented: Bool) {
        isSheetPresented = isPresented
    }

    /// Update the QR code
    /// - Parameter qrCode: The new QR code
    func updateQRCode(_ qrCode: String) {
        contact.qrCodeId = qrCode
        lookupUserByQRCode()
    }

    /// Look up a user by QR code
    func lookupUserByQRCode() {
        // Simulate a network request
        isAddingContact = true

        // Simulate a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }

            // 80% chance of success for demo purposes
            if Double.random(in: 0...1) < 0.8 {
                // Success
                self.contact.name = "Alex Morgan"
                self.contact.phone = "555-123-4567"
                self.contact.note = "I frequently go hiking alone on weekends at Mount Ridge trails. If unresponsive, check the main trail parking lot for my blue Honda Civic (plate XYZ-123). I carry an emergency beacon in my red backpack. I have a peanut allergy and keep an EpiPen in my backpack."
            } else {
                // Failure
                self.errorMessage = "Failed to look up user by QR code"
                self.showErrorAlert = true
            }

            self.isAddingContact = false
        }
    }

    /// Update the name
    /// - Parameter name: The new name
    func updateName(_ name: String) {
        contact.name = name
    }

    /// Update the phone
    /// - Parameter phone: The new phone
    func updatePhone(_ phone: String) {
        contact.phone = phone
    }

    /// Update whether the contact is a responder
    /// - Parameter isResponder: Whether the contact is a responder
    func updateIsResponder(_ isResponder: Bool) {
        contact.isResponder = isResponder
    }

    /// Update whether the contact is a dependent
    /// - Parameter isDependent: Whether the contact is a dependent
    func updateIsDependent(_ isDependent: Bool) {
        contact.isDependent = isDependent
    }

    /// Add the contact
    /// - Parameter completion: The completion handler
    func addContact(completion: @escaping (Bool) -> Void) {
        // Validate the contact
        guard !contact.name.isEmpty else {
            errorMessage = "Please enter a name"
            showErrorAlert = true
            completion(false)
            return
        }

        // Simulate a network request
        isAddingContact = true

        // Simulate a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }

            // 90% chance of success for demo purposes
            if Double.random(in: 0...1) < 0.9 {
                // Success
                self.isAddingContact = false

                // Show a notification for adding a contact
                NotificationManager.shared.showContactAddedNotification(contactName: self.contact.name)

                completion(true)
            } else {
                // Failure
                self.errorMessage = "Failed to add contact"
                self.showErrorAlert = true
                self.isAddingContact = false
                completion(false)
            }
        }
    }

    /// Set the error
    /// - Parameter error: The error message
    func setError(_ error: String?) {
        errorMessage = error
        showErrorAlert = error != nil
    }

    /// Dismiss the sheet
    func dismiss() {
        isSheetPresented = false
    }
}

// Contact model is now imported from Core/Domain/Contacts
