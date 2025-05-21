import SwiftUI
import PhotosUI
import AVFoundation

/// A SwiftUI view for scanning QR codes
struct QRScannerView: View {
    // MARK: - Properties

    /// The view model for the QR scanner
    @StateObject var viewModel = QRScannerViewModel()

    // MARK: - Body

    var body: some View {
        ZStack {
            // Camera view or camera failed view
            if viewModel.cameraLoadFailed {
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
            // Initialize the camera
            viewModel.initializeCamera()
        }
        .sheet(isPresented: $viewModel.isShowingManualEntry) {
            manualEntryView
        }
        .sheet(isPresented: $viewModel.isShowingGallery) {
            PhotoPickerView(viewModel: viewModel)
        }
        .alert("No QR Code Found", isPresented: $viewModel.showNoQRCodeAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The selected image does not contain a valid QR code. Please try another image.")
        }
        .alert("Invalid UUID Format", isPresented: $viewModel.showInvalidUUIDAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The clipboard content is not a valid UUID format.")
        }
        .sheet(isPresented: $viewModel.showAddContactSheet) {
            addContactSheetView
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
                                    Text(String(viewModel.contact.name.isEmpty ? "?" : viewModel.contact.name.prefix(1)))
                                        .foregroundColor(.blue)
                                        .font(.title)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.blue, lineWidth: 2)
                                )

                            // Name field - now non-editable
                            Text(viewModel.contact.name.isEmpty ? "Unknown" : viewModel.contact.name)
                            .font(.title3)
                            .multilineTextAlignment(.center)

                            // Phone field - now non-editable
                            Text(viewModel.contact.phone.isEmpty ? "No phone number" : viewModel.contact.phone)
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
                                get: { self.viewModel.contact.isResponder },
                                set: {
                                    HapticFeedback.selectionFeedback()
                                    self.viewModel.updateIsResponder($0)
                                }
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
                                get: { self.viewModel.contact.isDependent },
                                set: {
                                    HapticFeedback.selectionFeedback()
                                    self.viewModel.updateIsDependent($0)
                                }
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

                        // Note section - styled to match profile tab
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Emergency Note")
                                .font(.headline)

                            Text("This is the contact managed emergency note")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(viewModel.contact.note.isEmpty ? "No emergency note provided" : viewModel.contact.note)
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
                        viewModel.closeAddContactSheet()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        HapticFeedback.notificationFeedback(type: .success)
                        viewModel.addContact()
                    }
                    .disabled(viewModel.contact.name.isEmpty || (!viewModel.contact.isResponder && !viewModel.contact.isDependent))
                }
            }
            .alert(isPresented: $viewModel.showErrorAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(viewModel.errorMessage ?? "An unknown error occurred"),
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
                viewModel.dismissScanner()
            }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
            }

            Spacer()

            // Torch button
            Button(action: {
                viewModel.toggleTorch()
            }) {
                Image(systemName: viewModel.torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                    .font(.title2)
                    .foregroundColor(viewModel.torchOn ? .yellow : .white)
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
                    ForEach(0..<viewModel.galleryThumbnails.count, id: \.self) { index in
                        Button(action: {
                            HapticFeedback.lightImpact()
                            viewModel.processGalleryImage(at: index)
                        }) {
                            Image(uiImage: viewModel.galleryThumbnails[index])
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
                    HapticFeedback.triggerHaptic()
                    viewModel.isShowingManualEntry = true
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
                    HapticFeedback.triggerHaptic()
                    viewModel.isShowingGallery = true
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
        CameraPreviewView(torchOn: viewModel.torchOn)
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
                    HapticFeedback.triggerHaptic()
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
                    HapticFeedback.triggerHaptic()
                    viewModel.isShowingGallery = true
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
                    TextField("QR Code ID", text: $viewModel.manualQRCode)
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
                        .onChange(of: viewModel.manualQRCode) { oldValue, newValue in
                            // Limit to 36 characters (UUID format)
                            if newValue.count > 36 {
                                viewModel.manualQRCode = String(newValue.prefix(36))
                            }
                        }

                    // Paste button that only shows when text field is empty
                    if viewModel.manualQRCode.isEmpty {
                        Button(action: {
                            viewModel.handlePasteButtonTapped()
                        }) {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(.blue)
                                .padding(.trailing, 16)
                        }
                    }
                }
                .padding(.horizontal)

                // Add validation for QR code format
                let isValidFormat = viewModel.isValidQRCodeFormat(viewModel.manualQRCode)

                // Verify button style
                Button(action: {
                    viewModel.submitManualQRCode()
                }) {
                    Text("Add Contact")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .background(viewModel.manualQRCode.isEmpty || !isValidFormat ? Color.gray : Color.blue)
                .cornerRadius(12)
                .padding(.horizontal)
                .disabled(viewModel.manualQRCode.isEmpty || !isValidFormat)

                Spacer()
            }
            .padding()
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitle("Manual Entry", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                viewModel.cancelManualEntry()
            })
        }
    }
}

/// Preview provider for QRScannerView
struct QRScannerView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a view with a custom view model for preview purposes
        QRScannerView()
            .onAppear {
                // In a real implementation, the presenting view would set the onScanComplete callback
                // This is just an example of how to set it
            }
    }
}
