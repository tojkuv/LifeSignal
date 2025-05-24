import SwiftUI
import Foundation
import UIKit
@preconcurrency import AVFoundation
import PhotosUI
import ComposableArchitecture
import Perception

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
                        let contact = try await contactRepository.addContact("Emergency Contact", extractedPhoneNumber, false, false)
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

            case .processGalleryImage(_):
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
                        let _ = try await contactRepository.updateContact(contactToSave)
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


/// A SwiftUI view for picking photos
struct PhotoPickerView: UIViewControllerRepresentable {
    /// The TCA store for the QR scanner
    let store: StoreOf<QRScannerFeature>

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPickerView

        init(_ parent: PhotoPickerView) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // Dismiss the picker
            DispatchQueue.main.async {
                self.parent.store.send(.toggleGallery(false))
            }

            guard let provider = results.first?.itemProvider else {
                // No image selected
                return
            }

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    if image as? UIImage != nil {
                        DispatchQueue.main.async {
                            // Process the selected image for QR code scanning
                            // This would need to be implemented in the feature
                            // For now, just show an alert if no QR code is found
                            self.parent.store.send(.showNoQRCodeAlert(true))
                        }
                    }
                }
            }
        }
    }
}


/// A SwiftUI view for scanning QR codes
struct QRScannerView: View {
    // MARK: - Properties

    /// The TCA store for the QR scanner
    @Bindable var store: StoreOf<QRScannerFeature>

    // MARK: - Body

    var body: some View {
        WithPerceptionTracking {
            ZStack {
                // Camera view or camera failed view
                if store.cameraPermissionStatus == .denied || store.cameraPermissionStatus == .restricted {
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
                store.send(.startScanning)
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
            .alert("No QR Code Found", isPresented: Binding(
                get: { store.showNoQRCodeAlert },
                set: { store.send(.showNoQRCodeAlert($0)) }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The selected image does not contain a valid QR code. Please try another image.")
            }
            .alert("Invalid UUID Format", isPresented: Binding(
                get: { store.showInvalidUUIDAlert },
                set: { store.send(.showInvalidUUIDAlert($0)) }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The clipboard content is not a valid UUID format.")
            }
            .alert("Camera Permission Denied", isPresented: Binding(
                get: { store.showPermissionDeniedAlert },
                set: { store.send(.showPermissionDeniedAlert($0)) }
            )) {
                Button("Open Settings") {
                    store.send(.openSettings)
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text("Camera access is required to scan QR codes. Please enable camera access in Settings.")
            }
            .sheet(isPresented: Binding(
                get: { store.showAddContactSheet },
                set: { store.send(.showAddContactSheet($0)) }
            )) {
                addContactSheetView()
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
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text(String(store.contact.name.isEmpty ? "?" : store.contact.name.prefix(1)))
                                        .foregroundColor(.blue)
                                        .font(.title)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.blue, lineWidth: 2)
                                )

                            // Name field - now non-editable
                            Text(store.contact.name.isEmpty ? "Unknown" : store.contact.name)
                                .font(.title3)
                                .multilineTextAlignment(.center)

                            // Phone field - now non-editable
                            Text(store.contact.phoneNumber.isEmpty ? "No phone number" : store.contact.phoneNumber)
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
                            .cornerRadius(10)

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
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)

                        // Emergency note section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Emergency Note")
                                .font(.headline)

                            Text("This is the contact's emergency information")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(store.contact.emergencyNote.isEmpty ? "No emergency note provided" : store.contact.emergencyNote)
                                .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
                                .padding(12)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(10)
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
                        store.send(.closeAddContactSheet)
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
                store.send(.stopScanning)
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
                        .cornerRadius(8)
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
                        .cornerRadius(8)
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
                    store.send(.openSettings)
                }) {
                    Text("Open Settings")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }

                Button(action: {
                    store.send(.toggleGallery(true))
                }) {
                    Text("Select from Gallery")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.gray)
                        .cornerRadius(10)
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
                            store.send(.handlePasteButtonTapped)
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
