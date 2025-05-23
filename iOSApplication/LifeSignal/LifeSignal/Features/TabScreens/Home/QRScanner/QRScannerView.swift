import SwiftUI
import PhotosUI
import AVFoundation
import ComposableArchitecture
import Perception

/// A SwiftUI view for scanning QR codes
struct QRScannerView: View {
    // MARK: - Properties

    /// The TCA store for the QR scanner
    @Perception.Bindable var store: StoreOf<QRScannerFeature>

    // MARK: - Body

    var body: some View {
        WithPerceptionTracking {
            ZStack {
                // Camera view or camera failed view
                if store.cameraPermissionStatus == .denied || store.cameraPermissionStatus == .restricted {
                    cameraFailedView
                } else {
                    cameraView
                }

                // Overlay controls
                VStack {
                    // Top controls
                    topControlsView

                    Spacer()

                    // Bottom controls
                    bottomControlsView
                }
            }
            .onAppear {
                store.send(.startScanning)
            }
            .sheet(isPresented: $store.isShowingManualEntry.sending(\.toggleManualEntry)) {
                manualEntryView
            }
            .sheet(isPresented: $store.isShowingGallery.sending(\.toggleGallery)) {
                PhotoPickerView(store: store)
            }
            .alert("No QR Code Found", isPresented: $store.showNoQRCodeAlert.sending(\.showNoQRCodeAlert)) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The selected image does not contain a valid QR code. Please try another image.")
            }
            .alert("Invalid UUID Format", isPresented: $store.showInvalidUUIDAlert.sending(\.showInvalidUUIDAlert)) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The clipboard content is not a valid UUID format.")
            }
            .alert("Camera Permission Denied", isPresented: $store.showPermissionDeniedAlert.sending(\.showPermissionDeniedAlert)) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Camera access is required to scan QR codes. Please enable camera access in Settings.")
            }
            .sheet(isPresented: $store.showAddContactSheet.sending(\.showAddContactSheet)) {
                addContactSheetView
            }
        }
    }

    // MARK: - Subviews

    /// The add contact sheet view
    private var addContactSheetView: some View {
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
                            Text(store.contact.phone.isEmpty ? "No phone number" : store.contact.phone)
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
                            Toggle(isOn: $store.contact.isResponder.sending(\.updateIsResponder)) {
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
                            Toggle(isOn: $store.contact.isDependent.sending(\.updateIsDependent)) {
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

                        // Note section - styled to match profile tab
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Emergency Note")
                                .font(.headline)

                            Text("This is the contact managed emergency note")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(store.contact.note.isEmpty ? "No emergency note provided" : store.contact.note)
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
            .alert(isPresented: $store.showErrorAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(store.errorMessage ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    /// The top controls view
    private var topControlsView: some View {
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
    private var bottomControlsView: some View {
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
    private var cameraView: some View {
        CameraPreviewView(torchOn: store.torchOn)
            .edgesIgnoringSafeArea(.all)
    }

    /// The camera failed view
    private var cameraFailedView: some View {
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
    private var manualEntryView: some View {
        NavigationStack {
            VStack(alignment: .center, spacing: 20) {
                Text("Enter QR Code ID")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 20)

                // Verification code style text field with paste button
                ZStack(alignment: .trailing) {
                    TextField("QR Code ID", text: $store.manualQRCode.sending(\.updateManualQRCode))
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
                        .onChange(of: store.manualQRCode) { oldValue, newValue in
                            // Limit to 36 characters (UUID format)
                            if newValue.count > 36 {
                                store.manualQRCode = String(newValue.prefix(36))
                            }
                        }

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

                // Add validation for QR code format
                let isValidFormat = isValidQRCodeFormat(store.manualQRCode)

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
                .background(store.manualQRCode.isEmpty || !isValidFormat ? Color.gray : Color.blue)
                .cornerRadius(12)
                .padding(.horizontal)
                .disabled(store.manualQRCode.isEmpty || !isValidFormat)

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

/// Preview provider for QRScannerView
struct QRScannerView_Previews: PreviewProvider {
    static var previews: some View {
        QRScannerView(store: Store(initialState: QRScannerFeature.State()) {
            QRScannerFeature()
        })
    }
}

// MARK: - Helper Functions
extension QRScannerView {
    /// Helper function to validate QR code format
    private func isValidQRCodeFormat(_ code: String) -> Bool {
        // Basic UUID validation
        return UUID(uuidString: code) != nil
    }
}
