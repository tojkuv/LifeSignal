import Foundation
import SwiftUI
import Combine
import UIKit

/// View model for the home screen
class HomeViewModel: ObservableObject {
    // MARK: - Published Properties

    // User Properties
    @Published var userName: String = "Sarah Johnson"

    // QR Code Properties
    @Published var qrCodeId: String = UUID().uuidString.uppercased()
    @Published var qrCodeImage: UIImage? = nil
    @Published var isQRCodeReady: Bool = false
    @Published var isGeneratingQRCode: Bool = false
    @Published var shareableImage: UIImage? = nil

    // Check-in Properties
    @Published var checkInInterval: TimeInterval = 24 * 60 * 60 // Default: 1 day

    // Notification Properties
    @Published var notificationsEnabled: Bool = true
    @Published var notify30MinBefore: Bool = false
    @Published var notify2HoursBefore: Bool = true

    // UI State Properties
    @Published var showQRScanner: Bool = false
    @Published var showIntervalPicker: Bool = false
    @Published var showInstructions: Bool = false
    @Published var showShareSheet: Bool = false
    @Published var showCameraDeniedAlert: Bool = false
    @Published var showContactAddedAlert: Bool = false
    @Published var showResetQRConfirmation: Bool = false
    @Published var showIntervalChangeConfirmation: Bool = false

    // Interval Picker Properties
    @Published var intervalPickerUnit: String = "days"
    @Published var intervalPickerValue: Int = 1
    @Published var pendingIntervalChange: TimeInterval? = nil

    // Contact Properties
    @Published var pendingScannedCode: String? = nil
    @Published var newContact: Contact? = nil



    // MARK: - Initialization

    init() {
        // Load persisted data
        loadPersistedData()

        // Generate QR code on initialization
        generateQRCode()
    }

    // MARK: - QR Code Methods

    /// Generate a new QR code
    func generateQRCode() {
        isQRCodeReady = false
        isGeneratingQRCode = true

        // Generate QR code image
        if let image = QRCodeImageGenerator.generateQRCode(from: qrCodeId, size: 300) {
            qrCodeImage = image
            isQRCodeReady = true
        }

        isGeneratingQRCode = false
    }

    /// Reset QR code with a new ID
    func resetQRCode() {
        // Generate a new UUID
        qrCodeId = UUID().uuidString.uppercased()

        // Save to UserDefaults
        UserDefaults.standard.set(qrCodeId, forKey: "userQRCodeId")

        // Generate new QR code image
        generateQRCode()

        // Clear shareable image
        shareableImage = nil

        // Show notification
        NotificationManager.shared.showQRCodeResetNotification()
    }

    /// Generate a shareable QR code image
    /// - Parameter completion: Called when the image is ready
    func generateShareableQRCode(completion: @escaping () -> Void = {}) {
        if isGeneratingQRCode { return }

        isGeneratingQRCode = true

        // Create a shareable image with the QR code and user info
        Task { @MainActor in
            // Create a view to render
            let qrSize: CGFloat = 250
            let padding: CGFloat = 40
            let width = qrSize + (padding * 2)
            let height = qrSize + (padding * 2) + 60 // Extra space for text

            let renderer = ImageRenderer(content:
                VStack(spacing: 20) {
                    if let qrImage = self.qrCodeImage {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: qrSize, height: qrSize)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Text("LifeSignal QR Code")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .frame(width: width, height: height)
                .padding()
                .background(Color.blue.opacity(0.1))
            )

            // Set the size
            renderer.proposedSize = ProposedViewSize(width: width, height: height)

            // Render the image
            if let uiImage = renderer.uiImage {
                self.shareableImage = uiImage
                self.isGeneratingQRCode = false
                completion()
            } else {
                // Fallback to just the QR code if rendering fails
                self.shareableImage = self.qrCodeImage
                self.isGeneratingQRCode = false
                completion()
            }
        }
    }

    /// Share the QR code
    func shareQRCode() {
        if let _ = shareableImage {
            // Image already generated, just show the share sheet
            showShareSheet = true
        } else {
            // Generate the image first
            generateShareableQRCode { [weak self] in
                self?.showShareSheet = true
            }
        }
    }

    /// Update the check-in interval
    /// - Parameter interval: The new interval in seconds
    func updateCheckInInterval(_ interval: TimeInterval) {
        checkInInterval = interval

        // Save to UserDefaults
        UserDefaults.standard.set(checkInInterval, forKey: "userCheckInInterval")
    }

    // MARK: - Interval Picker Methods

    /// Initialize the interval picker with the current interval
    func initializeIntervalPicker() {
        if checkInInterval.truncatingRemainder(dividingBy: 86400) == 0,
           (1...7).contains(Int(checkInInterval / 86400)) {
            intervalPickerUnit = "days"
            intervalPickerValue = Int(checkInInterval / 86400)
        } else if checkInInterval.truncatingRemainder(dividingBy: 3600) == 0,
                  hourValues.contains(Int(checkInInterval / 3600)) {
            intervalPickerUnit = "hours"
            intervalPickerValue = Int(checkInInterval / 3600)
        } else {
            // Default to 1 day
            intervalPickerUnit = "days"
            intervalPickerValue = 1
        }
    }

    /// Update the interval picker unit
    /// - Parameter newUnit: The new unit ("days" or "hours")
    func updateIntervalPickerUnit(_ newUnit: String) {
        intervalPickerUnit = newUnit

        // Set default values based on unit
        if newUnit == "days" {
            intervalPickerValue = 1
        } else {
            intervalPickerValue = 8
        }

        // Provide haptic feedback
        HapticFeedback.selectionFeedback()
    }

    /// Get the computed interval in seconds from picker values
    /// - Returns: The interval in seconds
    func getComputedIntervalInSeconds() -> TimeInterval {
        if intervalPickerUnit == "days" {
            return TimeInterval(intervalPickerValue * 86400)
        } else {
            return TimeInterval(intervalPickerValue * 3600)
        }
    }

    /// Format an interval for display
    /// - Parameter interval: The interval in seconds
    /// - Returns: A formatted string
    func formatInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)

        // Special case for our specific hour values
        if hourValues.contains(hours) {
            return "\(hours) hours"
        }

        // For other values, use standard formatting
        let days = hours / 24
        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s")"
        } else {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
    }

    /// Available day values for the interval picker
    var dayValues: [Int] { Array(1...7) }

    /// Available hour values for the interval picker
    var hourValues: [Int] { [8, 16, 32] }

    /// Check if the current unit is days
    var isDayUnit: Bool { intervalPickerUnit == "days" }

    // MARK: - Notification Methods

    /// Update notification settings
    /// - Parameters:
    ///   - enabled: Whether notifications are enabled
    ///   - notify30Min: Whether to notify 30 minutes before expiration
    ///   - notify2Hours: Whether to notify 2 hours before expiration
    func updateNotificationSettings(enabled: Bool, notify30Min: Bool, notify2Hours: Bool) {
        notificationsEnabled = enabled
        notify30MinBefore = notify30Min
        notify2HoursBefore = notify2Hours

        // Save to UserDefaults
        UserDefaults.standard.set(notificationsEnabled, forKey: "userNotificationsEnabled")
        UserDefaults.standard.set(notify30MinBefore, forKey: "userNotify30MinBefore")
        UserDefaults.standard.set(notify2HoursBefore, forKey: "userNotify2HoursBefore")

        // Show a notification that settings were updated
        NotificationManager.shared.showNotificationSettingsUpdatedNotification()
    }

    // MARK: - Contact Methods

    /// Create a new contact from a scanned QR code
    /// - Parameter qrCodeId: The scanned QR code ID
    /// - Returns: A new contact
    func createContactFromQRCode(_ qrCodeId: String) -> Contact {
        return Contact(
            id: UUID().uuidString,
            name: "New Contact",
            phone: "",
            qrCodeId: qrCodeId,
            lastCheckIn: Date(),
            note: "",
            manualAlertActive: false,
            isNonResponsive: false,
            hasIncomingPing: false,
            incomingPingTimestamp: nil,
            isResponder: true,
            isDependent: false,
            hasOutgoingPing: false,
            outgoingPingTimestamp: nil,
            checkInInterval: 24 * 60 * 60,
            manualAlertTimestamp: nil
        )
    }

    // MARK: - Data Persistence

    /// Load persisted data from UserDefaults
    private func loadPersistedData() {
        // Load QR code ID
        if let savedQRCodeId = UserDefaults.standard.string(forKey: "userQRCodeId") {
            qrCodeId = savedQRCodeId
        }

        // Load check-in interval
        if let savedCheckInInterval = UserDefaults.standard.object(forKey: "userCheckInInterval") as? TimeInterval {
            checkInInterval = savedCheckInInterval
        }

        // Load notification settings
        notificationsEnabled = UserDefaults.standard.bool(forKey: "userNotificationsEnabled")
        notify30MinBefore = UserDefaults.standard.bool(forKey: "userNotify30MinBefore")
        notify2HoursBefore = UserDefaults.standard.bool(forKey: "userNotify2HoursBefore")

        // Load user name
        if let savedName = UserDefaults.standard.string(forKey: "userName") {
            userName = savedName
        }

        // Initialize interval picker values
        initializeIntervalPicker()
    }
}
