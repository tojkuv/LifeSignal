import Foundation
import SwiftUI
import UIKit

/// View model for QR code sharing functionality
@MainActor
class QRCodeShareSheetViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Whether the share sheet is showing
    @Published var isShareSheetPresented: Bool = false

    /// Whether to show the refresh confirmation alert
    @Published var isRefreshAlertPresented: Bool = false

    /// The QR code ID
    @Published private(set) var qrCodeId: String = UUID().uuidString

    /// The QR code image
    @Published private(set) var qrCodeImage: UIImage?

    /// The dismiss action to be called when closing the sheet
    private var onDismiss: () -> Void = {}

    // MARK: - Initialization

    /// Initialize with default values
    init() {
        self.qrCodeImage = generateQRCodeImage()
    }

    // MARK: - Public Methods

    /// Set the dismiss callback
    /// - Parameter callback: The callback to call when dismissing the sheet
    func setOnDismiss(_ callback: @escaping () -> Void) {
        onDismiss = callback
    }

    /// Show the share sheet with the current QR code image
    func showShareSheet() {
        isShareSheetPresented = true
    }

    /// Show the refresh confirmation alert
    func showRefreshAlert() {
        isRefreshAlertPresented = true
    }

    /// Generate a new QR code ID and update the QR code image
    func regenerateQRCode() {
        qrCodeId = UUID().uuidString
        qrCodeImage = generateQRCodeImage()
    }

    /// Dismiss the sheet
    func dismiss() {
        onDismiss()
    }

    // MARK: - Private Methods

    /// Generate a QR code image using the current QR code ID
    /// - Returns: The generated QR code image
    private func generateQRCodeImage() -> UIImage? {
        return QRCodeImageGenerator.generateQRCode(
            from: qrCodeId,
            size: 250
        )
    }
}
