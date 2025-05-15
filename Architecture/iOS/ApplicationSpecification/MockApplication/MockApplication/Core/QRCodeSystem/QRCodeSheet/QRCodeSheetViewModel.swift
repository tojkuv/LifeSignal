import Foundation
import SwiftUI
import UIKit

/// View model for QR code sheet functionality
class QRCodeSheetViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// The name to display
    @Published var name: String = ""
    
    /// The footer text to display
    @Published var footer: String = "Let others scan this code to add you as a contact."
    
    /// Whether the sheet is showing
    @Published var isShowing: Bool = false
    
    /// The QR code card view model
    @Published var qrCodeCardViewModel: QRCodeCardViewModel
    
    // MARK: - Initialization
    
    /// Initialize with default values
    /// - Parameters:
    ///   - name: The name to display
    ///   - qrCodeId: The QR code ID
    ///   - footer: The footer text to display
    ///   - isShowing: Whether the sheet is showing
    init(
        name: String = "",
        qrCodeId: String = "",
        footer: String = "Let others scan this code to add you as a contact.",
        isShowing: Bool = false
    ) {
        self.name = name
        self.footer = footer
        self.isShowing = isShowing
        self.qrCodeCardViewModel = QRCodeCardViewModel(
            name: name,
            qrCodeId: qrCodeId,
            footer: footer
        )
    }
    
    // MARK: - Methods
    
    /// Set whether the sheet is showing
    /// - Parameter isShowing: Whether the sheet is showing
    func setShowing(_ isShowing: Bool) {
        self.isShowing = isShowing
    }
    
    /// Share the QR code
    func shareQRCode() {
        // In a real app, this would share the QR code
        print("Sharing QR code for \(name)")
    }
    
    /// Dismiss the sheet
    func dismiss() {
        isShowing = false
    }
    
    /// Generate a shareable QR code
    /// - Returns: The QR code image
    func generateShareableQRCode() -> UIImage? {
        return QRCodeViewModel.generateBrandedQRCode(
            from: qrCodeCardViewModel.qrCodeViewModel.qrCodeId,
            size: 1024
        )
    }
}
