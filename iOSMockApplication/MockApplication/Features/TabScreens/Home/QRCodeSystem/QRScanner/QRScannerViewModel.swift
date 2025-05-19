import Foundation
import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

/// View model for QR code scanning functionality
class QRScannerViewModel: ObservableObject {
    // MARK: - Scanner Properties

    /// Whether the torch is on
    @Published var torchOn: Bool = false

    /// Whether the gallery picker is showing
    @Published var isShowingGallery: Bool = false

    /// Whether to show the manual QR code entry sheet
    @Published var isShowingManualEntry: Bool = false

    /// The manually entered QR code
    @Published var manualQRCode: String = ""

    /// Whether the camera failed to load
    @Published var cameraLoadFailed: Bool = false

    /// Whether to show the no QR code alert
    @Published var showNoQRCodeAlert: Bool = false

    /// Whether to show the invalid UUID alert
    @Published var showInvalidUUIDAlert: Bool = false

    /// Gallery assets for the carousel
    @Published var galleryAssets: [UIImage] = []

    /// Gallery thumbnails for the carousel
    @Published var galleryThumbnails: [UIImage] = []

    /// The scanned QR code
    @Published var scannedQRCode: String = ""

    /// Whether to show the add contact sheet
    @Published var showAddContactSheet: Bool = false

    // MARK: - Contact Properties

    /// The contact to add
    @Published var contact: Contact = Contact.empty

    /// The error message
    @Published var errorMessage: String?

    /// Whether to show the error alert
    @Published var showErrorAlert: Bool = false

    /// Callback for when scanning is complete and a contact is added
    private var onScanComplete: ((String) -> Void) = { _ in }

    // MARK: - Initialization

    init() {
        // Load gallery assets from the photo library
        loadGalleryAssets()
    }

    // MARK: - Scanner Methods

    /// Set the callback for when scanning is complete
    /// - Parameter callback: The callback to call when scanning is complete
    func setOnScanComplete(_ callback: @escaping (String) -> Void) {
        onScanComplete = callback
    }

    /// Toggle the torch
    func toggleTorch() {
        torchOn.toggle()
        HapticFeedback.triggerHaptic()
    }

    /// Initialize the camera
    func initializeCamera() {
        // Check camera permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Camera is authorized
            cameraLoadFailed = false
        case .notDetermined:
            // Request camera permission
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.cameraLoadFailed = !granted
                }
            }
        case .denied, .restricted, _:
            // Camera permission denied or other status
            cameraLoadFailed = true
        }
    }

    /// Generate a QR code
    /// - Returns: A random UUID string
    func generateQRCode() -> String {
        return UUID().uuidString
    }

    /// Handle a scanned QR code
    /// - Parameter qrCode: The scanned QR code
    func handleScannedQRCode(_ qrCode: String) {
        scannedQRCode = qrCode
        contact.qrCodeId = qrCode
        lookupUserByQRCode()
        showAddContactSheet = true
    }

    /// Set whether to show the scanner
    /// - Parameter show: Whether to show the scanner
    func setShowScanner(_ show: Bool) {
        if show {
            initializeCamera()
        }
    }

    /// Load gallery assets from the photo library
    func loadGalleryAssets() {
        // Request photo library access
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard let self = self else { return }

            if status == .authorized {
                // Access has been granted, fetch the most recent photos
                DispatchQueue.global(qos: .userInitiated).async {
                    // Create fetch options
                    let fetchOptions = PHFetchOptions()
                    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                    fetchOptions.fetchLimit = 20 // Limit to 20 most recent photos

                    // Fetch the assets
                    let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)

                    // Process the assets
                    var assets: [UIImage] = []
                    var thumbnails: [UIImage] = []

                    // Image request options
                    let imageRequestOptions = PHImageRequestOptions()
                    imageRequestOptions.isSynchronous = true
                    imageRequestOptions.deliveryMode = .highQualityFormat

                    // Thumbnail request options
                    let thumbnailRequestOptions = PHImageRequestOptions()
                    thumbnailRequestOptions.isSynchronous = true
                    thumbnailRequestOptions.deliveryMode = .fastFormat
                    thumbnailRequestOptions.resizeMode = .fast

                    // Process each asset
                    fetchResult.enumerateObjects { asset, index, _ in
                        // Request full image
                        PHImageManager.default().requestImage(
                            for: asset,
                            targetSize: PHImageManagerMaximumSize,
                            contentMode: .aspectFit,
                            options: imageRequestOptions
                        ) { image, _ in
                            if let image = image {
                                assets.append(image)
                            }
                        }

                        // Request thumbnail
                        PHImageManager.default().requestImage(
                            for: asset,
                            targetSize: CGSize(width: 100, height: 100),
                            contentMode: .aspectFill,
                            options: thumbnailRequestOptions
                        ) { image, _ in
                            if let image = image {
                                thumbnails.append(image)
                            }
                        }
                    }

                    // Update the UI on the main thread
                    DispatchQueue.main.async {
                        self.galleryAssets = assets
                        self.galleryThumbnails = thumbnails
                    }
                }
            } else {
                // Access denied, use mock images
                DispatchQueue.main.async {
                    self.generateMockGalleryImages()
                }
            }
        }
    }

    /// Generate mock gallery images as a fallback
    private func generateMockGalleryImages() {
        // Generate 10 mock images
        let mockImages = (0..<10).map { _ in createMockImage() }
        galleryAssets = mockImages
        galleryThumbnails = mockImages
    }

    /// Create a mock image
    /// - Returns: A mock image with random color
    private func createMockImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        return renderer.image { context in
            let randomColor = UIColor(
                red: .random(in: 0...1),
                green: .random(in: 0...1),
                blue: .random(in: 0...1),
                alpha: 1.0
            )
            randomColor.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
    }

    /// Process a selected gallery image
    /// - Parameter index: The index of the selected gallery image
    func processGalleryImage(at index: Int) {
        isShowingGallery = false

        // Simulate QR code detection with 90% success rate
        let randomChance = Double.random(in: 0...1)
        if randomChance < 0.9 {
            // QR code found - generate a UUID
            let qrCode = self.generateQRCode()
            self.handleScannedQRCode(qrCode)
        } else {
            // No QR code found
            self.showNoQRCodeAlert = true
        }
    }

    /// Process an image selected from the photo picker
    /// - Parameter image: The selected image
    func processSelectedImage(_ image: UIImage) {
        isShowingGallery = false

        // Simulate QR code detection with 90% success rate
        let randomChance = Double.random(in: 0...1)
        if randomChance < 0.9 {
            // QR code found - generate a UUID
            let qrCode = self.generateQRCode()
            self.handleScannedQRCode(qrCode)
        } else {
            // No QR code found
            self.showNoQRCodeAlert = true
        }
    }

    /// Validate if the QR code format is valid
    /// - Parameter qrCode: The QR code to validate
    /// - Returns: Whether the QR code format is valid
    func isValidQRCodeFormat(_ qrCode: String) -> Bool {
        // Validate that the QR code is a valid UUID
        return UUID(uuidString: qrCode) != nil
    }

    /// Handle paste button tapped in manual entry
    func handlePasteButtonTapped() {
        HapticFeedback.lightImpact()
        // Get text from clipboard
        let pasteboard = UIPasteboard.general
        if let pastedText = pasteboard.string {
            // Check if it's a valid UUID
            if UUID(uuidString: pastedText) != nil {
                manualQRCode = pastedText
            } else {
                // Show alert for invalid UUID
                showInvalidUUIDAlert = true
            }
        }
    }

    /// Submit manual QR code
    func submitManualQRCode() {
        if !manualQRCode.isEmpty && isValidQRCodeFormat(manualQRCode) {
            HapticFeedback.notificationFeedback(type: .success)
            handleScannedQRCode(manualQRCode)
            isShowingManualEntry = false
            manualQRCode = ""
        }
    }

    /// Cancel manual entry
    func cancelManualEntry() {
        HapticFeedback.triggerHaptic()
        isShowingManualEntry = false
        manualQRCode = ""
    }

    /// Dismiss the scanner
    func dismissScanner() {
        HapticFeedback.triggerHaptic()
        // Call the onScanComplete callback with an empty string to indicate cancellation
        onScanComplete("")
    }

    // MARK: - Contact Methods

    /// Look up a user by QR code
    func lookupUserByQRCode() {
        // Simulate a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
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
        }
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
    func addContact() {
        // Validate the contact
        guard !contact.name.isEmpty else {
            errorMessage = "Please enter a name"
            showErrorAlert = true
            return
        }

        // Simulate a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            // 90% chance of success for demo purposes
            if Double.random(in: 0...1) < 0.9 {
                // Success
                // Show a notification for adding a contact
                NotificationManager.shared.showContactAddedNotification(contactName: self.contact.name)

                // Call the onScanComplete callback
                self.onScanComplete(self.scannedQRCode)

                // Close the add contact sheet
                self.showAddContactSheet = false

                // Reset the contact
                self.resetContact()
            } else {
                // Failure
                self.errorMessage = "Failed to add contact"
                self.showErrorAlert = true
            }
        }
    }

    /// Reset the contact to empty
    private func resetContact() {
        contact = Contact.empty
    }

    /// Close the add contact sheet
    func closeAddContactSheet() {
        HapticFeedback.triggerHaptic()
        showAddContactSheet = false
        resetContact()
    }

    /// Dismiss the scanner with the contact
    func dismissWithContact() {
        onScanComplete(scannedQRCode)
    }
}
