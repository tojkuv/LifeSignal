import Foundation
import SwiftUI
import UIKit

/// View model for QR code card functionality
class QRCodeCardViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// The name to display
    @Published var name: String = ""
    
    /// The footer text to display
    @Published var footer: String = ""
    
    /// The QR code generator view model
    @Published var qrCodeViewModel: QRCodeViewModel
    
    // MARK: - Initialization
    
    /// Initialize with default values
    /// - Parameters:
    ///   - name: The name to display
    ///   - qrCodeId: The QR code ID
    ///   - footer: The footer text to display
    init(
        name: String = "",
        qrCodeId: String = "",
        footer: String = ""
    ) {
        self.name = name
        self.footer = footer
        self.qrCodeViewModel = QRCodeViewModel(
            qrCodeId: qrCodeId,
            size: 200,
            branded: true
        )
    }
}
