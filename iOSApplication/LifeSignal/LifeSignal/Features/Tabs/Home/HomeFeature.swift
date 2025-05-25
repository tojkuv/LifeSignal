import SwiftUI
import Foundation
import UIKit
@preconcurrency import AVFoundation
import PhotosUI
import ComposableArchitecture
import Perception

// Define Alert enum outside of the feature to avoid circular dependencies
enum HomeAlert: Equatable {
    case cameraDenied
    case contactAdded(Contact)
    case resetQRConfirmation
    case intervalChangeConfirmation(TimeInterval)
}

/// Home Feature - QR code generation and settings management using TCA
@Reducer
struct HomeFeature {
    /// Home state conforming to TCA patterns
    @ObservableState
    struct State: Equatable {
        // User Data
        @Shared(.currentUser) var currentUser: User? = nil

        // QR Code Properties
        var qrCodeImage: UIImage? = nil
        var isQRCodeReady: Bool = false
        var isGeneratingQRCode: Bool = false
        var shareableImage: UIImage? = nil

        // UI State Properties
        @Presents var qrScanner: QRScannerFeature.State?
        var showQRScanner: Bool = false
        var showIntervalPicker: Bool = false
        var showInstructions: Bool = false
        @Presents var qrShareSheet: QRCodeShareSheetFeature.State?
        @Presents var alert: AlertState<HomeAlert>?
        var showShareSheet: Bool = false
        var showIntervalChangeConfirmation: Bool = false
        var showCameraDeniedAlert: Bool = false
        var showResetQRConfirmation: Bool = false

        // Interval Picker Properties
        var intervalPickerUnit: String = "days"
        var intervalPickerValue: Int = 1
        var pendingIntervalChange: TimeInterval? = nil

        // Contact Properties
        var pendingScannedCode: String? = nil
        var newContact: Contact? = nil

        /// Available day values for the interval picker
        var dayValues: [Int] { Array(1...7) }

        /// Available hour values for the interval picker
        var hourValues: [Int] { [8, 16, 32] }

        /// Check if the current unit is days
        var isDayUnit: Bool { intervalPickerUnit == "days" }

        /// Initialize with default values and load persisted data
        init() {
            // Default initialization - actual data loading will be handled in effects
        }
    }

    /// Home actions representing events that can occur
    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        // Lifecycle
        case onAppear
        case loadUser
        case userLoaded(User)

        // QR Code core functionality
        case generateQRCode
        case qrCodeGenerated(UIImage?)
        case resetQRCode
        case copyQRCodeId
        case generateShareableQRCode
        case shareableQRCodeGenerated(UIImage?)
        case shareQRCode

        // QR Code UI navigation
        case showQRScanner
        case hideQRScanner
        case showQRShareSheet
        case hideQRShareSheet
        case qrScanner(PresentationAction<QRScannerFeature.Action>)
        case qrShareSheet(PresentationAction<QRCodeShareSheetFeature.Action>)

        // Check-in interval management
        case updateCheckInInterval(TimeInterval)
        case initializeIntervalPicker
        case updateIntervalPickerUnit(String)
        case updateIntervalPickerValue(Int)
        case confirmIntervalChange
        case cancelIntervalChange

        // Notification settings
        case updateNotificationSettings(enabled: Bool, notify30Min: Bool, notify2Hours: Bool)

        // Contact management
        case createContactFromQRCode(String)
        case contactCreated(Contact)
        case setPendingScannedCode(String?)

        // UI state management
        case setShowIntervalPicker(Bool)
        case setShowInstructions(Bool)
        case setShowShareSheet(Bool)
        case setShowQRScanner(Bool)
        case setShowResetQRConfirmation(Bool)
        case setPendingIntervalChange(TimeInterval)
        case setShowIntervalChangeConfirmation(Bool)
        case setShowCameraDeniedAlert(Bool)
        case alert(PresentationAction<HomeAlert>)

        // Internal/private actions
        case _qrCodeGenerationStarted
        case _qrCodeGenerationCompleted
        case _shareableQRCodeGenerationStarted
        case _shareableQRCodeGenerationCompleted
    }

    /// Dependencies for the Home feature
    @Dependency(\.userClient) var userClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.hapticClient) var haptics

    /// Home reducer body implementing business logic
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce<State, Action> { state, action in
            switch action {
            case .binding:
                return .none
                
            case .onAppear:
                return .send(.loadUser)

            case .loadUser:
                return .run { send in
                    if let user = await userClient.getCurrentUser() {
                        await send(.userLoaded(user))
                    }
                }

            case let .userLoaded(user):
                state.$currentUser.withLock { $0 = user }
                return .merge(
                    .send(.initializeIntervalPicker),
                    .send(.generateQRCode)
                )

            case .generateQRCode:
                state.isQRCodeReady = false
                return .run { send in
                    await send(._qrCodeGenerationStarted)
                    do {
                        let image = try await userClient.getQRCodeImage(300)
                        await send(.qrCodeGenerated(image))
                    } catch {
                        // Handle QR code generation error
                        await send(.qrCodeGenerated(nil))
                    }
                }

            case ._qrCodeGenerationStarted:
                state.isGeneratingQRCode = true
                return .none

            case let .qrCodeGenerated(image):
                state.qrCodeImage = image
                state.isQRCodeReady = image != nil
                state.isGeneratingQRCode = false
                return .none

            case .resetQRCode:
                state.alert = AlertState {
                    TextState("Reset QR Code")
                } actions: {
                    ButtonState(role: .destructive, action: .resetQRConfirmation) {
                        TextState("Reset")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("This will invalidate your current QR code. Existing contacts will need to scan your new code.")
                }
                return .none

            case .generateShareableQRCode:
                guard !state.isGeneratingQRCode else { 
                    return .send(.shareableQRCodeGenerated(nil))
                }

                return .run { send in
                    await send(._shareableQRCodeGenerationStarted)
                    do {
                        let shareableImage = try await userClient.getShareableQRCodeImage()
                        await send(.shareableQRCodeGenerated(shareableImage))
                    } catch {
                        // Handle shareable QR code generation error
                        await send(.shareableQRCodeGenerated(nil))
                    }
                }

            case ._shareableQRCodeGenerationStarted:
                state.isGeneratingQRCode = true
                return .none

            case let .shareableQRCodeGenerated(image):
                state.shareableImage = image
                state.isGeneratingQRCode = false
                return .none

            case .shareQRCode:
                if state.shareableImage != nil {
                    return .send(.showQRShareSheet)
                } else {
                    return .merge(
                        .send(.generateShareableQRCode),
                        .run { send in
                            // Wait for generation to complete, then show share sheet
                            try await Task.sleep(for: .milliseconds(100))
                            await send(.showQRShareSheet)
                        }
                    )
                }

            case let .updateCheckInInterval(interval):
                return .run { send in
                    do {
                        let updatedUser = try await userClient.updateCheckInInterval(interval)
                        await send(.initializeIntervalPicker)
                    } catch {
                        // Error handling if needed
                    }
                }

            case .initializeIntervalPicker:
                let interval = state.currentUser?.checkInInterval ?? 86400
                if interval.truncatingRemainder(dividingBy: 86400) == 0,
                   (1...7).contains(Int(interval / 86400)) {
                    state.intervalPickerUnit = "days"
                    state.intervalPickerValue = Int(interval / 86400)
                } else if interval.truncatingRemainder(dividingBy: 3600) == 0,
                          state.hourValues.contains(Int(interval / 3600)) {
                    state.intervalPickerUnit = "hours"
                    state.intervalPickerValue = Int(interval / 3600)
                } else {
                    // Default to 1 day
                    state.intervalPickerUnit = "days"
                    state.intervalPickerValue = 1
                }
                return .none

            case let .updateIntervalPickerUnit(newUnit):
                state.intervalPickerUnit = newUnit

                // Set default values based on unit
                if newUnit == "days" {
                    state.intervalPickerValue = 1
                } else {
                    state.intervalPickerValue = 8
                }

                return .run { send in
                    await haptics.selection()
                }

            case let .updateIntervalPickerValue(value):
                state.intervalPickerValue = value
                return .none

            case .confirmIntervalChange:
                let newInterval: TimeInterval
                if state.intervalPickerUnit == "days" {
                    newInterval = TimeInterval(state.intervalPickerValue * 86400)
                } else {
                    newInterval = TimeInterval(state.intervalPickerValue * 3600)
                }
                state.pendingIntervalChange = newInterval
                let intervalText = state.formatInterval(newInterval)
                state.alert = AlertState {
                    TextState("Update Check-In Interval")
                } actions: {
                    ButtonState(action: .intervalChangeConfirmation(newInterval)) {
                        TextState("Update")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("Change check-in interval to \(intervalText)?")
                }
                return .none

            case .cancelIntervalChange:
                state.pendingIntervalChange = nil
                state.alert = nil
                state.showIntervalPicker = false
                return .send(.initializeIntervalPicker)

            case let .updateNotificationSettings(enabled, notify30Min, notify2Hours):
                return .run { send in
                    do {
                        let updatedUser = try await userClient.updateNotificationSettings(enabled, notify30Min, notify2Hours)
                        let notification = NotificationItem(
                            type: .system,
                            title: "Notification Settings Updated",
                            message: "Your notification settings have been successfully updated."
                        )
                        try? await notificationClient.sendNotification(notification)
                    } catch {
                        // Error handling if needed
                    }
                }

            // UI State actions
            case .showQRScanner:
                state.qrScanner = QRScannerFeature.State()
                return .none

            case .hideQRScanner:
                state.qrScanner = nil
                return .none

            case .showQRShareSheet:
                if let qrImage = state.qrCodeImage, let user = state.currentUser {
                    state.qrShareSheet = QRCodeShareSheetFeature.State(
                        qrCodeId: user.qrCodeId.uuidString,
                        qrCodeImage: qrImage
                    )
                }
                return .none

            case .hideQRShareSheet:
                state.qrShareSheet = nil
                return .none

            case .qrScanner(.dismiss):
                state.qrScanner = nil
                return .none

            case .qrShareSheet(.dismiss):
                state.qrShareSheet = nil
                return .none

            case .qrScanner(.presented(_)), .qrShareSheet(.presented(_)):
                return .none

            case let .setShowIntervalPicker(show):
                state.showIntervalPicker = show
                return .run { send in
                    await haptics.impact(.medium)
                }

            case let .setShowInstructions(show):
                state.showInstructions = show
                return .run { send in
                    await haptics.impact(.medium)
                }

            case let .setShowShareSheet(show):
                state.showShareSheet = show
                return .none
                
            case let .setShowResetQRConfirmation(show):
                if show {
                    state.alert = AlertState {
                        TextState("Reset QR Code")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("Cancel")
                        }
                    }
                } else {
                    state.alert = nil
                }
                return .none
                
            case let .setPendingIntervalChange(interval):
                state.pendingIntervalChange = interval
                return .none
                
            case let .setShowIntervalChangeConfirmation(show):
                if show, let interval = state.pendingIntervalChange {
                    let intervalText = state.formatInterval(interval)
                    state.alert = AlertState {
                        TextState("Change check-in interval to \(intervalText)?")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("Cancel")
                        }
                    }
                } else {
                    state.alert = nil
                }
                return .none
                
            case let .setShowQRScanner(show):
                state.showQRScanner = show
                return .none
                
            case let .setShowCameraDeniedAlert(show):
                state.showCameraDeniedAlert = show
                return .none

            case .alert(.presented(.resetQRConfirmation)):
                state.shareableImage = nil

                return .run { send in
                    do {
                        let updatedUser = try await userClient.regenerateQRCode()
                        // Clear cached QR image to force regeneration
                        _ = try await userClient.refreshQRCodeImage()
                        let notification = NotificationItem(
                            type: .system,
                            title: "QR Code Reset",
                            message: "Your QR code has been reset. Previous QR codes are no longer valid."
                        )
                        try? await notificationClient.sendNotification(notification)
                        await send(.generateQRCode)
                    } catch {
                        // Error handling if needed
                    }
                }

            case let .alert(.presented(.intervalChangeConfirmation(interval))):
                state.showIntervalPicker = false
                return .send(.updateCheckInInterval(interval))

            case .alert(.presented(.cameraDenied)):
                return .none

            case .alert(.presented(.contactAdded(_))):
                // Handle contact added confirmation if needed
                return .none

            case .alert:
                return .none

            case .createContactFromQRCode(_):
                let contact = Contact(
                    id: UUID(),
                    name: "New Contact",
                    phoneNumber: "",
                    isResponder: true,
                    isDependent: false,
                    lastUpdated: Date(),
                    emergencyNote: "",
                    lastCheckInTime: Date(),
                    interval: 24 * 60 * 60,
                    hasIncomingPing: false,
                    hasOutgoingPing: false,
                    manualAlertActive: false,
                    incomingPingTimestamp: nil,
                    outgoingPingTimestamp: nil,
                    manualAlertTimestamp: nil
                )
                return .send(.contactCreated(contact))

            case let .contactCreated(contact):
                state.newContact = contact
                state.alert = AlertState {
                    TextState("Contact Added")
                } actions: {
                    ButtonState(role: .cancel, action: .contactAdded(contact)) {
                        TextState("OK")
                    }
                } message: {
                    TextState("\(contact.name) has been added to your contacts.")
                }
                return .none

            case let .setPendingScannedCode(code):
                state.pendingScannedCode = code
                return .none

            case .copyQRCodeId:
                return .run { [qrCodeId = state.currentUser?.qrCodeId.uuidString ?? ""] send in
                    UIPasteboard.general.string = qrCodeId
                    await haptics.notification(.success)
                    let notification = NotificationItem(
                        type: .system,
                        title: "QR Code ID Copied",
                        message: "Your QR code ID has been copied to the clipboard."
                    )
                    try? await notificationClient.sendNotification(notification)
                }

            case ._qrCodeGenerationCompleted, ._shareableQRCodeGenerationCompleted:
                return .none
            }
        }
        .ifLet(\.$qrScanner, action: \.qrScanner) {
            QRScannerFeature()
        }
        .ifLet(\.$qrShareSheet, action: \.qrShareSheet) {
            QRCodeShareSheetFeature()
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

// MARK: - Helper Extensions

extension HomeFeature.State {
    /// Get the computed interval in seconds from picker values
    func getComputedIntervalInSeconds() -> TimeInterval {
        if intervalPickerUnit == "days" {
            return TimeInterval(intervalPickerValue * 86400)
        } else {
            return TimeInterval(intervalPickerValue * 3600)
        }
    }

    /// Format an interval for display
    func formatInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)

        // Special case for our specific hour values
        if hourValues.contains(hours) {
            return "\(hours) hours"
        }

        // For other values, use standard formatting
        let days = hours / 24
        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s")"
        } else {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
    }
}

// MARK: - Separate View Components

struct IntervalPickerView: View {
    @Bindable var store: StoreOf<HomeFeature>
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Unit", selection: $store.intervalPickerUnit) {
                        Text("Days").tag("days")
                        Text("Hours").tag("hours")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: store.intervalPickerUnit) { oldUnit, newUnit in
                        store.send(.updateIntervalPickerUnit(newUnit))
                    }

                    Picker("Value", selection: $store.intervalPickerValue) {
                        if store.isDayUnit {
                            ForEach(store.dayValues, id: \.self) { day in
                                Text("\(day) day\(day > 1 ? "s" : "")").tag(day)
                            }
                        } else {
                            ForEach(store.hourValues, id: \.self) { hour in
                                Text("\(hour) hours").tag(hour)
                            }
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 150)
                    .clipped()
                    .onChange(of: store.intervalPickerValue) { _, _ in
                        // Haptic feedback handled by TCA action
                    }
                }
            }
            .navigationTitle("Interval")
            .navigationBarItems(
                trailing: Button("Save") {
                    // Haptic feedback handled by TCA action
                    store.send(.updateCheckInInterval(store.state.getComputedIntervalInSeconds()))
                    store.send(.setShowIntervalPicker(false))
                }
            )
        }
    }
}

struct InstructionsView: View {
    @Bindable var store: StoreOf<HomeFeature>
    
    var body: some View {
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
                // Haptic feedback handled by TCA action
                store.send(.setShowInstructions(false))
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
}


struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>

    var body: some View {
        WithPerceptionTracking {
            mainContent()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .edgesIgnoringSafeArea(.bottom)
        .navigationTitle("Home")
        .onAppear {
            store.send(.generateQRCode)
        }
        .sheet(item: $store.scope(state: \.qrScanner, action: \.qrScanner)) { store in
            QRScannerView(store: store)
        }
        .sheet(item: $store.scope(state: \.qrShareSheet, action: \.qrShareSheet)) { store in
            QRCodeShareSheetView(store: store)
        }
        .sheet(isPresented: $store.showIntervalPicker) {
            IntervalPickerView(store: store)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $store.showInstructions) {
            InstructionsView(store: store)
        }
        .sheet(isPresented: $store.showShareSheet) {
            if let shareImage = store.shareableImage {
                ActivityShareSheet(items: ["My LifeSignal QR Code", shareImage])
            }
        }
        .alert("Change Notification Setting?", isPresented: $store.showIntervalChangeConfirmation) {
            Button("Cancel", role: .cancel) {
                store.send(.setShowIntervalChangeConfirmation(false))
            }
            Button("Change") {
                if let interval = store.pendingIntervalChange {
                    switch Int(interval) {
                    case 0:
                        store.send(.updateNotificationSettings(enabled: false, notify30Min: false, notify2Hours: false))
                    case 30:
                        store.send(.updateNotificationSettings(enabled: true, notify30Min: true, notify2Hours: false))
                    case 120:
                        store.send(.updateNotificationSettings(enabled: true, notify30Min: false, notify2Hours: true))
                    default:
                        break
                    }
                    store.send(.setShowIntervalChangeConfirmation(false))
                }
            }
        } message: {
            if let interval = store.pendingIntervalChange {
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
        .alert("Camera Access Denied", isPresented: $store.showCameraDeniedAlert) {
            Button("OK", role: .cancel) { }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Please allow camera access in Settings to scan QR codes.")
        }
        .alert("Reset QR Code", isPresented: $store.showResetQRConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset") {
                store.send(.resetQRCode)
            }
        } message: {
            Text("Are you sure you want to reset your QR code? This will invalidate any previously shared QR codes.")
        }
    }

    // MARK: - Main Content
    
    @ViewBuilder
    private func mainContent() -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // QR Code Section
                qrCodeSection()

                // Settings Section
                settingsSection()

                // Add extra padding at the bottom to ensure content doesn't overlap with tab bar
                Spacer()
                    .frame(height: 20)
            }
            .padding(.bottom, 50) // Add padding to ensure content doesn't overlap with tab bar
        }
    }

    // MARK: - QR Code Section

    @ViewBuilder
    private func qrCodeSection() -> some View {
        VStack(spacing: 16) {
            // QR Code Card
            qrCodeCard()

            // Action Buttons
            HStack(spacing: 12) {
                // Reset QR Code Button
                qrCodeActionButton(
                    icon: "arrow.triangle.2.circlepath",
                    label: "Reset QR",
                    action: {
                        // Haptic feedback handled by TCA action
                        store.send(.setShowResetQRConfirmation(true))
                    }
                )

                // Share QR Button
                qrCodeActionButton(
                    icon: "square.and.arrow.up",
                    label: "Share QR",
                    action: {
                        // Haptic feedback handled by TCA action
                        store.send(.generateShareableQRCode)
                    }
                )

                // Scan QR Button
                qrCodeActionButton(
                    icon: "qrcode.viewfinder",
                    label: "Scan QR",
                    action: {
                        // Haptic feedback handled by TCA action
                        store.send(.showQRScanner)
                    }
                )
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func qrCodeCard() -> some View {
        HStack(alignment: .top, spacing: 16) {
            // QR Code
            ZStack {
                if store.isQRCodeReady, let qrImage = store.qrCodeImage {
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
                    // Haptic feedback handled by TCA action
                    store.send(.copyQRCodeId)
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

    @ViewBuilder
    private func settingsSection() -> some View {
        VStack(alignment: .leading, spacing: 24) {
            // Check-in Interval
            checkInIntervalSection()

            // Notifications
            notificationsSection()

            // Help/Instructions
            helpSection()
        }
    }

    @ViewBuilder
    private func checkInIntervalSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Check-in interval")
                .foregroundColor(.primary)
                .padding(.horizontal)

            Button(action: {
                // Haptic feedback handled by TCA action
                store.send(.setShowIntervalPicker(true))
            }) {
                HStack {
                    Text(store.state.formatInterval(store.currentUser?.checkInInterval ?? 86400))
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

    @ViewBuilder
    private func notificationsSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Check-in notification")
                .foregroundColor(.primary)
                .padding(.horizontal)

            Picker("Check-in notification", selection: Binding(
                get: {
                    if !(store.currentUser?.isNotificationsEnabled ?? true) {
                        return 0
                    } else if store.currentUser?.notify2HoursBefore ?? false {
                        return 120
                    } else {
                        return 30
                    }
                },
                set: { newValue in
                    store.send(.setPendingIntervalChange(TimeInterval(newValue)))
                    // Haptic feedback handled by TCA action
                    store.send(.setShowIntervalChangeConfirmation(true))
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

    @ViewBuilder
    private func helpSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                // Haptic feedback handled by TCA action
                store.send(.setShowInstructions(true))
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
