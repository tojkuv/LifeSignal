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
    @Published var shareImage: UIImage? = nil

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

    /// Prepare for sharing QR code
    /// - Parameter completion: The completion handler called when ready to show share sheet
    func prepareForSharing(completion: @escaping () -> Void = {}) {
        guard let userViewModel = userViewModel else { return }
        if isGeneratingImage { return }

        isGeneratingImage = true

        // Since QRCodeShareSheetViewModel is @MainActor, we need to run this on the main actor
        Task { @MainActor in
            // Create a QRCodeShareSheetViewModel with the user's information
            let shareSheetViewModel = QRCodeShareSheetViewModel(
                name: userViewModel.name,
                qrCodeId: userViewModel.qrCodeId,
                subtitle: "LifeSignal contact",
                footer: "Use LifeSignal's QR code scanner to add this contact"
            )

            // Generate the shareable image using the view model
            shareSheetViewModel.generateShareableImage { [weak self] image in
                // We're already on the main thread due to @MainActor
                self?.shareImage = image
                self?.isGeneratingImage = false
                completion()
            }
        }
    }

    /// Share the QR code
    func shareQRCode() {
        if let _ = shareImage {
            // Image already generated, just show the share sheet
            showShareSheet = true
        } else if !isGeneratingImage {
            // Need to generate the image first
            prepareForSharing { [weak self] in
                self?.showShareSheet = true
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
