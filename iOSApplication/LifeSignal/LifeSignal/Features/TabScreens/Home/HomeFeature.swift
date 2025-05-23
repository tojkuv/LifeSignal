import ComposableArchitecture
import Foundation
import UIKit
import Sharing
import SwiftUI

/// Home Feature - QR code generation and settings management using TCA
@Reducer
struct HomeFeature {
    /// Home state conforming to TCA patterns
    @ObservableState
    struct State: Equatable {
        // User Data
        @Shared(.currentUser) var currentUser: User? = nil

        // QR Code Properties
        var qrCodeImage: UIImage? = nil
        var isQRCodeReady: Bool = false
        var isGeneratingQRCode: Bool = false
        var shareableImage: UIImage? = nil

        // UI State Properties
        @Presents var qrScanner: QRScannerFeature.State?
        var showIntervalPicker: Bool = false
        var showInstructions: Bool = false
        @Presents var qrShareSheet: QRCodeShareSheetFeature.State?
        var showCameraDeniedAlert: Bool = false
        var showContactAddedAlert: Bool = false
        var showResetQRConfirmation: Bool = false
        var showIntervalChangeConfirmation: Bool = false
        var showShareSheet: Bool = false

        // Interval Picker Properties
        var intervalPickerUnit: String = "days"
        var intervalPickerValue: Int = 1
        var pendingIntervalChange: TimeInterval? = nil

        // Contact Properties
        var pendingScannedCode: String? = nil
        var newContact: Contact? = nil

        /// Available day values for the interval picker
        var dayValues: [Int] { Array(1...7) }

        /// Available hour values for the interval picker
        var hourValues: [Int] { [8, 16, 32] }

        /// Check if the current unit is days
        var isDayUnit: Bool { intervalPickerUnit == "days" }

        /// Initialize with default values and load persisted data
        init() {
            // Default initialization - actual data loading will be handled in effects
        }
    }

    /// Home actions representing events that can occur
    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        // Lifecycle actions
        case onAppear
        case loadUser
        case userLoaded(User)

        // QR Code actions
        case generateQRCode
        case qrCodeGenerated(UIImage?)
        case resetQRCode
        case generateShareableQRCode
        case shareableQRCodeGenerated(UIImage?)
        case shareQRCode
        case showQRScanner
        case hideQRScanner
        case showQRShareSheet
        case hideQRShareSheet

        // Check-in interval actions
        case updateCheckInInterval(TimeInterval)
        case initializeIntervalPicker
        case updateIntervalPickerUnit(String)
        case updateIntervalPickerValue(Int)
        case confirmIntervalChange
        case cancelIntervalChange

        // Notification actions
        case updateNotificationSettings(enabled: Bool, notify30Min: Bool, notify2Hours: Bool)

        // UI State actions
        case qrScanner(PresentationAction<QRScannerFeature.Action>)
        case setShowIntervalPicker(Bool)
        case setShowInstructions(Bool)
        case qrShareSheet(PresentationAction<QRCodeShareSheetFeature.Action>)
        case setShowCameraDeniedAlert(Bool)
        case setShowContactAddedAlert(Bool)
        case setShowResetQRConfirmation(Bool)
        case setShowIntervalChangeConfirmation(Bool)
        case setShowShareSheet(Bool)

        // Contact actions
        case createContactFromQRCode(String)
        case contactCreated(Contact)
        case setPendingScannedCode(String?)
        case copyQRCodeId

        // Internal actions
        case _qrCodeGenerationStarted
        case _qrCodeGenerationCompleted
        case _shareableQRCodeGenerationStarted
        case _shareableQRCodeGenerationCompleted
    }

    /// Dependencies for the Home feature
    @Dependency(\.userRepository) var userRepository
    @Dependency(\.qrCodeGenerator) var qrCodeGenerator
    @Dependency(\.notificationRepository) var notificationRepository
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.analytics) var analytics
    @Dependency(\.loggingClient) var logging

    /// Home reducer body implementing business logic
    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .onAppear:
                return .send(.loadUser)

            case .loadUser:
                return .run { send in
                    if let user = await userRepository.getCurrentUser() {
                        await send(.userLoaded(user))
                    } else if let legacyUser = await userRepository.loadUser() {
                        // Handle legacy user migration
                        await send(.userLoaded(legacyUser))
                    }
                }

            case let .userLoaded(user):
                state.currentUser = user
                return .merge(
                    .send(.initializeIntervalPicker),
                    .send(.generateQRCode)
                )

            case .generateQRCode:
                state.isQRCodeReady = false
                return .run { [qrCodeId = state.currentUser?.qrCodeId ?? ""] send in
                    await send(._qrCodeGenerationStarted)
                    let image = await qrCodeGenerator.generateQRCode(qrCodeId, 300)
                    await send(.qrCodeGenerated(image))
                }

            case ._qrCodeGenerationStarted:
                state.isGeneratingQRCode = true
                return .none

            case let .qrCodeGenerated(image):
                state.qrCodeImage = image
                state.isQRCodeReady = image != nil
                state.isGeneratingQRCode = false
                return .none

            case .resetQRCode:
                if var user = state.currentUser {
                    user = user.withNewQRCodeId()
                    state.currentUser = user
                }
                state.shareableImage = nil

                return .run { [user = state.currentUser] send in
                    if let user = user {
                        _ = try? await userRepository.updateProfile(user)
                        await notificationRepository.sendLocalNotification(
                            .system,
                            "QR Code Reset",
                            "Your QR code has been reset. Previous QR codes are no longer valid."
                        )
                        await analytics.track(.featureUsed(feature: "qr_code_reset", context: [:]))
                        await send(.generateQRCode)
                    }
                }

            case .generateShareableQRCode:
                guard !state.isGeneratingQRCode else { return .none }

                return .run { [qrCodeImage = state.qrCodeImage, userName = state.currentUser?.name ?? ""] send in
                    await send(._shareableQRCodeGenerationStarted)
                    let shareableImage = await qrCodeGenerator.generateShareableQRCode(qrCodeImage, userName)
                    await send(.shareableQRCodeGenerated(shareableImage))
                }

            case ._shareableQRCodeGenerationStarted:
                state.isGeneratingQRCode = true
                return .none

            case let .shareableQRCodeGenerated(image):
                state.shareableImage = image
                state.isGeneratingQRCode = false
                return .none

            case .shareQRCode:
                if state.shareableImage != nil {
                    return .send(.showQRShareSheet)
                } else {
                    return .merge(
                        .send(.generateShareableQRCode),
                        .run { send in
                            // Wait for generation to complete, then show share sheet
                            try await Task.sleep(for: .milliseconds(100))
                            await send(.showQRShareSheet)
                        }
                    )
                }

            case let .updateCheckInInterval(interval):
                if var user = state.currentUser {
                    user = user.withCheckInInterval(interval)
                    state.currentUser = user
                }

                return .run { [user = state.currentUser] send in
                    if let user = user {
                        _ = try? await userRepository.updateProfile(user)
                        await analytics.track(.featureUsed(feature: "check_in_interval_update", context: ["interval": "\(interval)"]))
                        await send(.initializeIntervalPicker)
                    }
                }

            case .initializeIntervalPicker:
                let interval = state.currentUser?.checkInInterval ?? 86400
                if interval.truncatingRemainder(dividingBy: 86400) == 0,
                   (1...7).contains(Int(interval / 86400)) {
                    state.intervalPickerUnit = "days"
                    state.intervalPickerValue = Int(interval / 86400)
                } else if interval.truncatingRemainder(dividingBy: 3600) == 0,
                          state.hourValues.contains(Int(interval / 3600)) {
                    state.intervalPickerUnit = "hours"
                    state.intervalPickerValue = Int(interval / 3600)
                } else {
                    // Default to 1 day
                    state.intervalPickerUnit = "days"
                    state.intervalPickerValue = 1
                }
                return .none

            case let .updateIntervalPickerUnit(newUnit):
                state.intervalPickerUnit = newUnit

                // Set default values based on unit
                if newUnit == "days" {
                    state.intervalPickerValue = 1
                } else {
                    state.intervalPickerValue = 8
                }

                return .run { send in
                    await haptics.selection()
                }

            case let .updateIntervalPickerValue(value):
                state.intervalPickerValue = value
                return .none

            case .confirmIntervalChange:
                let newInterval: TimeInterval
                if state.intervalPickerUnit == "days" {
                    newInterval = TimeInterval(state.intervalPickerValue * 86400)
                } else {
                    newInterval = TimeInterval(state.intervalPickerValue * 3600)
                }
                state.pendingIntervalChange = newInterval
                state.showIntervalChangeConfirmation = true
                return .none

            case .cancelIntervalChange:
                state.pendingIntervalChange = nil
                state.showIntervalChangeConfirmation = false
                state.showIntervalPicker = false
                return .send(.initializeIntervalPicker)

            case let .updateNotificationSettings(enabled, notify30Min, notify2Hours):
                if var user = state.currentUser {
                    user = user.withNotificationSettings(
                        enabled: enabled,
                        notify30MinBefore: notify30Min,
                        notify2HoursBefore: notify2Hours
                    )
                    state.currentUser = user
                }

                return .run { [user = state.currentUser] send in
                    if let user = user {
                        _ = try? await userRepository.updateProfile(user)
                        await notificationRepository.sendLocalNotification(
                            .system,
                            "Notification Settings Updated",
                            "Your notification settings have been successfully updated."
                        )
                        await analytics.track(.featureUsed(feature: "notification_settings", context: [
                            "enabled": "\(enabled)",
                            "notify_30min": "\(notify30Min)",
                            "notify_2hours": "\(notify2Hours)"
                        ]))
                    }
                }

            // UI State actions
            case .showQRScanner:
                state.qrScanner = QRScannerFeature.State()
                return .none

            case .hideQRScanner:
                state.qrScanner = nil
                return .none

            case .showQRShareSheet:
                if let qrImage = state.qrCodeImage, let user = state.currentUser {
                    state.qrShareSheet = QRCodeShareSheetFeature.State(
                        qrCodeId: user.qrCodeId,
                        qrCodeImage: qrImage
                    )
                }
                return .none

            case .hideQRShareSheet:
                state.qrShareSheet = nil
                return .none

            case .qrScanner(.dismiss):
                state.qrScanner = nil
                return .none

            case .qrShareSheet(.dismiss):
                state.qrShareSheet = nil
                return .none

            case .qrScanner, .qrShareSheet:
                return .none

            case let .setShowIntervalPicker(show):
                state.showIntervalPicker = show
                return .run { send in
                    await haptics.impact(.medium)
                }

            case let .setShowInstructions(show):
                state.showInstructions = show
                return .run { send in
                    await haptics.impact(.medium)
                }

            case let .setShowShareSheet(show):
                state.showShareSheet = show
                return .none

            case let .setShowCameraDeniedAlert(show):
                state.showCameraDeniedAlert = show
                return .none

            case let .setShowContactAddedAlert(show):
                state.showContactAddedAlert = show
                return .none

            case let .setShowResetQRConfirmation(show):
                state.showResetQRConfirmation = show
                return .run { send in
                    await haptics.impact(.medium)
                }

            case let .setShowIntervalChangeConfirmation(show):
                state.showIntervalChangeConfirmation = show
                if !show {
                    state.pendingIntervalChange = nil
                }
                return .none

            case let .createContactFromQRCode(qrCodeId):
                let contact = Contact(
                    id: UUID(),
                    userID: UUID(),
                    name: "New Contact",
                    phoneNumber: "",
                    relationship: .responder,
                    status: .active,
                    lastUpdated: Date(),
                    qrCodeId: qrCodeId,
                    lastCheckIn: Date(),
                    note: "",
                    manualAlertActive: false,
                    isNonResponsive: false,
                    hasIncomingPing: false,
                    incomingPingTimestamp: nil,
                    hasOutgoingPing: false,
                    outgoingPingTimestamp: nil,
                    checkInInterval: 24 * 60 * 60,
                    manualAlertTimestamp: nil
                )
                return .send(.contactCreated(contact))

            case let .contactCreated(contact):
                state.newContact = contact
                state.showContactAddedAlert = true
                return .none

            case let .setPendingScannedCode(code):
                state.pendingScannedCode = code
                return .none

            case .copyQRCodeId:
                return .run { [qrCodeId = state.currentUser?.qrCodeId ?? ""] send in
                    UIPasteboard.general.string = qrCodeId
                    await haptics.notification(.success)
                    await notificationRepository.sendLocalNotification(
                        .system,
                        "QR Code ID Copied",
                        "Your QR code ID has been copied to the clipboard."
                    )
                    await analytics.track(.featureUsed(feature: "qr_code_copy", context: [:]))
                }

            case ._qrCodeGenerationCompleted, ._shareableQRCodeGenerationCompleted:
                return .none
            }
        }
        .ifLet(\.$qrScanner, action: \.qrScanner) {
            QRScannerFeature()
        }
        .ifLet(\.$qrShareSheet, action: \.qrShareSheet) {
            QRCodeShareSheetFeature()
        }
    }
}

// MARK: - Helper Extensions

extension HomeFeature.State {
    /// Get the computed interval in seconds from picker values
    func getComputedIntervalInSeconds() -> TimeInterval {
        if intervalPickerUnit == "days" {
            return TimeInterval(intervalPickerValue * 86400)
        } else {
            return TimeInterval(intervalPickerValue * 3600)
        }
    }

    /// Format an interval for display
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
}