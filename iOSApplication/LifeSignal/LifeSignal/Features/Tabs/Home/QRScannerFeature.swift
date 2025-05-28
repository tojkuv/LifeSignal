import SwiftUI
import Foundation
import UIKit
@preconcurrency import AVFoundation
import PhotosUI
import Photos
import ComposableArchitecture
import Perception

@Reducer
struct QRScannerFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.currentUser) var currentUser: User? = nil
        
        var isScanning = false
        var isLoading = false
        var torchOn = false
        var scannedCode: String? = nil
        var manualQRCode = ""
        var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
        var photoLibraryPermissionStatus: PHAuthorizationStatus = .notDetermined
        
        // View state
        var isShowingManualEntry = false
        var isShowingGallery = false
        var showNoQRCodeAlert = false
        var showQRCodeFoundButNoUserAlert = false
        var showInvalidUUIDAlert = false
        var showAddContactSheet = false
        var showErrorAlert = false
        var errorMessage: String? = nil
        var galleryThumbnails: [UIImage] = []
        var areGalleryThumbnailsMock: Bool = false
        
        // Contact being added - using updated Contact model
        var contact = Contact(
            id: UUID(),
            name: "",
            phoneNumber: "",
            isResponder: false,
            isDependent: false,
            emergencyNote: "",
            lastCheckInTimestamp: Date().addingTimeInterval(-3600), // 1 hour ago
            checkInInterval: 24 * 60 * 60,
            hasIncomingPing: false,
            hasOutgoingPing: false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil,
            hasManualAlertActive: false,
            emergencyAlertTimestamp: nil,
            hasNotResponsiveAlert: false,
            notResponsiveAlertTimestamp: nil,
            profileImageURL: nil,
            profileImageData: nil,
            dateAdded: Date(),
            lastUpdated: Date()
        )
        
        var cameraLoadFailed: Bool {
            cameraPermissionStatus == .denied || cameraPermissionStatus == .restricted
        }
        
        var canSubmitManualCode: Bool {
            !manualQRCode.isEmpty && isValidQRCodeFormat(manualQRCode)
        }

        func isValidQRCodeFormat(_ text: String) -> Bool {
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

    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case initializeCamera
        case toggleTorch
        case processScannedCode(String)
        case toggleManualEntry(Bool)
        case toggleGallery(Bool)
        case updateManualQRCode(String)
        case submitManualQRCode
        case cancelManualEntry
        case handlePasteButtonTapped
        case processGalleryImage(Int)
        case updateIsResponder(Bool)
        case updateIsDependent(Bool)
        case closeAddContactSheet
        case addContact
        case cancelAddContact
        case loadGalleryThumbnails
        case galleryThumbnailsLoaded([UIImage])
        case galleryThumbnailsLoadedAsMock([UIImage])
        case requestPhotoLibraryPermission
        case photoLibraryPermissionResponse(PHAuthorizationStatus)
        case dismiss
        case permissionResponse(AVAuthorizationStatus)
        case codeProcessingResponse(Result<Contact, Error>)
        case contactAddResponse(Result<Contact, Error>)
        
        // Missing actions
        case showNoQRCodeAlert(Bool)
        case showQRCodeFoundButNoUserAlert(Bool)
        case showInvalidUUIDAlert(Bool)
        case showAddContactSheet(Bool)
        case dismissErrorAlert
        case showGalleryWithPermission
        case processImageForQRCode(UIImage)
    }

    @Dependency(\.contactsClient) var contactsClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.cameraClient) var cameraClient
    @Dependency(\.phoneNumberFormatter) var phoneNumberFormatter

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            coreReducer(state: &state, action: action)
        }
    }
    
    // MARK: - Core Reducer Logic
    
    private func coreReducer(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .binding:
            return .none
            
        case .onAppear:
            return .send(.initializeCamera)
            
        case .initializeCamera:
            return initializeCameraEffect()
            
        case .toggleTorch:
            return toggleTorchEffect(state: &state)
            
        case let .processScannedCode(code):
            return processScannedCodeEffect(state: &state, code: code)
            
        case let .toggleManualEntry(show):
            return toggleManualEntryEffect(state: &state, show: show)
            
        case let .toggleGallery(show):
            state.isShowingGallery = show
            return .none
            
        case let .updateManualQRCode(code):
            state.manualQRCode = String(code.prefix(36))
            return .none
            
        case .submitManualQRCode:
            return submitManualQRCodeEffect(state: &state)
            
        case .cancelManualEntry:
            return cancelManualEntryEffect(state: &state)
            
        case .handlePasteButtonTapped:
            return handlePasteButtonEffect()
            
        case let .processGalleryImage(index):
            return processGalleryImageEffect(state: &state, index: index)
            
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
            return addContactEffect(state: state)
            
        case .cancelAddContact:
            state.showAddContactSheet = false
            return .run { send in
                await send(.dismiss)
            }
            
        case .loadGalleryThumbnails:
            return loadGalleryThumbnailsEffect()
            
        case let .galleryThumbnailsLoaded(thumbnails):
            state.galleryThumbnails = thumbnails
            state.areGalleryThumbnailsMock = false
            return .none
            
        case let .galleryThumbnailsLoadedAsMock(thumbnails):
            state.galleryThumbnails = thumbnails
            state.areGalleryThumbnailsMock = true
            return .none
            
        case .requestPhotoLibraryPermission:
            return requestPhotoLibraryPermissionEffect()
            
        case let .photoLibraryPermissionResponse(status):
            return photoLibraryPermissionResponseEffect(state: &state, status: status)
            
        case .dismiss:
            return .none
            
        case let .permissionResponse(status):
            return permissionResponseEffect(state: &state, status: status)
            
        case let .codeProcessingResponse(.success(contact)):
            return codeProcessingSuccessEffect(state: &state, contact: contact)
            
        case let .codeProcessingResponse(.failure(error)):
            return codeProcessingFailureEffect(state: &state, error: error)
            
        case .contactAddResponse(.success):
            return contactAddSuccessEffect(state: &state)
            
        case let .contactAddResponse(.failure(error)):
            return contactAddFailureEffect(error: error)
            
        // Missing action handlers
        case let .showNoQRCodeAlert(show):
            state.showNoQRCodeAlert = show
            return .none
            
        case let .showQRCodeFoundButNoUserAlert(show):
            state.showQRCodeFoundButNoUserAlert = show
            return .none
            
        case let .showInvalidUUIDAlert(show):
            state.showInvalidUUIDAlert = show
            return .none
            
        case let .showAddContactSheet(show):
            state.showAddContactSheet = show
            return .none
            
        case .dismissErrorAlert:
            state.showErrorAlert = false
            state.errorMessage = nil
            return .none
            
        case .showGalleryWithPermission:
            state.isShowingGallery = true
            return .none
            
        case let .processImageForQRCode(image):
            return processImageForQRCodeEffect(state: &state, image: image)
        }
    }
    
    // MARK: - Effect Functions
    
    private func initializeCameraEffect() -> Effect<Action> {
        .run { [cameraClient] send in
            let status = await cameraClient.requestPermission()
            await send(.permissionResponse(status))
        }
    }
    
    private func toggleTorchEffect(state: inout State) -> Effect<Action> {
        state.torchOn.toggle()
        return .run { [haptics] _ in
            await haptics.impact(.light)
        }
    }
    
    private func processScannedCodeEffect(state: inout State, code: String) -> Effect<Action> {
        state.isLoading = true
        state.scannedCode = code
        
        return .run { [contactsClient, haptics] send in
            await send(.codeProcessingResponse(Result {
                let qrCodeId: String
                if code.hasPrefix("lifesignal://") {
                    qrCodeId = String(code.dropFirst("lifesignal://".count))
                } else {
                    qrCodeId = code
                }
                
                // Use ContactsClient to handle the QR code processing logic
                let contact = try await contactsClient.getContactByQRCode(qrCodeId)
                await haptics.notification(.success)
                return contact
            }))
        }
    }
    
    private func toggleManualEntryEffect(state: inout State, show: Bool) -> Effect<Action> {
        state.isShowingManualEntry = show
        if show {
            state.manualQRCode = ""
        }
        return .none
    }
    
    private func submitManualQRCodeEffect(state: inout State) -> Effect<Action> {
        guard state.canSubmitManualCode else {
            state.showInvalidUUIDAlert = true
            return .none
        }
        state.isShowingManualEntry = false
        
        let codeToProcess: String
        if state.manualQRCode.hasPrefix("lifesignal://") {
            codeToProcess = state.manualQRCode
        } else {
            codeToProcess = state.manualQRCode
        }
        
        return .send(.processScannedCode(codeToProcess))
    }
    
    private func cancelManualEntryEffect(state: inout State) -> Effect<Action> {
        state.isShowingManualEntry = false
        state.manualQRCode = ""
        return .none
    }
    
    private func handlePasteButtonEffect() -> Effect<Action> {
        .run { [haptics] send in
            if let clipboardText = UIPasteboard.general.string {
                await send(.updateManualQRCode(clipboardText))
                await haptics.impact(.light)
            }
        }
    }
    
    private func processGalleryImageEffect(state: inout State, index: Int) -> Effect<Action> {
        guard state.galleryThumbnails.indices.contains(index) else {
            return .run { send in
                await send(.showNoQRCodeAlert(true))
            }
        }
        
        // If these are mock thumbnails and photo library permission is not granted, request permission
        if state.areGalleryThumbnailsMock && state.photoLibraryPermissionStatus != .authorized && state.photoLibraryPermissionStatus != .limited {
            return .send(.requestPhotoLibraryPermission)
        }
        
        return .run { [haptics, cameraClient] send in
            await haptics.impact(.light)
            await send(.toggleGallery(false))
            
            // Load full resolution image for the selected index instead of using thumbnail
            if let fullResImage = await cameraClient.getFullResolutionRecentPhoto(index) {
                await send(.processImageForQRCode(fullResImage))
            } else {
                await send(.showNoQRCodeAlert(true))
            }
        }
    }
    
    private func processImageForQRCodeEffect(state: inout State, image: UIImage) -> Effect<Action> {
        .run { [haptics, cameraClient] send in
            await haptics.impact(.light)
            
            // Use CameraClient to detect QR code in the image
            let qrCodeString = await cameraClient.detectQRCode(image)
            
            if let qrCode = qrCodeString {
                // QR code found - now validate if it's a valid LifeSignal QR code
                let cleanedCode = qrCode.hasPrefix("lifesignal://") ? String(qrCode.dropFirst("lifesignal://".count)) : qrCode
                
                // Validate UUID format
                if UUID(uuidString: cleanedCode) != nil {
                    // Valid UUID format - process it (this will handle 80%/20% logic in ContactsClient)
                    await send(.processScannedCode(qrCode))
                } else {
                    // QR code found but not a valid LifeSignal UUID format
                    await send(.showInvalidUUIDAlert(true))
                }
            } else {
                // No QR code found in image
                await send(.showNoQRCodeAlert(true))
            }
        }
    }
    
    private func addContactEffect(state: State) -> Effect<Action> {
        guard state.contact.isResponder || state.contact.isDependent else {
            return .run { send in
                await send(.dismissErrorAlert)
            }
        }
        
        return .run { [contactsClient, haptics, contact = state.contact] send in
            await haptics.notification(.success)
            await send(.contactAddResponse(Result {
                try await contactsClient.addContact(
                    contact.name,
                    contact.phoneNumber,
                    contact.isResponder,
                    contact.isDependent
                )
            }))
        }
    }
    
    private func loadGalleryThumbnailsEffect() -> Effect<Action> {
        .run { [cameraClient] send in
            // Check photo library permission first
            let photoStatus = await cameraClient.checkPhotoLibraryPermission()
            let thumbnails = await cameraClient.getRecentPhotos()
            
            // If permission is not granted, these will be mock thumbnails
            if photoStatus == .authorized || photoStatus == .limited {
                await send(.galleryThumbnailsLoaded(thumbnails))
            } else {
                await send(.galleryThumbnailsLoadedAsMock(thumbnails))
            }
        }
    }
    
    private func permissionResponseEffect(state: inout State, status: AVAuthorizationStatus) -> Effect<Action> {
        state.cameraPermissionStatus = status
        if status == .authorized {
            state.isScanning = true
            // Check current photo library permission status and load gallery thumbnails
            return .run { [cameraClient] send in
                // Check current photo library permission
                let photoStatus = await cameraClient.checkPhotoLibraryPermission()
                await send(.photoLibraryPermissionResponse(photoStatus))
                // Load gallery thumbnails
                await send(.loadGalleryThumbnails)
            }
        }
        return .none
    }
    
    private func codeProcessingSuccessEffect(state: inout State, contact: Contact) -> Effect<Action> {
        state.isLoading = false
        state.contact = contact
        state.showAddContactSheet = true
        return .none
    }
    
    private func codeProcessingFailureEffect(state: inout State, error: Error) -> Effect<Action> {
        state.isLoading = false
        
        if let contactsError = error as? ContactsClientError {
            switch contactsError {
            case .contactNotFound(let details):
                if details.contains("QR code found but no LifeSignal user was found") {
                    // QR code found but no LifeSignal user found
                    state.showQRCodeFoundButNoUserAlert = true
                    return .run { [haptics] _ in
                        await haptics.notification(.warning)
                    }
                } else {
                    // Invalid QR code format or other contact not found errors
                    state.errorMessage = error.localizedDescription
                    state.showErrorAlert = true
                    return .run { [haptics, notificationClient] _ in
                        await haptics.notification(.error)
                        try? await notificationClient.sendSystemNotification(
                            "QR Code Error",
                            "Unable to process QR code: \(error.localizedDescription)"
                        )
                    }
                }
            default:
                // Other ContactsClient errors
                state.errorMessage = error.localizedDescription
                state.showErrorAlert = true
                return .run { [haptics, notificationClient] _ in
                    await haptics.notification(.error)
                    try? await notificationClient.sendSystemNotification(
                        "QR Code Error",
                        "Unable to process QR code: \(error.localizedDescription)"
                    )
                }
            }
        } else {
            // Other non-ContactsClient errors
            state.errorMessage = error.localizedDescription
            state.showErrorAlert = true
            return .run { [haptics, notificationClient] _ in
                await haptics.notification(.error)
                try? await notificationClient.sendSystemNotification(
                    "QR Code Error",
                    "Unable to process QR code: \(error.localizedDescription)"
                )
            }
        }
    }
    
    private func contactAddSuccessEffect(state: inout State) -> Effect<Action> {
        state.showAddContactSheet = false
        return .run { [haptics, notificationClient, contactName = state.contact.name] send in
            await haptics.notification(.success)
            try? await notificationClient.sendSystemNotification(
                "Contact Added",
                "Successfully added \(contactName) to your contacts"
            )
            // Dismiss the QR scanner after successfully adding contact
            await send(.dismiss)
        }
    }
    
    private func contactAddFailureEffect(error: Error) -> Effect<Action> {
        .run { [haptics, notificationClient] _ in
            await haptics.notification(.error)
            try? await notificationClient.sendSystemNotification(
                "Add Contact Failed",
                "Unable to add contact: \(error.localizedDescription)"
            )
        }
    }
    
    private func requestPhotoLibraryPermissionEffect() -> Effect<Action> {
        .run { [cameraClient] send in
            let status = await cameraClient.requestPhotoLibraryPermission()
            await send(.photoLibraryPermissionResponse(status))
        }
    }
    
    private func photoLibraryPermissionResponseEffect(state: inout State, status: PHAuthorizationStatus) -> Effect<Action> {
        state.photoLibraryPermissionStatus = status
        // If permission was granted, reload gallery thumbnails with real photos
        if status == .authorized || status == .limited {
            return .send(.loadGalleryThumbnails)
        }
        return .none
    }
}

/// A SwiftUI view that wraps a UIKit camera preview view
struct CameraPreviewView: UIViewRepresentable {
    /// Whether the torch is on
    var torchOn: Bool

    /// Coordinator class to manage the capture session
    class Coordinator: NSObject {
        let session = AVCaptureSession()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Create the UIView
    func makeUIView(context: Context) -> UIView {
        // Create a UIView to hold the camera preview
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black

        // Create a preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: context.coordinator.session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        // Configure the session
        configureSession(context.coordinator.session)

        return view
    }

    /// Update the UIView
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update torch state
        guard let device = AVCaptureDevice.default(for: .video) else { return }

        if device.hasTorch && device.isTorchAvailable {
            do {
                try device.lockForConfiguration()
                device.torchMode = torchOn ? .on : .off
                device.unlockForConfiguration()
            } catch {
                print("Failed to set torch mode: \(error)")
            }
        }
    }

    /// Configure the capture session
    private func configureSession(_ session: AVCaptureSession) {
        // Get the default video device
        guard let device = AVCaptureDevice.default(for: .video) else {
            print("No video device available")
            return
        }

        // Create an input from the device
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            print("Failed to create capture input")
            return
        }

        // Check if we can add the input to the session
        if session.canAddInput(input) {
            session.addInput(input)
        } else {
            print("Cannot add input to session")
            return
        }

        // Create a metadata output
        let output = AVCaptureMetadataOutput()

        // Check if we can add the output to the session
        if session.canAddOutput(output) {
            session.addOutput(output)

            // Configure the output to detect QR codes
            output.metadataObjectTypes = [.qr]
        } else {
            print("Cannot add output to session")
            return
        }

        // Start the session on a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
}



/// A SwiftUI view for scanning QR codes
struct QRScannerView: View {
    // MARK: - Properties

    /// The TCA store for the QR scanner
    @Bindable var store: StoreOf<QRScannerFeature>
    
    @Dependency(\.phoneNumberFormatter) var phoneNumberFormatter

    // MARK: - Body

    var body: some View {
        WithPerceptionTracking {
            ZStack {
                // Camera view or camera failed view
                if store.cameraLoadFailed {
                    cameraFailedView()
                } else {
                    cameraView()
                }

                // Overlay controls
                VStack {
                    // Top controls
                    topControlsView()

                    Spacer()

                    // Bottom controls
                    bottomControlsView()
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
            .sheet(isPresented: Binding(
                get: { store.isShowingManualEntry },
                set: { store.send(.toggleManualEntry($0)) }
            )) {
                manualEntryView()
            }
            .sheet(isPresented: Binding(
                get: { store.isShowingGallery },
                set: { store.send(.toggleGallery($0)) }
            )) {
                PhotoPickerView(store: store)
            }
            .sheet(isPresented: Binding(
                get: { store.showAddContactSheet },
                set: { store.send(.showAddContactSheet($0)) }
            )) {
                addContactSheetView()
            }
            .alert("No QR Code", isPresented: Binding(
                get: { store.showNoQRCodeAlert },
                set: { store.send(.showNoQRCodeAlert($0)) }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("No QR code found in this image.")
            }
            .alert("Invalid QR Code", isPresented: Binding(
                get: { store.showInvalidUUIDAlert },
                set: { store.send(.showInvalidUUIDAlert($0)) }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This is not a valid LifeSignal QR code.")
            }
            .alert("User Not Found", isPresented: Binding(
                get: { store.showQRCodeFoundButNoUserAlert },
                set: { store.send(.showQRCodeFoundButNoUserAlert($0)) }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("No LifeSignal user found for this QR code.")
            }
        }
    }

    // MARK: - Subviews

    /// The add contact sheet view
    @ViewBuilder
    private func addContactSheetView() -> some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header (avatar, name, phone) - centered, stacked
                        VStack(spacing: 12) {
                            CommonAvatarView(
                                name: store.contact.name.isEmpty ? "?" : store.contact.name,
                                size: 100,
                                backgroundColor: Color.blue.opacity(0.1),
                                textColor: .blue,
                                strokeWidth: 2,
                                strokeColor: .blue
                            )

                            // Name field - now non-editable
                            Text(store.contact.name.isEmpty ? "Unknown" : store.contact.name)
                                .font(.title3)
                                .multilineTextAlignment(.center)

                            // Phone field - now non-editable with formatting
                            Text(store.contact.phoneNumber.isEmpty ? "No phone number" : phoneNumberFormatter.formatPhoneNumberForDisplay(store.contact.phoneNumber))
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top)

                        // Role selection
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Contact Role")
                                .font(.headline)

                            // Responder toggle
                            Toggle(isOn: Binding(
                                get: { store.contact.isResponder },
                                set: { store.send(.updateIsResponder($0)) }
                            )) {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .foregroundColor(.blue)

                                    VStack(alignment: .leading) {
                                        Text("Responder")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)

                                        Text("Can see your status and respond if you need help")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)

                            // Dependent toggle
                            Toggle(isOn: Binding(
                                get: { store.contact.isDependent },
                                set: { store.send(.updateIsDependent($0)) }
                            )) {
                                HStack {
                                    Image(systemName: "person.3.fill")
                                        .foregroundColor(.blue)

                                    VStack(alignment: .leading) {
                                        Text("Dependent")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)

                                        Text("You can see their status and respond if they need help")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                            
                            // Role selection warning card (shown when no role is selected)
                            if !store.contact.isResponder && !store.contact.isDependent {
                                VStack(spacing: 0) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .foregroundColor(.orange)
                                                    .font(.caption)
                                                
                                                Text("Please Select a Role")
                                                    .font(.body)
                                                    .foregroundColor(.orange)
                                            }
                                            
                                            Text("You must select at least one role (Responder or Dependent) to add this contact.")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal)
                                }
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)

                        // Emergency note section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Emergency Note")
                                .font(.headline)

                            Text("This is the contact's emergency information")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack {
                                Text(store.contact.emergencyNote.isEmpty ? "No emergency note provided" : store.contact.emergencyNote)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 40)
                }
                .background(Color(UIColor.systemGroupedBackground))
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        store.send(.cancelAddContact)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        store.send(.addContact)
                    }
                    .disabled(store.contact.name.isEmpty || (!store.contact.isResponder && !store.contact.isDependent))
                }
            }
            .alert(isPresented: Binding(
                get: { store.showErrorAlert },
                set: { _ in store.send(.dismissErrorAlert) }
            )) {
                Alert(
                    title: Text("Error"),
                    message: Text(store.errorMessage ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    /// The top controls view
    @ViewBuilder
    private func topControlsView() -> some View {
        HStack {
            // Close button
            Button(action: {
                store.send(.dismiss)
            }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
            }

            Spacer()

            // Torch button
            Button(action: {
                store.send(.toggleTorch)
            }) {
                Image(systemName: store.torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                    .font(.title2)
                    .foregroundColor(store.torchOn ? .yellow : .white)
                    .padding(12)
            }
        }
        .padding(4)
    }

    /// The bottom controls view
    @ViewBuilder
    private func bottomControlsView() -> some View {
        VStack {
            // Gallery carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    // Gallery thumbnails
                    ForEach(0..<store.galleryThumbnails.count, id: \.self) { index in
                        Button(action: {
                            store.send(.processGalleryImage(index))
                        }) {
                            Image(uiImage: store.galleryThumbnails[index])
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 90, height: 90)
                                .clipShape(Rectangle())
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 100)

            // Horizontal stack for buttons
            HStack {
                // Manual Entry button
                Button(action: {
                    store.send(.toggleManualEntry(true))
                }) {
                    Text("By QR Code ID")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .cornerRadius(12)
                }

                Spacer()

                // Gallery button
                Button(action: {
                    store.send(.toggleGallery(true))
                }) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .padding(12)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 48)
        }
    }

    /// The camera view
    @ViewBuilder
    private func cameraView() -> some View {
        CameraPreviewView(torchOn: store.torchOn)
            .edgesIgnoringSafeArea(.all)
    }

    /// The camera failed view
    @ViewBuilder
    private func cameraFailedView() -> some View {
        ZStack {
            Color.black
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)

                Text("Camera Access Required")
                    .font(.title2)
                    .foregroundColor(.white)

                Text("Please allow camera access in Settings to scan QR codes.")
                    .font(.body)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Open Settings")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }

                Button(action: {
                    store.send(.toggleGallery(true))
                }) {
                    Text("Select from Gallery")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.gray)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
    }

    /// The manual entry view
    @ViewBuilder
    private func manualEntryView() -> some View {
        NavigationStack {
            VStack(alignment: .center, spacing: 20) {
                Text("Enter QR Code ID")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 20)

                // Verification code style text field with paste button
                ZStack(alignment: .trailing) {
                    TextField("QR Code ID", text: Binding(
                        get: { store.manualQRCode },
                        set: { store.send(.updateManualQRCode($0)) }
                    ))
                    .keyboardType(.default)
                    .font(.body)
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                    // Paste button that only shows when text field is empty
                    if store.manualQRCode.isEmpty {
                        Button(action: {
                            store.send(.handlePasteButtonTapped, animation: .default)
                        }) {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(.blue)
                                .padding(.trailing, 16)
                        }
                    }
                }
                .padding(.horizontal)

                // Verify button style
                Button(action: {
                    store.send(.submitManualQRCode)
                }) {
                    Text("Add Contact")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .background(store.canSubmitManualCode ? Color.blue : Color.gray)
                .cornerRadius(12)
                .padding(.horizontal)
                .disabled(!store.canSubmitManualCode)

                Spacer()
            }
            .padding()
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitle("Manual Entry", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                store.send(.cancelManualEntry)
            })
        }
    }
}

// MARK: - PhotoPickerView

struct PhotoPickerView: View {
    @Bindable var store: StoreOf<QRScannerFeature>
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Recent Photos")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                if store.galleryThumbnails.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        
                        Text("No photos available")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if store.photoLibraryPermissionStatus == .notDetermined {
                            Button("Allow Photo Access") {
                                store.send(.requestPhotoLibraryPermission)
                            }
                            .foregroundColor(.blue)
                        } else if store.photoLibraryPermissionStatus == .denied {
                            VStack(spacing: 12) {
                                Text("Photo library access is required to select images")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button("Open Settings") {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(0..<store.galleryThumbnails.count, id: \.self) { index in
                                Button(action: {
                                    store.send(.processGalleryImage(index))
                                }) {
                                    Image(uiImage: store.galleryThumbnails[index])
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipped()
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Select Photo")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    store.send(.toggleGallery(false))
                }
            )
            .onAppear {
                store.send(.loadGalleryThumbnails)
            }
        }
    }
}
