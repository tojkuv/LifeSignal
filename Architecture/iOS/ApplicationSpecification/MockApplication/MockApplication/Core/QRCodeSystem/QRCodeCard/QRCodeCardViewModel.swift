import Foundation
import SwiftUI
import UIKit

/// View model for QR code card functionality
class QRCodeCardViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// The name to display
    @Published var name: String

    /// The subtitle to display
    @Published var subtitle: String
    
    /// The footer text to display
    @Published var footer: String
    
    /// The QR code generator view model
    @Published var qrCodeViewModel: QRCodeViewModel
    
    // MARK: - Initialization
    
    /// Initialize with default values
    /// - Parameters:
    ///   - name: The name to display
    ///   - qrCodeId: The QR code ID
    ///   - footer: The footer text to display
    init(
        name: String = "First Last",
        subtitle: String = "LifeSignal contact",
        qrCodeId: String = "F3B6C150-9E23-4BFA-A13E-8A8B842BB4C5",
        footer: String = "Use LifeSignal's QR code scanner to add this contact"
    ) {
        self.name = name
        self.subtitle = subtitle
        self.footer = footer
        self.qrCodeViewModel = QRCodeViewModel(
            qrCodeId: qrCodeId,
            size: 200,
            branded: true
        )
    }
}
