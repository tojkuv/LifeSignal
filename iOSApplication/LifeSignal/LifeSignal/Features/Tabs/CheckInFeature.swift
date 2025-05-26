import SwiftUI
import Foundation
import ComposableArchitecture
import Perception
@_exported import Sharing

@Reducer
struct CheckInFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.currentUser) var currentUser: User? = nil
        
        var isCheckingIn = false
        var isAlertActive: Bool {
            currentUser?.isEmergencyAlertEnabled ?? false
        }
        var tapProgress: Double = 0.0
        var longPressProgress: Double = 0.0
        var isLongPressing = false
        var timeUntilNextCheckInText = "--:--:--"
        var alertTapCount = 0
        var lastAlertTapTime: Date? = nil
        var errorMessage: String?
        
        var canActivateAlert: Bool { !isAlertActive && currentUser != nil }
        var canDeactivateAlert: Bool { isAlertActive && currentUser != nil }
        var canCheckIn: Bool { !isCheckingIn && currentUser != nil }
        
        var checkInButtonBackgroundColor: Color {
            if isCheckingIn { return .gray }
            if let lastCheckIn = currentUser?.lastCheckedIn,
               let interval = currentUser?.checkInInterval {
                let timeSince = Date().timeIntervalSince(lastCheckIn)
                let timeRemaining = interval - timeSince
                
                if timeRemaining > interval * 0.5 { return .green }
                if timeRemaining > interval * 0.2 { return .yellow }
                if timeRemaining <= 0 { return .red }
                return .orange
            }
            return .blue
        }
        
        var isCheckInButtonCoolingDown: Bool {
            if let lastCheckIn = currentUser?.lastCheckedIn {
                return Date().timeIntervalSince(lastCheckIn) < 300 // 5 minute cooldown
            }
            return false
        }
    }

    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        // Lifecycle
        case onAppear
        case onDisappear
        
        // Core check-in functionality
        case checkIn
        case checkInResponse(Result<Void, Error>)
        
        // Alert system
        case activateAlert
        case deactivateAlert
        case alertResponse(Result<Void, Error>)
        
        // Alert button interactions
        case alertButtonTapped
        
        // Long press gestures
        case longPressStarted
        case longPressEnded
        
        // Timer management
        case startTimer
        case stopTimer
        case updateTimer
    }

    @Dependency(\.userClient) var userClient
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.notificationClient) var notificationClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .onAppear:
                return .send(.startTimer)
                
            case .onDisappear:
                return .send(.stopTimer)
                
            // Core check-in functionality
            case .checkIn:
                guard state.canCheckIn else { return .none }
                state.isCheckingIn = true
                state.errorMessage = nil
                
                return .run { [currentUser = state.currentUser] send in
                    do {
                        guard var user = currentUser else {
                            await send(.checkInResponse(.failure(UserClientError.userNotFound)))
                            return
                        }
                        
                        // Update lastCheckedIn timestamp
                        user.lastCheckedIn = Date()
                        user.lastModified = Date()
                        
                        // Call updateUser to persist the check-in
                        try await userClient.updateUser(user)
                        
                        // Send success notification
                        let notification = NotificationItem(
                            type: .checkInReminder,
                            title: "Check-in Complete",
                            message: "You've successfully checked in"
                        )
                        try await notificationClient.sendNotification(notification)
                        
                        await send(.checkInResponse(.success(())))
                    } catch {
                        await send(.checkInResponse(.failure(error)))
                    }
                }

            case .checkInResponse(.success):
                state.isCheckingIn = false
                
                return .run { _ in
                    await haptics.notification(.success)
                }

            case let .checkInResponse(.failure(error)):
                state.isCheckingIn = false
                state.errorMessage = error.localizedDescription
                
                return .run { _ in
                    await haptics.notification(.error)
                }
                
            // Alert system
            case .activateAlert:
                guard state.canActivateAlert else { return .none }
                state.errorMessage = nil
                
                return .run { [currentUser = state.currentUser] send in
                    do {
                        guard var user = currentUser else {
                            await send(.alertResponse(.failure(UserClientError.userNotFound)))
                            return
                        }
                        
                        // Enable emergency alert
                        user.setEmergencyAlertEnabled(true)
                        user.emergencyAlertTimestamp = Date()
                        
                        // Call updateUser to persist the alert activation
                        try await userClient.updateUser(user)
                        
                        // Notify contacts about emergency alert
                        try await notificationClient.notifyEmergencyAlertToggled(user.id, true)
                        
                        // Send local notification
                        let notification = NotificationItem(
                            type: .emergencyAlert,
                            title: "Emergency Alert Activated",
                            message: "Your contacts have been notified"
                        )
                        try await notificationClient.sendNotification(notification)
                        
                        await haptics.notification(.warning)
                        await send(.alertResponse(.success(())))
                    } catch {
                        await send(.alertResponse(.failure(error)))
                    }
                }
                
            case .deactivateAlert:
                guard state.canDeactivateAlert else { return .none }
                state.errorMessage = nil
                
                return .run { [currentUser = state.currentUser] send in
                    do {
                        guard var user = currentUser else {
                            await send(.alertResponse(.failure(UserClientError.userNotFound)))
                            return
                        }
                        
                        // Disable emergency alert
                        user.setEmergencyAlertEnabled(false)
                        
                        // Call updateUser to persist the alert deactivation
                        try await userClient.updateUser(user)
                        
                        // Notify contacts about emergency alert deactivation
                        try await notificationClient.notifyEmergencyAlertToggled(user.id, false)
                        
                        // Send local notification
                        let notification = NotificationItem(
                            type: .system,
                            title: "Emergency Alert Cancelled",
                            message: "The emergency alert has been cancelled"
                        )
                        try await notificationClient.sendNotification(notification)
                        
                        await haptics.notification(.success)
                        await send(.alertResponse(.success(())))
                    } catch {
                        await send(.alertResponse(.failure(error)))
                    }
                }

            case .alertResponse(.success):
                state.alertTapCount = 0
                state.tapProgress = 0.0
                return .none

            case let .alertResponse(.failure(error)):
                state.errorMessage = error.localizedDescription
                return .none
                
            // Alert button interactions
            case .alertButtonTapped:
                guard state.canActivateAlert else { return .none }
                
                let now = Date()
                if let lastTap = state.lastAlertTapTime,
                   now.timeIntervalSince(lastTap) < 0.8 {
                    state.alertTapCount += 1
                    state.tapProgress = Double(state.alertTapCount) / 5.0
                    
                    if state.alertTapCount >= 5 {
                        return .send(.activateAlert)
                    }
                } else {
                    state.alertTapCount = 1
                    state.tapProgress = 0.2
                }
                
                state.lastAlertTapTime = now
                
                return .run { send in
                    await haptics.impact(.medium)
                    try? await Task.sleep(for: .milliseconds(800))
                    let currentTime = Date()
                    if currentTime.timeIntervalSince(now) >= 0.8 {
                        await send(.binding(.set(\.alertTapCount, 0)))
                        await send(.binding(.set(\.tapProgress, 0.0)))
                    }
                }
                
            // Long press gestures
            case .longPressStarted:
                guard state.canDeactivateAlert else { return .none }
                state.isLongPressing = true
                state.longPressProgress = 0.0
                
                return .run { send in
                    await haptics.impact(.heavy)
                    for i in 1...30 {
                        try? await Task.sleep(for: .milliseconds(100))
                        await send(.binding(.set(\.longPressProgress, min(1.0, Double(i) / 30.0))))
                    }
                }
                .cancellable(id: CancelID.longPress)
                
            case .longPressEnded:
                if state.isLongPressing && state.longPressProgress >= 1.0 {
                    state.isLongPressing = false
                    state.longPressProgress = 0.0
                    return .send(.deactivateAlert)
                } else {
                    state.isLongPressing = false
                    state.longPressProgress = 0.0
                    return .cancel(id: CancelID.longPress)
                }
                
            // Timer management
            case .startTimer:
                return .run { send in
                    while true {
                        await send(.updateTimer)
                        try? await Task.sleep(for: .seconds(1))
                    }
                }
                .cancellable(id: CancelID.timer)

            case .stopTimer:
                return .cancel(id: CancelID.timer)
                
            case .updateTimer:
                if let lastCheckIn = state.currentUser?.lastCheckedIn,
                   let interval = state.currentUser?.checkInInterval {
                    let timeSince = Date().timeIntervalSince(lastCheckIn)
                    let timeRemaining = max(0, interval - timeSince)
                    
                    let hours = Int(timeRemaining) / 3600
                    let minutes = Int(timeRemaining) % 3600 / 60
                    let seconds = Int(timeRemaining) % 60
                    
                    state.timeUntilNextCheckInText = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
                } else {
                    state.timeUntilNextCheckInText = "--:--:--"
                }
                return .none
            }
        }
    }
    
    private enum CancelID {
        case timer
        case longPress
    }
}

struct CheckInView: View {
    @Bindable var store: StoreOf<CheckInFeature>

    var body: some View {
        WithPerceptionTracking {
            // Scrollable view for better horizontal mode support
            ScrollView(.vertical, showsIndicators: true) {
                // Single vertical stack for the entire view with equal spacing
                VStack(spacing: 16) {
                    // Alert Button
                    alertButtonView()

                    // Countdown display
                    countdownView()

                    // Check-in button
                    checkInButtonView()

                    // Add extra padding at the bottom to ensure content doesn't overlap with tab bar
                    Spacer()
                        .frame(height: 20)
                }
                .padding(.horizontal)
                .padding(.bottom, 50) // Add padding to ensure content doesn't overlap with tab bar
            }
            .background(Color(UIColor.systemGroupedBackground))
            .edgesIgnoringSafeArea(.bottom) // Extend background to bottom edge
            .onAppear {
                store.send(.onAppear)
            }
            .onDisappear {
                store.send(.onDisappear)
            }
        }
    }

    @ViewBuilder
    private func alertButtonView() -> some View {
        ZStack(alignment: .center) {
            Button(action: {
                store.send(.alertButtonTapped, animation: .default)
            }) {
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(store.isAlertActive ? Color.red.opacity(0.3) : Color(UIColor.secondarySystemGroupedBackground))
                        .frame(maxWidth: .infinity)
                        .frame(height: 100) // Same height as countdown

                    // Progress animation layer (below text)
                    if !store.isAlertActive {
                        GeometryReader { geometry in
                            // Rectangle that grows from center to edges
                            Rectangle()
                                .fill(Color.red.opacity(0.3)) // Use the same red color as the active alert button
                                .frame(width: geometry.size.width * store.tapProgress, height: geometry.size.height)
                                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                                .opacity(0.7) // Reduce opacity to ensure text remains visible in light mode
                        }
                        .animation(.linear(duration: 0.3), value: store.tapProgress)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Deactivation animation layer (below text)
                    if store.isLongPressing && store.isAlertActive && store.canDeactivateAlert {
                        GeometryReader { geometry in
                            // Growing rectangle that expands horizontally from center
                            Rectangle()
                                .fill(Color(UIColor.secondarySystemGroupedBackground))
                                .frame(width: geometry.size.width * store.longPressProgress, height: geometry.size.height)
                                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        }
                        .animation(.linear, value: store.longPressProgress)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Stack for main text and subtext
                    VStack(alignment: .center, spacing: 4) {
                        // Main button text
                        Text(store.isAlertActive ? "Alert Is Active" : "Activate Alert")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.primary) // Always use primary color for main text

                        // Subtext - directly below main text
                        if store.isAlertActive && store.canDeactivateAlert {
                            // "Hold to deactivate" text (visible whenever alert is active and can be deactivated)
                            Text("Hold to Deactivate")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary) // Use secondary color for subtext
                        } else if !store.isAlertActive && store.canActivateAlert {
                            // "Tap repeatedly to activate" text (visible whenever alert is not active and button can receive taps)
                            Text("Tap Repeatedly to Activate")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary) // Use secondary color for subtext
                        }
                    }
                    .zIndex(10) // Ensure text is always on top
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100) // Same height as countdown
            }
            .buttonStyle(PlainButtonStyle())
            // Disable the default button highlight effect
            .buttonStyle(BorderlessButtonStyle())
            // Use a gesture for handling the long press
            .gesture(
                LongPressGesture(minimumDuration: 3.0)
                    .onChanged { _ in
                        if store.isAlertActive && store.canDeactivateAlert {
                            store.send(.longPressStarted)
                        }
                    }
                    .onEnded { _ in
                        store.send(.longPressEnded)
                    }
            )
        }
    }

    @ViewBuilder
    private func countdownView() -> some View {
        VStack {
            Text("Interval Time Left")
                .font(.system(size: 14, weight: .semibold))
                .tracking(0.5) // Add letter spacing for better readability
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 12)

            // Center content vertically and horizontally
            // Time text (centered)
            Text(store.timeUntilNextCheckInText)
                .font(.system(size: 38, weight: .bold))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.7) // Allow text to scale down if needed
                .lineLimit(1) // Ensure single line
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100) // Fixed height
        .background(Color(UIColor.secondarySystemGroupedBackground)) // Use secondarySystemGroupedBackground
        .cornerRadius(12)
    }

    @ViewBuilder
    private func checkInButtonView() -> some View {
        Button(action: {
            store.send(.checkIn, animation: .default)
        }) {
            Text("Check-in")
                .font(.system(size: 26, weight: .bold))
                .tracking(0.5) // Add letter spacing for better readability
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 200) // Twice the height of alert button
                .background(store.checkInButtonBackgroundColor)
                .cornerRadius(12)
        }
        .disabled(store.isCheckInButtonCoolingDown)
    }
}

#Preview {
    CheckInView(
        store: Store(initialState: CheckInFeature.State()) {
            CheckInFeature()
        }
    )
}