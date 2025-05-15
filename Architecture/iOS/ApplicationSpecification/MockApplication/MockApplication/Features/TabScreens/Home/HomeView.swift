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
    @State private var showAlertToggleConfirmation = false
    @State private var pendingAlertToggleValue: Bool? = nil

    func generateQRCodeImage(completion: @escaping () -> Void = {}) {
        if isGeneratingImage { return }

        isImageReady = false
        isGeneratingImage = true
        let qrContent = userViewModel.qrCodeId
        let content = AnyView(
            QRCodeShareView(
                name: userViewModel.name,
                subtitle: "LifeSignal contact",
                qrCodeId: qrContent,
                footer: "Use LifeSignal's QR code scanner to add this contact"
            )
        )

        QRCodeViewModel.generateQRCodeImage(content: content) { image in
            qrCodeImage = image
            isImageReady = true
            isGeneratingImage = false
            completion()
        }
    }

    func shareQRCode() {
        if isImageReady, let image = qrCodeImage {
            shareImage = .qrCode(image)
        } else if !isGeneratingImage {
            generateQRCodeImage {
                if let image = self.qrCodeImage {
                    self.shareImage = .qrCode(image)
                }
            }
        }
    }

    func showQRCodeSheet() {
        // Show the QR code sheet using our new QRCodeSheetView
        let qrCodeSheetView = QRCodeSheetView(
            name: userViewModel.name,
            qrCodeId: userViewModel.qrCodeId,
            onDismiss: {}
        )

        // In a real app, we would present this as a sheet
        // For now, we'll just use the existing share functionality
        shareQRCode()
    }

    func formatInterval(_ interval: TimeInterval) -> String {
        return TimeFormatting.formatInterval(interval)
    }

    // MARK: - View Components

    private var qrCodeSection: some View {
        VStack(spacing: 8) {
            // QR Code Card with avatar above (overlapping, improved layout)
            // Use our new QRCodeCardView from the QRCodeSystem feature
            QRCodeCardView(
                name: userViewModel.name,
                subtitle: "LifeSignal contact",
                qrCodeId: userViewModel.qrCodeId,
                footer: "Your QR code is unique. If you share it with someone, they can scan it and add you as a contact"
            )
            .padding(EdgeInsets(top: 16, leading: 0, bottom: 0, trailing: 0))

            Button("Reset QR Code") {
                userViewModel.generateNewQRCode()
            }
            .foregroundColor(.blue)
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var addContactButton: some View {
        Button(action: {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        showQRScanner = true
                    }
                } else {
                    DispatchQueue.main.async {
                        showCameraDeniedAlert = true
                    }
                }
            }
        }) {
            Text("Add Contact")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
        .frame(width: 200)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 16)
    }

    private var checkInStatusSection: some View {
        HStack {
            Text("Check-in status")
                .foregroundColor(.primary)
            Spacer()
            Text("Active")
                .foregroundColor(.green)
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemGray5))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Section: Check-in Interval
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Button(action: {
                        showIntervalPicker = true
                    }) {
                        HStack {
                            Text("Check-in time interval")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(formatInterval(Double(userViewModel.checkInInterval * 3600)))")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity)
                        .background(Color(UIColor.systemGray5))
                        .cornerRadius(12)
                    }

                    Text("Time until your countdown expires and responders are notified if you don't check in.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .center)
            }

            // Section: Notifications
            VStack(alignment: .leading, spacing: 8) {
                Text("Check-in notification")
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .padding(.leading)
                Picker("Check-in notification", selection: $userViewModel.notificationLeadTime) {
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
            .onAppear {
                if ![30, 120].contains(userViewModel.notificationLeadTime) {
                    userViewModel.notificationLeadTime = 30
                }
            }

            // Section: Help/Instructions
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

            // Alert Toggle Row
            Button(action: {
                pendingAlertToggleValue = !userViewModel.sendAlertActive
                showAlertToggleConfirmation = true
            }) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 20))
                        .padding(.trailing, 4)
                    Text("Alert to responders")
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                    Spacer()
                    Text(userViewModel.sendAlertActive ? "Active" : "Inactive")
                        .foregroundColor(userViewModel.sendAlertActive ? .red : .secondary)
                        .fontWeight(userViewModel.sendAlertActive ? .semibold : .medium)
                }
                .frame(height: 35)
                .padding(.vertical, 12)
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                .background(
                    userViewModel.sendAlertActive ?
                        Color.red.opacity(0.15) :
                        Color(UIColor.systemGray5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(userViewModel.sendAlertActive ? Color.red.opacity(0.3) : Color.clear, lineWidth: 2)
                )
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
            .shadow(color: userViewModel.sendAlertActive ? Color.red.opacity(0.1) : Color.clear, radius: 4, x: 0, y: 2)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                qrCodeSection
                addContactButton
                checkInStatusSection
                settingsSection
            }
            .padding(.bottom, 60)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showQRScanner, onDismiss: {
            if let code = pendingScannedCode {
                newContact = Contact(
                    id: UUID().uuidString,
                    name: "Alex Morgan",
                    phone: "555-123-4567",
                    qrCodeId: code,
                    lastCheckIn: Date(),
                    note: "I frequently go hiking alone on weekends at Mount Ridge trails. If unresponsive, check the main trail parking lot for my blue Honda Civic (plate XYZ-123). I carry an emergency beacon in my red backpack. I have a peanut allergy and keep an EpiPen in my backpack.",
                    manualAlertActive: false,
                    isNonResponsive: false,
                    hasIncomingPing: false,
                    incomingPingTimestamp: nil,
                    isResponder: false,
                    isDependent: false
                )
                pendingScannedCode = nil
            }
        }) {
            // Use our new QRScannerView from the QRCodeSystem feature
            QRScannerView { result in
                pendingScannedCode = result
            }
        }
        .sheet(item: $newContact, onDismiss: { newContact = nil }) { contact in
            // Use our new AddContactSheetView from the QRCodeSystem feature
            AddContactSheetView(
                qrCodeId: contact.qrCodeId,
                onAddContact: { _ in
                    // Show alert after sheet closes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showContactAddedAlert = true
                    }
                },
                onClose: { newContact = nil }
            )
        }
        .sheet(isPresented: $showIntervalPicker) {
            IntervalPickerView(
                interval: Double(userViewModel.checkInInterval * 3600),
                onSave: { newInterval in
                    userViewModel.checkInInterval = Int(newInterval / 3600)
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showInstructions) {
            InstructionsView()
        }
        .sheet(item: $shareImage) { shareImageItem in
            ShareSheet(activityItems: [shareImageItem.image], title: "Share QR Code")
        }
        .onAppear {
            generateQRCodeImage()
        }
        .onChange(of: userViewModel.qrCodeId) { oldValue, newValue in
            generateQRCodeImage()
        }
        .alert(isPresented: $showCheckInConfirmation) {
            Alert(
                title: Text("Confirm Check-in"),
                message: Text("Are you sure you want to check in now? This will reset your timer."),
                primaryButton: .default(Text("Check In")) {
                    userViewModel.updateLastCheckedIn()
                },
                secondaryButton: .cancel()
            )
        }
        .alert(isPresented: $showCameraDeniedAlert) {
            Alert(
                title: Text("Camera Access Denied"),
                message: Text("Please enable camera access in Settings to scan QR codes."),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showContactAddedAlert) {
            Alert(
                title: Text("Contact Added"),
                message: Text("The contact was successfully added."),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showAlertToggleConfirmation) {
            Alert(
                title: Text(userViewModel.sendAlertActive ? "Deactivate Alert?" : "Send Alert?"),
                message: Text(userViewModel.sendAlertActive ? "Are you sure you want to deactivate the alert to responders?" : "Are you sure you want to send an alert to responders?"),
                primaryButton: .destructive(Text(userViewModel.sendAlertActive ? "Deactivate" : "Activate")) {
                    if let value = pendingAlertToggleValue {
                        userViewModel.sendAlertActive = value
                    }
                    pendingAlertToggleValue = nil
                },
                secondaryButton: .cancel {
                    pendingAlertToggleValue = nil
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    shareQRCode()
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }
}

// MARK: - Instructions
struct InstructionsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var userViewModel: UserViewModel
    @State private var showCheckInConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    instructionSection(
                        title: "Welcome to LifeSignal",
                        content: "LifeSignal helps you stay connected with your trusted contacts. It automatically notifies your responders if you don't check in within your specified time interval.",
                        icon: "app.badge.checkmark.fill"
                    )

                    instructionSection(
                        title: "Setting Up",
                        content: "1. Set your check-in interval in the Home tab\n2. Add responders by scanning their QR code\n3. Enable notifications to receive reminders before timeout",
                        icon: "gear"
                    )

                    instructionSection(
                        title: "Regular Check-ins",
                        content: "Remember to check in regularly by tapping the 'Check-In' tab in the navigation bar. This resets your timer and prevents notifications from being sent to your responders.",
                        icon: "clock.fill"
                    )

                    instructionSection(
                        title: "Adding Responders",
                        content: "Responders are people who will be notified if you don't check in. To add a responder:\n1. Go to the Responders tab\n2. Tap the QR code icon in the navigation bar\n3. Scan their QR code",
                        icon: "person.2.fill"
                    )

                    instructionSection(
                        title: "Adding Dependents",
                        content: "Dependents are people you're responsible for. You'll be notified if they don't check in. To add a dependent:\n1. Go to the Dependents tab\n2. Tap the QR code icon in the navigation bar\n3. Scan their QR code",
                        icon: "person.3.fill"
                    )

                    instructionSection(
                        title: "Notifications",
                        content: "You can choose to receive notifications:\n• 30 minutes before timeout\n• 2 hours before timeout\n\nThese help remind you to check in before your responders are alerted.",
                        icon: "bell.fill"
                    )

                    instructionSection(
                        title: "Privacy & Security",
                        content: "Your data is private and secure. Your location is never shared without your explicit permission. You can reset your QR code at any time from the Home screen.",
                        icon: "lock.shield.fill"
                    )
                }
                .padding()
            }
            .navigationTitle("Instructions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    private func instructionSection(title: String, content: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)

                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
            }

            Text(content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 10)
    }
}

// Using the enum HomeShareImage from the separate file
