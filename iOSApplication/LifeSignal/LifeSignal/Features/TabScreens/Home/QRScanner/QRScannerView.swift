import SwiftUI
import PhotosUI
import AVFoundation
import ComposableArchitecture
import Perception

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
            .sheet(isPresented: Binding(
                get: { store.isShowingManualEntry },
                set: { store.send(.toggleManualEntry($0)) }
            )) {
                manualEntryView
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
    private var manualEntryView: some View {
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

                // Add validation for QR code format
                let isValidFormat = store.isValidManualQRCode

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
