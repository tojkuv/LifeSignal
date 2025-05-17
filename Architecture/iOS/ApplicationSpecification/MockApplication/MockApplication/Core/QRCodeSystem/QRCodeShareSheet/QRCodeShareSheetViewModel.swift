import Foundation
import SwiftUI
import UIKit

/// View model for QR code share sheet functionality
class QRCodeShareSheetViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The name to display
    @Published var name: String = ""

    /// Whether the share sheet is showing
    @Published var isShowingShareSheet: Bool = false

    /// The QR code generator view model
    @Published var qrCodeViewModel: QRCodeViewModel

    // MARK: - Initialization

    /// Initialize with default values
    /// - Parameters:
    ///   - name: The name to display
    ///   - qrCodeId: The QR code ID
    ///   - isShowingShareSheet: Whether the share sheet is showing
    init(
        name: String = "",
        qrCodeId: String = "",
        isShowingShareSheet: Bool = false
    ) {
        self.name = name
        self.isShowingShareSheet = isShowingShareSheet
        self.qrCodeViewModel = QRCodeViewModel(
            qrCodeId: qrCodeId,
            size: 1024,
            branded: true
        )

        // Force generate QR code image immediately
        // Use a sync call to ensure the image is generated before the view appears
        self.qrCodeViewModel.generateQRCodeImage()

        // Also schedule an async call as a backup
        DispatchQueue.main.async {
            self.qrCodeViewModel.generateQRCodeImage()
        }
    }

    // MARK: - Methods

    /// Set whether the share sheet is showing
    /// - Parameter isShowing: Whether the share sheet is showing
    func setShowingShareSheet(_ isShowing: Bool) {
        isShowingShareSheet = isShowing
    }

    /// Share the QR code
    func shareQRCode() {
        // In a real app, this would share the QR code
        print("Sharing QR code for \(name)")
    }

    /// Dismiss the sheet
    func dismiss() {
        // In a real app, this would dismiss the sheet
    }
}
