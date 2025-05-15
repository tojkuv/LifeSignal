import Foundation
import SwiftUI
import Combine

/// View model for the home screen
class HomeViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Whether the QR scanner is showing
    @Published var showQRScanner: Bool = false

    /// Whether the interval picker is showing
    @Published var showIntervalPicker: Bool = false

    /// Whether the instructions are showing
    @Published var showInstructions: Bool = false

    /// Whether the check-in confirmation is showing
    @Published var showCheckInConfirmation: Bool = false

    /// Whether the share sheet is showing
    @Published var showShareSheet: Bool = false

    /// The QR code image
    @Published var qrCodeImage: UIImage? = nil

    /// Whether the image is ready
    @Published var isImageReady: Bool = false

    /// Whether the image is being generated
    @Published var isGeneratingImage: Bool = false

    /// Whether the camera denied alert is showing
    @Published var showCameraDeniedAlert: Bool = false

    /// The new contact
    @Published var newContact: Contact? = nil

    /// The pending scanned code
    @Published var pendingScannedCode: String? = nil

    /// The share image
    @Published var shareImage: HomeShareImage? = nil

    /// Whether the contact added alert is showing
    @Published var showContactAddedAlert: Bool = false

    // MARK: - Private Properties

    /// The user view model
    private var userViewModel: UserViewModel?

    // MARK: - Initialization

    init() {
        // Initialize with default values
    }

    // MARK: - Methods

    /// Set the user view model
    /// - Parameter userViewModel: The user view model
    func setUserViewModel(_ userViewModel: UserViewModel) {
        self.userViewModel = userViewModel
    }

    /// Generate a QR code image
    /// - Parameter completion: The completion handler
    func generateQRCodeImage(completion: @escaping () -> Void = {}) {
        guard let userViewModel = userViewModel else { return }
        if isGeneratingImage { return }

        isImageReady = false
        isGeneratingImage = true
        let qrContent = userViewModel.qrCodeId
        let content = AnyView(
            QRCodeShareView(
                name: userViewModel.name,
                subtitle: "LifeSignal contact",
                qrCodeId: qrContent,
                footer: "Use LifeSignal's QR code scanner to add this contact"
            )
        )

        QRCodeViewModel.generateQRCodeImage(content: content) { [weak self] image in
            self?.qrCodeImage = image
            self?.isImageReady = true
            self?.isGeneratingImage = false
            completion()
        }
    }

    /// Share the QR code
    func shareQRCode() {
        if isImageReady, let image = qrCodeImage {
            shareImage = .qrCode(image)
        } else if !isGeneratingImage {
            generateQRCodeImage { [weak self] in
                if let image = self?.qrCodeImage {
                    self?.shareImage = .qrCode(image)
                }
            }
        }
    }

    /// Show the QR code sheet
    func showQRCodeSheet() {
        // In a real app, we would present this as a sheet
        // For now, we'll just use the existing share functionality
        shareQRCode()
    }

    /// Format an interval for display
    /// - Parameter interval: The interval in seconds
    /// - Returns: A formatted string representation of the interval
    func formatInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        let days = hours / 24

        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s")"
        } else {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
    }
}
