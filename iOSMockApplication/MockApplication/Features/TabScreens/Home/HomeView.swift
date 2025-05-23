import SwiftUI
import Foundation
import UIKit
import AVFoundation
import PhotosUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // QR Code Section
                qrCodeSection

                // Settings Section
                settingsSection

                // Add extra padding at the bottom to ensure content doesn't overlap with tab bar
                Spacer()
                    .frame(height: 20)
            }
            .padding(.bottom, 50) // Add padding to ensure content doesn't overlap with tab bar
        }
        .background(Color(UIColor.systemGroupedBackground))
        .edgesIgnoringSafeArea(.bottom) // Extend background to bottom edge
        .navigationTitle("Home")
        .onAppear {
            // Generate QR code when the view appears
            viewModel.generateQRCode()
        }

        // QR Scanner Sheet
        .sheet(isPresented: $viewModel.showQRScanner) {
            QRScannerView()
        }

        // Interval Picker Sheet
        .sheet(isPresented: $viewModel.showIntervalPicker) {
            intervalPickerView()
            .presentationDetents([.medium])
        }

        // Instructions Sheet
        .sheet(isPresented: $viewModel.showInstructions) {
            instructionsView
        }

        // Share Sheet
        .sheet(isPresented: $viewModel.showShareSheet) {
            if let shareImage = viewModel.shareableImage {
                ActivityShareSheet(items: ["My LifeSignal QR Code", shareImage])
            }
        }



        // Notification Setting Change Alert
        .alert("Change Notification Setting?", isPresented: $viewModel.showIntervalChangeConfirmation) {
            Button("Cancel", role: .cancel) {
                viewModel.pendingIntervalChange = nil
            }
            Button("Change") {
                if let interval = viewModel.pendingIntervalChange {
                    switch Int(interval) {
                    case 0: // Disabled
                        viewModel.updateNotificationSettings(enabled: false, notify30Min: false, notify2Hours: false)
                    case 30: // 30 minutes
                        viewModel.updateNotificationSettings(enabled: true, notify30Min: true, notify2Hours: false)
                    case 120: // 2 hours
                        viewModel.updateNotificationSettings(enabled: true, notify30Min: false, notify2Hours: true)
                    default:
                        break
                    }
                    viewModel.pendingIntervalChange = nil
                }
            }
        } message: {
            if let interval = viewModel.pendingIntervalChange {
                switch Int(interval) {
                case 0:
                    Text("Are you sure you want to disable check-in notifications?")
                case 30:
                    Text("You'll be notified 30 minutes before your check-in expires. Is this correct?")
                case 120:
                    Text("You'll be notified 2 hours before your check-in expires. Is this correct?")
                default:
                    Text("Are you sure you want to change your notification setting?")
                }
            } else {
                Text("Are you sure you want to change your notification setting?")
            }
        }

        // Contact Added Alert - Removed as NotificationManager already shows a silent notification
        // .alert("Contact Added", isPresented: $viewModel.showContactAddedAlert) {
        //     Button("OK", role: .cancel) { }
        // } message: {
        //     Text("New responder has been added to your contacts.")
        // }

        // Camera Access Denied Alert
        .alert("Camera Access Denied", isPresented: $viewModel.showCameraDeniedAlert) {
            Button("OK", role: .cancel) { }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Please allow camera access in Settings to scan QR codes.")
        }

        // Reset QR Code Confirmation Alert
        .alert("Reset QR Code", isPresented: $viewModel.showResetQRConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset") {
                viewModel.resetQRCode()
            }
        } message: {
            Text("Are you sure you want to reset your QR code? This will invalidate any previously shared QR codes.")
        }
    }

    // MARK: - Instructions View

    private var instructionsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("How to use LifeSignal")
                .font(.title)
                .fontWeight(.bold)
                .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 15) {
                instructionItem(
                    number: "1",
                    title: "Set your interval",
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
                HapticFeedback.triggerHaptic()
                viewModel.showInstructions = false
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

    // MARK: - Interval Picker View

    private func intervalPickerView() -> some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Unit", selection: $viewModel.intervalPickerUnit) {
                        Text("Days").tag("days")
                        Text("Hours").tag("hours")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: viewModel.intervalPickerUnit) { oldUnit, newUnit in
                        viewModel.updateIntervalPickerUnit(newUnit)
                    }

                    Picker("Value", selection: $viewModel.intervalPickerValue) {
                        if viewModel.isDayUnit {
                            ForEach(viewModel.dayValues, id: \.self) { day in
                                Text("\(day) day\(day > 1 ? "s" : "")").tag(day)
                            }
                        } else {
                            ForEach(viewModel.hourValues, id: \.self) { hour in
                                Text("\(hour) hours").tag(hour)
                            }
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 150)
                    .clipped()
                    .onChange(of: viewModel.intervalPickerValue) { _, _ in
                        HapticFeedback.selectionFeedback()
                    }
                }
            }
            .navigationTitle("Interval")
            .navigationBarItems(
                trailing: Button("Save") {
                    HapticFeedback.notificationFeedback(type: .success)
                    viewModel.updateCheckInInterval(viewModel.getComputedIntervalInSeconds())
                    viewModel.showIntervalPicker = false
                }
            )
        }
    }

    // MARK: - QR Code Section

    private var qrCodeSection: some View {
        VStack(spacing: 16) {
            // QR Code Card
            qrCodeCard

            // Action Buttons
            HStack(spacing: 12) {
                // Reset QR Code Button
                qrCodeActionButton(
                    icon: "arrow.triangle.2.circlepath",
                    label: "Reset QR",
                    action: {
                        HapticFeedback.triggerHaptic()
                        viewModel.showResetQRConfirmation = true
                    }
                )

                // Share QR Button
                qrCodeActionButton(
                    icon: "square.and.arrow.up",
                    label: "Share QR",
                    action: {
                        HapticFeedback.triggerHaptic()
                        viewModel.generateShareableQRCode {
                            viewModel.showShareSheet = true
                        }
                    }
                )

                // Scan QR Button
                qrCodeActionButton(
                    icon: "qrcode.viewfinder",
                    label: "Scan QR",
                    action: {
                        HapticFeedback.triggerHaptic()
                        viewModel.showQRScanner = true
                    }
                )
            }
            .padding(.horizontal, 16)
        }
    }

    private var qrCodeCard: some View {
        HStack(alignment: .top, spacing: 16) {
            // QR Code
            ZStack {
                if viewModel.isQRCodeReady, let qrImage = viewModel.qrCodeImage {
                    Image(uiImage: qrImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 130, height: 130)
                } else {
                    ProgressView()
                        .frame(width: 130, height: 130)
                }
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.15),
                    radius: 4,
                    x: 0,
                    y: 2)
            .environment(\.colorScheme, .light) // Force light mode for QR code

            // Info and button
            VStack(alignment: .leading, spacing: 10) {
                Text("Your QR Code")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Share this QR code with others to add contacts.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)

                // Copy ID button
                Button(action: {
                    HapticFeedback.lightImpact()
                    UIPasteboard.general.string = viewModel.qrCodeId
                    HapticFeedback.notificationFeedback(type: .success)
                    NotificationManager.shared.showQRCodeCopiedNotification()
                }) {
                    Label("Copy ID", systemImage: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(Color(UIColor.tertiarySystemGroupedBackground))
                        .cornerRadius(10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func qrCodeActionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(label)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .foregroundColor(.primary)
            .cornerRadius(12)
        }
    }



    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Check-in Interval
            checkInIntervalSection

            // Notifications
            notificationsSection

            // Help/Instructions
            helpSection
        }
    }

    private var checkInIntervalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Check-in interval")
                .foregroundColor(.primary)
                .padding(.horizontal)

            Button(action: {
                HapticFeedback.triggerHaptic()
                viewModel.showIntervalPicker = true
            }) {
                HStack {
                    Text(viewModel.formatInterval(viewModel.checkInInterval))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)

            Text("This is how long before your contacts are alerted if you don't check in.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Check-in notification")
                .foregroundColor(.primary)
                .padding(.horizontal)

            Picker("Check-in notification", selection: Binding(
                get: {
                    if !viewModel.notificationsEnabled {
                        return 0
                    } else if viewModel.notify2HoursBefore {
                        return 120
                    } else {
                        return 30
                    }
                },
                set: { newValue in
                    viewModel.pendingIntervalChange = TimeInterval(newValue)
                    HapticFeedback.selectionFeedback()
                    viewModel.showIntervalChangeConfirmation = true
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
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                HapticFeedback.triggerHaptic()
                viewModel.showInstructions = true
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
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
}
