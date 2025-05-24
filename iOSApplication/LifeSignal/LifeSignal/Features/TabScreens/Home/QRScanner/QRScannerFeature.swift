import Foundation
import SwiftUI
import UIKit
import ComposableArchitecture
import AVFoundation

// Define Alert enum outside to avoid circular dependencies
enum QRScannerAlert: Equatable {
    case cameraPermissionDenied
    case invalidCode
    case contactAdded(Contact)
    case processingFailed(String)
}

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
        
        // New state properties for view management
        var isShowingManualEntry = false
        var isShowingGallery = false
        var showNoQRCodeAlert = false
        var showInvalidUUIDAlert = false
        var showPermissionDeniedAlert = false
        var showAddContactSheet = false
        var showErrorAlert = false
        var manualQRCode = ""
        var galleryThumbnails: [UIImage] = []
        
        // Contact being added
        var contact = Contact(
            id: UUID(),
            name: "",
            phoneNumber: "",
            isResponder: true,
            isDependent: false,
            lastUpdated: Date(),
            emergencyNote: "",
            lastCheckInTime: nil,
            interval: 24 * 60 * 60,
            hasIncomingPing: false,
            hasOutgoingPing: false,
            manualAlertActive: false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil,
            manualAlertTimestamp: nil
        )
        
        @Presents var permissionAlert: AlertState<QRScannerAlert>?
        @Presents var processingAlert: AlertState<QRScannerAlert>?
        
        var canStartScanning: Bool {
            currentUser != nil && cameraPermissionStatus == .authorized
        }
        
        var canProcessCode: Bool {
            !manualCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        var isValidManualQRCode: Bool {
            isValidQRCodeFormat(manualQRCode)
        }

        var canSubmitManualCode: Bool {
            !manualQRCode.isEmpty && isValidManualQRCode
        }

        // Helper method moved to state for consistency
        private func isValidQRCodeFormat(_ text: String) -> Bool {
            // Check if it's a valid UUID format
            if UUID(uuidString: text) != nil {
                return true
            }

            // Check if it's a full LifeSignal URL with valid UUID
            if text.hasPrefix("lifesignal://") {
                let uuidPart = text.replacingOccurrences(of: "lifesignal://", with: "")
                return UUID(uuidString: uuidPart) != nil
            }

            return false
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case startScanning
        case stopScanning
        case toggleTorch
        case requestCameraPermission
        case processScannedCode(String)
        case processManualCode
        case pasteFromClipboard
        case permissionAlert(PresentationAction<QRScannerAlert>)
        case processingAlert(PresentationAction<QRScannerAlert>)
        case permissionResponse(AVAuthorizationStatus)
        case codeProcessingResponse(Result<Contact, Error>)
        case dismiss
        case openSettings

        // New actions for proper state management
        case toggleManualEntry(Bool)
        case toggleGallery(Bool)
        case showNoQRCodeAlert(Bool)
        case showInvalidUUIDAlert(Bool)
        case showPermissionDeniedAlert(Bool)
        case showAddContactSheet(Bool)
        case updateManualQRCode(String)
        case submitManualQRCode
        case cancelManualEntry
        case handlePasteButtonTapped
        case processGalleryImage(Int)
        case updateIsResponder(Bool)
        case updateIsDependent(Bool)
        case closeAddContactSheet
        case addContact
        case loadGalleryThumbnails
        case galleryThumbnailsLoaded([UIImage])
        case dismissErrorAlert
    }

    @Dependency(\.cameraClient) var cameraClient
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.qrCodeGenerator) var qrCodeGenerator
    @Dependency(\.contactRepository) var contactRepository
    @Dependency(\.analytics) var analytics

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce<State, Action> { state, action in
            switch action {
            case .binding:
                return .none

            case .startScanning:
                guard state.canStartScanning else {
                    if state.cameraPermissionStatus == .notDetermined {
                        return .send(.requestCameraPermission)
                    } else if state.cameraPermissionStatus == .denied {
                        state.showPermissionDeniedAlert = true
                    }
                    return .none
                }

                state.isScanning = true
                state.errorMessage = nil

                return .run { send in
                    await haptics.impact(.light)
                    await analytics.track(.featureUsed(feature: "qr_scan_start", context: [:]))
                    await send(.loadGalleryThumbnails)
                }

            case .stopScanning:
                state.isScanning = false
                state.torchOn = false
                state.scannedCode = nil
                return .none

            case .toggleTorch:
                state.torchOn.toggle()
                return .run { [torchOn = state.torchOn] _ in
                    await haptics.impact(.light)
                    await analytics.track(.featureUsed(feature: "qr_torch_toggle", context: ["on": "\(torchOn)"]))
                }

            case .requestCameraPermission:
                return .run { send in
                    let status = await cameraClient.requestPermission()
                    await send(.permissionResponse(status))
                }

            case let .processScannedCode(code):
                state.isScanning = false
                state.isLoading = true
                state.scannedCode = code

                return .run { send in
                    await haptics.notification(.success)
                    await analytics.track(.featureUsed(feature: "qr_code_scanned", context: [:]))
                    await send(.codeProcessingResponse(Result {
                        // Validate QR code format
                        guard code.hasPrefix("lifesignal://") else {
                            throw NSError(domain: "QRScanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid QR code format"])
                        }

                        // Extract phone number from QR code
                        let extractedPhoneNumber = code.replacingOccurrences(of: "lifesignal://", with: "")

                        // Add contact using phone number
                        let contact = try await contactRepository.addContact(extractedPhoneNumber)
                        return contact
                    }))
                }

            case .processManualCode:
                guard state.canProcessCode else { return .none }
                let code = state.manualCode.trimmingCharacters(in: .whitespacesAndNewlines)
                return .send(.processScannedCode(code))

            case .pasteFromClipboard:
                return .run { send in
                    if let clipboardText = UIPasteboard.general.string {
                        await send(.binding(.set(\.manualCode, clipboardText)))
                        await haptics.impact(.light)
                    }
                }

            case .permissionAlert(.presented(.cameraPermissionDenied)):
                return .send(.openSettings)

            case .permissionAlert, .processingAlert:
                return .none

            case let .permissionResponse(status):
                state.cameraPermissionStatus = status
                if status == .authorized {
                    return .send(.startScanning)
                }
                return .none

            case let .codeProcessingResponse(.success(contact)):
                state.isLoading = false
                state.contact = contact
                state.showAddContactSheet = true
                return .none

            case let .codeProcessingResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                state.showErrorAlert = true
                return .none

            case .dismiss:
                return .none

            case .openSettings:
                return .run { _ in
                    await haptics.impact(.medium)
                    await MainActor.run {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }

            case let .toggleManualEntry(show):
                state.isShowingManualEntry = show
                if show {
                    state.manualQRCode = ""
                }
                return .none

            case let .toggleGallery(show):
                state.isShowingGallery = show
                return .none

            case let .showNoQRCodeAlert(show):
                state.showNoQRCodeAlert = show
                return .none

            case let .showInvalidUUIDAlert(show):
                state.showInvalidUUIDAlert = show
                return .none

            case let .showPermissionDeniedAlert(show):
                state.showPermissionDeniedAlert = show
                return .none

            case let .showAddContactSheet(show):
                state.showAddContactSheet = show
                return .none

            case let .updateManualQRCode(code):
                state.manualQRCode = String(code.prefix(36)) // Limit to UUID length
                return .none

            case .submitManualQRCode:
                guard state.canSubmitManualCode else {
                    state.showInvalidUUIDAlert = true
                    return .none
                }
                state.isShowingManualEntry = false

                // Handle both UUID-only and full URL formats
                let codeToProcess: String
                if state.manualQRCode.hasPrefix("lifesignal://") {
                    codeToProcess = state.manualQRCode
                } else {
                    codeToProcess = "lifesignal://\(state.manualQRCode)"
                }

                return .send(.processScannedCode(codeToProcess))

            case .cancelManualEntry:
                state.isShowingManualEntry = false
                state.manualQRCode = ""
                return .none

            case .handlePasteButtonTapped:
                return .run { send in
                    if let clipboardText = UIPasteboard.general.string {
                        await send(.updateManualQRCode(clipboardText))
                        await haptics.impact(.light)
                    }
                }

            case let .processGalleryImage(index):
                // Process image at index from gallery
                return .run { send in
                    // Implementation for processing gallery image
                    await haptics.impact(.light)
                    // This would typically involve QR code detection from the image
                }

            case let .updateIsResponder(isResponder):
                state.contact.isResponder = isResponder
                return .none

            case let .updateIsDependent(isDependent):
                state.contact.isDependent = isDependent
                return .none

            case .closeAddContactSheet:
                state.showAddContactSheet = false
                return .none

            case .addContact:
                guard state.contact.isResponder || state.contact.isDependent else {
                    state.errorMessage = "Please select at least one role for the contact"
                    state.showErrorAlert = true
                    return .none
                }

                // The contact already has the correct isResponder/isDependent values
                let contactToSave = state.contact

                return .run { send in
                    do {
                        let savedContact = try await contactRepository.saveContact(contactToSave)
                        await haptics.notification(.success)
                        await analytics.track(.featureUsed(feature: "contact_added", context: ["via": "qr_scanner"]))
                        await send(.closeAddContactSheet)
                        await send(.dismiss)
                    } catch {
                        await send(.codeProcessingResponse(.failure(error)))
                    }
                }

            case .loadGalleryThumbnails:
                return .run { send in
                    // Load recent photos from gallery
                    let thumbnails: [UIImage] = [] // Implementation would load actual thumbnails
                    await send(.galleryThumbnailsLoaded(thumbnails))
                }

            case let .galleryThumbnailsLoaded(thumbnails):
                state.galleryThumbnails = thumbnails
                return .none

            case .dismissErrorAlert:
                state.showErrorAlert = false
                state.errorMessage = nil
                return .none
            }
        }
        .ifLet(\.$permissionAlert, action: \.permissionAlert)
        .ifLet(\.$processingAlert, action: \.processingAlert)
    }
}