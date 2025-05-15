import SwiftUI
import Foundation
import UIKit
import AVFoundation

// Import QRCodeSystem components
import PhotosUI

struct HomeView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @State private var showQRScanner = false
    @State private var showIntervalPicker = false
    @State private var showInstructions = false
    @State private var showCheckInConfirmation = false
    @State private var showShareSheet = false
    @State private var qrCodeImage: UIImage? = nil
    @State private var isImageReady = false
    @State private var isGeneratingImage = false
    @State private var showCameraDeniedAlert = false
    @State private var newContact: Contact? = nil
    @State private var pendingScannedCode: String? = nil
    @State private var shareImage: HomeShareImage? = nil
    @State private var showContactAddedAlert = false

    func generateQRCodeImage(completion: @escaping () -> Void = {}) {
        if isGeneratingImage { return }

        isImageReady = false
        isGeneratingImage = true

        DispatchQueue.global(qos: .userInitiated).async {
            // Generate QR code image
            if let qrImage = generateQRCode(from: userViewModel.qrCodeId) {
                DispatchQueue.main.async {
                    self.qrCodeImage = qrImage
                    self.isImageReady = true
                    self.isGeneratingImage = false
                    completion()
                }
            } else {
                DispatchQueue.main.async {
                    self.isGeneratingImage = false
                    // Handle error
                }
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // QR Code Section
                qrCodeSection

                // Settings Section
                settingsSection
            }
            .padding(.vertical)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            generateQRCodeImage()
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerView(onScanned: { code in
                pendingScannedCode = code
                showQRScanner = false
                // Process scanned code
                if let code = pendingScannedCode {
                    newContact = Contact(
                        id: UUID().uuidString,
                        name: "New Contact",
                        phone: "",
                        qrCodeId: code,
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
                    showContactAddedAlert = true
                }
            })
        }
        .sheet(isPresented: $showIntervalPicker) {
            IntervalPickerView(
                interval: userViewModel.checkInInterval,
                onSave: { interval in
                    userViewModel.checkInInterval = interval
                    showIntervalPicker = false
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showInstructions) {
            VStack(alignment: .leading, spacing: 20) {
                Text("How to use LifeSignal")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)

                VStack(alignment: .leading, spacing: 15) {
                    instructionItem(
                        number: "1",
                        title: "Set your check-in interval",
                        description: "Choose how often you need to check in. This is the maximum time before your contacts are alerted if you don't check in."
                    )

                    instructionItem(
                        number: "2",
                        title: "Add responders",
                        description: "Share your QR code with trusted contacts who will respond if you need help. They'll be notified if you miss a check-in."
                    )

                    instructionItem(
                        number: "3",
                        title: "Check in regularly",
                        description: "Tap the check-in button before your timer expires. This resets your countdown and lets your contacts know you're safe."
                    )

                    instructionItem(
                        number: "4",
                        title: "Emergency alert",
                        description: "If you need immediate help, activate the alert to notify all your responders instantly."
                    )
                }

                Spacer()

                Button(action: {
                    showInstructions = false
                }) {
                    Text("Got it")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.top)
            }
            .padding()
        }
        .alert("Contact Added", isPresented: $showContactAddedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("New responder has been added to your contacts.")
        }
        .alert("Camera Access Denied", isPresented: $showCameraDeniedAlert) {
            Button("OK", role: .cancel) { }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Please allow camera access in Settings to scan QR codes.")
        }

        .sheet(isPresented: $showShareSheet) {
            if let shareImage = shareImage {
                // Add a descriptive text along with the image
                let text = "My LifeSignal QR Code"
                ShareSheet(items: [text, shareImage.image])
            }
        }
    }

    // Generate a QR code from a string
    private func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: .utf8)
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            filter.setValue("H", forKey: "inputCorrectionLevel")
            if let ciImage = filter.outputImage {
                let transform = CGAffineTransform(scaleX: 10, y: 10)
                let scaledCIImage = ciImage.transformed(by: transform)
                let context = CIContext()
                if let cgImage = context.createCGImage(scaledCIImage, from: scaledCIImage.extent) {
                    return UIImage(cgImage: cgImage)
                }
            }
        }
        return nil
    }

    // Format an interval for display
    private func formatInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        let days = hours / 24

        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s")"
        } else {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
    }

    // Break up the complex expression into smaller parts
    private var settingsSection: some View {
        settingsSectionContent
    }

    private var settingsSectionContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Section: Check-in Interval
            checkInIntervalSection

            // Section: Notifications
            notificationsSection

            // Section: Help/Instructions
            helpSection
        }
    }

    private var checkInIntervalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Check-in interval")
                .foregroundColor(.primary)
                .padding(.horizontal)
                .padding(.leading)

            Button(action: {
                showIntervalPicker = true
            }) {
                HStack {
                    Text(formatInterval(userViewModel.checkInInterval))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemGray5))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)

            Text("This is how long before your contacts are alerted if you don't check in.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Check-in notification")
                .foregroundColor(.primary)
                .padding(.horizontal)
                .padding(.leading)
            Picker("Check-in notification", selection: Binding(
                get: {
                    if !userViewModel.notificationsEnabled {
                        return 0
                    } else if userViewModel.notify2HoursBefore {
                        return 120
                    } else {
                        return 30
                    }
                },
                set: { newValue in
                    switch newValue {
                    case 0: // Disabled
                        userViewModel.notificationsEnabled = false
                    case 30: // 30 minutes
                        userViewModel.notificationsEnabled = true
                        userViewModel.notify30MinBefore = true
                        userViewModel.notify2HoursBefore = false
                    case 120: // 2 hours
                        userViewModel.notificationsEnabled = true
                        userViewModel.notify30MinBefore = false
                        userViewModel.notify2HoursBefore = true
                    default:
                        break
                    }
                }
            )) {
                Text("Disabled").tag(0)
                Text("30 mins").tag(30)
                Text("2 hours").tag(120)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            Text("Choose when you'd like to be reminded before your countdown expires.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        // No onAppear needed
    }

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                showInstructions = true
            }) {
                HStack {
                    Text("Review instructions")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemGray5))
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }

    private var qrCodeSection: some View {
        VStack(spacing: 16) {
            // QR Code Card
            VStack(spacing: 16) {
                if isImageReady, let qrImage = qrCodeImage {
                    Image(uiImage: qrImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                } else {
                    ProgressView()
                        .frame(width: 200, height: 200)
                }

                Text("Your LifeSignal QR Code")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Share this with trusted contacts who will respond if you need help")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            .padding(.horizontal)

            // Action Buttons - Standardized sizing and padding
            HStack(spacing: 12) {
                // Scan QR Button
                Button(action: {
                    showQRScanner = true
                }) {
                    VStack(spacing: 8) { // Standardized spacing
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 24))
                        Text("Scan QR")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 80) // Standardized height
                    .background(Color(UIColor.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }

                // Share QR Button
                Button(action: {
                    // Always generate a fresh QR code image before showing the share sheet
                    // This ensures the image is ready when the sheet appears
                    generateQRCodeImage {
                        if let qrImage = self.qrCodeImage, let cgImage = qrImage.cgImage {
                            let copy = UIImage(cgImage: cgImage)
                            self.shareImage = .qrCode(copy)
                            self.showShareSheet = true
                        }
                    }
                }) {
                    VStack(spacing: 8) { // Standardized spacing
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 24))
                        Text("Share QR")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 80) // Standardized height
                    .background(Color(UIColor.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }

                // Notification Center Button
                NavigationLink(destination: NotificationCenterView()) {
                    VStack(spacing: 8) { // Standardized spacing
                        Image(systemName: "bell.square")
                            .font(.system(size: 24))
                        Text("Notifications")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 80) // Standardized height
                    .background(Color(UIColor.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16) // Standardized padding
        }
    }

    private func instructionItem(number: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Text(number)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Color.blue)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 10)
    }
}

// Using the enum HomeShareImage from the separate file
