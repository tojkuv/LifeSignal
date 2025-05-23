import Foundation
import SwiftUI
import UIKit
import ComposableArchitecture
import AVFoundation
import Sharing

@Reducer
struct QRScannerFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.currentUser) var currentUser: User? = nil
        
        var isScanning = false
        var isLoading = false
        var torchOn = false
        var scannedCode: String? = nil
        var errorMessage: String? = nil
        var manualCode = ""
        var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
        
        @Presents var permissionAlert: AlertState<Action.Alert>?
        @Presents var processingAlert: AlertState<Action.Alert>?
        
        var canStartScanning: Bool {
            currentUser != nil && cameraPermissionStatus == .authorized
        }
        
        var canProcessCode: Bool {
            !manualCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case startScanning
        case stopScanning
        case toggleTorch
        case requestCameraPermission
        case processScannedCode(String)
        case processManualCode
        case pasteFromClipboard
        case permissionAlert(PresentationAction<Alert>)
        case processingAlert(PresentationAction<Alert>)
        case permissionResponse(AVAuthorizationStatus)
        case codeProcessingResponse(Result<Contact, Error>)
        
        // Missing actions from PhotoPickerView
        case toggleGallery(Bool)
        case showNoQRCodeAlert(Bool)
        
        enum Alert: Equatable {
            case cameraPermissionDenied
            case invalidCode
            case contactAdded(Contact)
            case processingFailed(String)
        }
    }

    @Dependency(\.cameraClient) var cameraClient
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.qrCodeGenerator) var qrCodeGenerator
    @Dependency(\.contactRepository) var contactRepository
    @Dependency(\.analytics) var analytics

    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .startScanning:
                guard state.canStartScanning else {
                    return .send(.requestCameraPermission)
                }
                
                state.isScanning = true
                state.scannedCode = nil
                state.errorMessage = nil
                
                return .run { _ in
                    await analytics.track(.featureUsed(feature: "qr_scanner_start", context: [:]))
                }
                
            case .stopScanning:
                state.isScanning = false
                
                return .run { _ in
                    await haptics.selection()
                }
                
            case .toggleTorch:
                let newTorchState = !state.torchOn
                state.torchOn = newTorchState
                
                return .run { _ in
                    await haptics.selection()
                    await analytics.track(.featureUsed(feature: "torch_toggle", context: ["enabled": "\(newTorchState)"]))
                }
                
            case .requestCameraPermission:
                return .run { send in
                    await analytics.track(.featureUsed(feature: "camera_permission_request", context: [:]))
                    let status = await cameraClient.requestPermission()
                    await send(.permissionResponse(status))
                }
                
            case let .processScannedCode(code):
                state.scannedCode = code
                state.isScanning = false
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { send in
                    await haptics.notification(.success)
                    await analytics.track(.featureUsed(feature: "qr_code_scanned", context: ["method": "camera"]))
                    await send(.codeProcessingResponse(Result {
                        try await processQRCode(code)
                    }))
                }
                
            case .processManualCode:
                guard state.canProcessCode else { return .none }
                
                let code = state.manualCode.trimmingCharacters(in: .whitespacesAndNewlines)
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { send in
                    await analytics.track(.featureUsed(feature: "qr_code_scanned", context: ["method": "manual"]))
                    await send(.codeProcessingResponse(Result {
                        try await processQRCode(code)
                    }))
                }
                
            case .pasteFromClipboard:
                if let clipboardString = UIPasteboard.general.string {
                    state.manualCode = clipboardString
                    
                    return .run { _ in
                        await haptics.selection()
                        await analytics.track(.featureUsed(feature: "qr_code_paste", context: [:]))
                    }
                }
                return .none
                
            case let .permissionResponse(status):
                state.cameraPermissionStatus = status
                
                if status == .denied || status == .restricted {
                    state.permissionAlert = AlertState {
                        TextState("Camera Permission Required")
                    } actions: {
                        ButtonState(action: .cameraPermissionDenied) {
                            TextState("Settings")
                        }
                        ButtonState(role: .cancel) {
                            TextState("Cancel")
                        }
                    } message: {
                        TextState("Camera access is required to scan QR codes. Please enable it in Settings.")
                    }
                } else if status == .authorized {
                    state.isScanning = true
                }
                
                return .none
                
            case let .codeProcessingResponse(.success(contact)):
                state.isLoading = false
                state.manualCode = ""
                
                state.processingAlert = AlertState {
                    TextState("Contact Added")
                } actions: {
                    ButtonState(action: .contactAdded(contact)) {
                        TextState("OK")
                    }
                } message: {
                    TextState("\(contact.name) has been added to your contacts.")
                }
                
                return .run { _ in
                    await haptics.notification(.success)
                }
                
            case let .codeProcessingResponse(.failure(error)):
                state.isLoading = false
                
                if error.localizedDescription.contains("Invalid") {
                    state.processingAlert = AlertState {
                        TextState("Invalid QR Code")
                    } actions: {
                        ButtonState(action: .invalidCode) {
                            TextState("OK")
                        }
                    } message: {
                        TextState("The scanned QR code is not a valid LifeSignal contact code.")
                    }
                } else {
                    state.errorMessage = error.localizedDescription
                    state.processingAlert = AlertState {
                        TextState("Processing Failed")
                    } actions: {
                        ButtonState(action: .processingFailed(error.localizedDescription)) {
                            TextState("OK")
                        }
                    } message: {
                        TextState(error.localizedDescription)
                    }
                }
                
                return .run { _ in
                    await haptics.notification(.error)
                }
                
            case .permissionAlert(.presented(.cameraPermissionDenied)):
                return .run { _ in
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        await UIApplication.shared.open(settingsURL)
                    }
                }
                
            case .permissionAlert:
                return .none
                
            case .processingAlert:
                return .none
                
            // Handle missing actions from PhotoPickerView
            case let .toggleGallery(isOpen):
                // Handle gallery toggle
                return .run { _ in
                    await analytics.track(.featureUsed(feature: "qr_scanner_gallery_toggle", context: ["is_open": "\(isOpen)"]))
                }
                
            case let .showNoQRCodeAlert(show):
                if show {
                    state.processingAlert = AlertState {
                        TextState("No QR Code Found")
                    } actions: {
                        ButtonState(action: .invalidCode) {
                            TextState("OK")
                        }
                    } message: {
                        TextState("No QR code was found in the selected image.")
                    }
                }
                return .none
            }
        }
        .ifLet(\.$permissionAlert, action: \.permissionAlert)
        .ifLet(\.$processingAlert, action: \.processingAlert)
    }
    
    // Helper function to process QR codes and create contacts
    private func processQRCode(_ code: String) async throws -> Contact {
        // Validate UUID format
        guard let uuid = UUID(uuidString: code) else {
            throw QRCodeError.invalidFormat
        }
        
        // In production, this would fetch contact info from the server using the UUID
        // For now, simulate contact creation
        try await Task.sleep(for: .milliseconds(1000))
        
        return Contact(
            id: UUID(),
            userID: uuid,
            name: "Scanned Contact",
            phoneNumber: "+1234567890",
            relationship: .responder,
            status: .active,
            lastUpdated: Date(),
            qrCodeId: code,
            lastCheckIn: nil,
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
    }
    
    enum QRCodeError: LocalizedError {
        case invalidFormat
        case networkError
        case contactNotFound
        
        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "Invalid QR code format"
            case .networkError:
                return "Network error occurred"
            case .contactNotFound:
                return "Contact not found"
            }
        }
    }
}