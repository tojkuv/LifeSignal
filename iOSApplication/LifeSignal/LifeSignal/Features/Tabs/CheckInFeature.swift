import SwiftUI
import Foundation
import ComposableArchitecture
import Perception
@_exported import Sharing

private enum CheckInCancelID {
    case timer
    case longPress
    case tapReset
    case activationAnimation
}

@Reducer
struct CheckInFeature: FeatureContext {
    /// The view type that this feature is paired with (same file)
    typealias PairedView = CheckInView
    @ObservableState
    struct State: Equatable {
        @Shared(.authenticationInternalState) var authState: AuthClientState
        @Shared(.userInternalState) var userState: UserClientState
        
        var currentUser: User? { userState.currentUser }
        
        var isCheckingIn = false
        var isAlertActive: Bool {
            currentUser?.isEmergencyAlertEnabled ?? false
        }
        var tapProgress: Double = 0.0
        var longPressProgress: Double = 0.0
        var isLongPressing = false
        var isActivating = false
        var lastDeactivationTime: Date? = nil
        var timeUntilNextCheckInText = "--:--:--"
        var alertTapCount = 0
        var lastAlertTapTime: Date? = nil
        
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
        case checkInCooldownNotification
        
        // Alert system
        case activateAlert
        case deactivateAlert
        case alertResponse(Result<Void, Error>)
        
        // Biometric authentication
        case authenticateBiometricForCheckIn
        case authenticateBiometricForAlertDeactivation
        case biometricAuthenticationResult(Result<Bool, Error>)
        
        // Alert button interactions
        case alertButtonTapped
        case startActivationAnimation
        
        // Long press gestures
        case longPressStarted
        case longPressEnded
        case dragGestureChanged
        case dragGestureEnded
        
        // Timer management
        case startTimer
        case stopTimer
        case updateTimer
        
        // Tap progress reset
        case resetTapProgress
        
        // Debug actions
        case debugCycleCheckInState
    }

    @Dependency(\.userClient) var userClient
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.biometricClient) var biometricClient

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
                
                // Check if in cooldown period
                if state.isCheckInButtonCoolingDown {
                    return .send(.checkInCooldownNotification)
                }
                
                // Check biometric requirement first
                if state.currentUser?.biometricAuthEnabled == true {
                    return .send(.authenticateBiometricForCheckIn)
                }
                
                state.isCheckingIn = true
                
                return .run { [currentUser = state.currentUser, authToken = state.authState.authenticationToken] send in
                    do {
                        guard let user = currentUser, let token = authToken else {
                            await send(.checkInResponse(.failure(UserClientError.userNotFound)))
                            return
                        }
                        
                        // Update user with new check-in timestamp
                        var updatedUser = user
                        updatedUser.lastCheckedIn = Date()
                        updatedUser.lastModified = Date()
                        
                        // Call updateUser to persist the check-in
                        try await userClient.updateUser(updatedUser, token)
                        
                        // Send success system notification
                        try? await notificationClient.sendSystemNotification(
                            "Check-in Complete",
                            "You've successfully checked in"
                        )
                        
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
                
                return .run { [notificationClient] _ in
                    // Send error system notification
                    try? await notificationClient.sendSystemNotification(
                        "Check-in Issue",
                        "Unable to complete check-in. Will retry automatically."
                    )
                    await haptics.notification(.error)
                }
                
            case .checkInCooldownNotification:
                return .run { [lastCheckIn = state.currentUser?.lastCheckedIn] _ in
                    let timeRemaining: Int
                    if let lastCheckIn = lastCheckIn {
                        let elapsed = Date().timeIntervalSince(lastCheckIn)
                        timeRemaining = max(0, Int(300 - elapsed)) // 5 minutes = 300 seconds
                    } else {
                        timeRemaining = 0
                    }
                    
                    let minutes = timeRemaining / 60
                    let seconds = timeRemaining % 60
                    let timeText = minutes > 0 ? "\(minutes)m \(seconds)s" : "\(seconds)s"
                    
                    // Send cooldown system notification
                    try? await notificationClient.sendSystemNotification(
                        "Check-in Too Soon",
                        "You checked in recently. Please wait \(timeText) before checking in again."
                    )
                    await haptics.notification(.warning)
                }
                
            // Biometric authentication
            case .authenticateBiometricForCheckIn:
                return .run { [biometricClient] send in
                    await send(.biometricAuthenticationResult(Result {
                        try await biometricClient.authenticate("Authenticate to check in")
                    }))
                }
                
            case .authenticateBiometricForAlertDeactivation:
                return .run { [biometricClient] send in
                    await send(.biometricAuthenticationResult(Result {
                        try await biometricClient.authenticate("Authenticate to deactivate emergency alert")
                    }))
                }
                
            case let .biometricAuthenticationResult(.success(success)):
                if success {
                    // Determine which action to perform based on the last biometric request
                    // For simplicity, check current state to determine action
                    if state.isAlertActive && state.canDeactivateAlert {
                        // Was authenticating for alert deactivation
                        return .run { [currentUser = state.currentUser, authToken = state.authState.authenticationToken] send in
                            do {
                                guard var user = currentUser, let token = authToken else {
                                    await send(.alertResponse(.failure(UserClientError.userNotFound)))
                                    return
                                }
                                
                                // Disable emergency alert
                                user.setEmergencyAlertEnabled(false)
                                
                                // Call updateUser to persist the alert deactivation
                                try await userClient.updateUser(user, token)
                                
                                // Notify contacts about emergency alert deactivation
                                try await notificationClient.notifyEmergencyAlertToggled(user.id, false, token)
                                
                                await haptics.notification(.success)
                                await send(.alertResponse(.success(())))
                            } catch {
                                await send(.alertResponse(.failure(error)))
                            }
                        }
                    } else {
                        // Was authenticating for check-in
                        if state.isCheckInButtonCoolingDown {
                            return .send(.checkInCooldownNotification)
                        }
                        
                        state.isCheckingIn = true
                        
                        return .run { [currentUser = state.currentUser, authToken = state.authState.authenticationToken] send in
                            do {
                                guard let user = currentUser, let token = authToken else {
                                    await send(.checkInResponse(.failure(UserClientError.userNotFound)))
                                    return
                                }
                                
                                // Update user with new check-in timestamp
                                var updatedUser = user
                                updatedUser.lastCheckedIn = Date()
                                updatedUser.lastModified = Date()
                                
                                // Call updateUser to persist the check-in
                                try await userClient.updateUser(updatedUser, token)
                                
                                // Send success system notification
                                try? await notificationClient.sendSystemNotification(
                                    "Check-in Complete",
                                    "You've successfully checked in"
                                )
                                
                                await send(.checkInResponse(.success(())))
                            } catch {
                                await send(.checkInResponse(.failure(error)))
                            }
                        }
                    }
                } else {
                    return .run { _ in
                        await haptics.notification(.error)
                    }
                }
                
            case let .biometricAuthenticationResult(.failure(error)):
                return .run { [notificationClient] _ in
                    await haptics.notification(.error)
                    
                    let message: String
                    if let biometricError = error as? BiometricClientError {
                        switch biometricError {
                        case .userCancel:
                            message = "Biometric authentication was cancelled."
                        case .notAvailable:
                            message = "Biometric authentication is not available."
                        case .notEnrolled:
                            message = "No biometric data is enrolled on this device."
                        default:
                            message = biometricError.errorDescription ?? "Biometric authentication failed."
                        }
                    } else {
                        message = "Biometric authentication failed."
                    }
                    
                    try? await notificationClient.sendSystemNotification(
                        "Authentication Failed",
                        message
                    )
                }
                
            // Alert system
            case .activateAlert:
                guard state.canActivateAlert else { return .none }
                
                return .run { [currentUser = state.currentUser, authToken = state.authState.authenticationToken] send in
                    do {
                        guard var user = currentUser, let token = authToken else {
                            await send(.alertResponse(.failure(UserClientError.userNotFound)))
                            return
                        }
                        
                        // Enable emergency alert
                        user.setEmergencyAlertEnabled(true)
                        user.emergencyAlertTimestamp = Date()
                        
                        // Call updateUser to persist the alert activation
                        try await userClient.updateUser(user, token)
                        
                        // Notify contacts about emergency alert
                        try await notificationClient.notifyEmergencyAlertToggled(user.id, true, token)
                        
                        // Emergency alert notification is handled via notifyEmergencyAlertToggled
                        // which creates proper notification history via stream
                        
                        await haptics.notification(.warning)
                        await send(.alertResponse(.success(())))
                    } catch {
                        await send(.alertResponse(.failure(error)))
                    }
                }
                
            case .deactivateAlert:
                guard state.canDeactivateAlert else { return .none }
                
                // Check biometric requirement for alert deactivation
                if state.currentUser?.biometricAuthEnabled == true {
                    return .send(.authenticateBiometricForAlertDeactivation)
                }
                
                return .run { [currentUser = state.currentUser, authToken = state.authState.authenticationToken] send in
                    do {
                        guard var user = currentUser, let token = authToken else {
                            await send(.alertResponse(.failure(UserClientError.userNotFound)))
                            return
                        }
                        
                        // Disable emergency alert
                        user.setEmergencyAlertEnabled(false)
                        
                        // Call updateUser to persist the alert deactivation
                        try await userClient.updateUser(user, token)
                        
                        // Notify contacts about emergency alert deactivation
                        try await notificationClient.notifyEmergencyAlertToggled(user.id, false, token)
                        
                        // Emergency alert deactivation is handled via notifyEmergencyAlertToggled
                        // which creates proper notification history via stream
                        
                        await haptics.notification(.success)
                        await send(.alertResponse(.success(())))
                    } catch {
                        await send(.alertResponse(.failure(error)))
                    }
                }

            case .alertResponse(.success):
                state.alertTapCount = 0
                state.tapProgress = 0.0
                state.isActivating = false
                state.isLongPressing = false
                state.longPressProgress = 0.0
                return .none

            case let .alertResponse(.failure(error)):
                // Emergency alert errors with system notification
                return .run { [notificationClient] _ in
                    try? await notificationClient.sendSystemNotification(
                        "Emergency Alert Issue",
                        "Unable to update emergency alert status. Please try again."
                    )
                    await haptics.notification(.error)
                }
                
            // Alert button interactions
            case .alertButtonTapped:
                if state.isAlertActive || state.isLongPressing || state.isActivating {
                    return .none
                }
                
                // Prevent taps shortly after deactivation
                if let lastDeactivation = state.lastDeactivationTime,
                   Date().timeIntervalSince(lastDeactivation) < 0.5 {
                    return .none
                }
                
                guard state.canActivateAlert else { return .none }
                
                let now = Date()
                if let lastTap = state.lastAlertTapTime,
                   now.timeIntervalSince(lastTap) < 1.0 { // Increased window to 1 second
                    state.alertTapCount += 1
                    
                    if state.alertTapCount >= 5 {
                        // Don't update tapProgress, go straight to animation
                        state.alertTapCount = 0 // Reset tap count
                        state.lastAlertTapTime = nil
                        return .merge(
                            .cancel(id: CheckInCancelID.tapReset),
                            .run { _ in await haptics.impact(.heavy) },
                            .send(.startActivationAnimation)
                        )
                    } else {
                        // Update progress for taps 1-4: each tap fills 15% (60% total)
                        state.tapProgress = Double(state.alertTapCount) * 0.15
                    }
                } else {
                    state.alertTapCount = 1
                    state.tapProgress = 0.15 // First tap fills 15%
                }
                
                state.lastAlertTapTime = now
                
                return .merge(
                    .cancel(id: CheckInCancelID.tapReset),
                    .run { _ in await haptics.impact(.medium) },
                    .run { send in
                        try? await Task.sleep(for: .seconds(2)) // Longer reset window
                        await send(.resetTapProgress)
                    }
                    .cancellable(id: CheckInCancelID.tapReset)
                )
                
            case .startActivationAnimation:
                guard state.canActivateAlert else { return .none }
                state.isActivating = true
                // Animation starts from 60% and fills remaining 40%
                let startProgress = 0.6
                state.tapProgress = startProgress
                
                return .run { send in
                    let totalDuration: Double = 0.6 // Slower animation for the final 40%
                    let updateInterval: Double = 0.016 // ~60fps for smooth animation
                    let totalSteps = Int(totalDuration / updateInterval)
                    let progressRange = 0.4 // Fill the remaining 40%
                    
                    for i in 1...totalSteps {
                        guard Task.isCancelled == false else { break }
                        try? await Task.sleep(for: .milliseconds(Int(updateInterval * 1000)))
                        let progress = startProgress + (progressRange * Double(i) / Double(totalSteps))
                        await send(.binding(.set(\.tapProgress, min(1.0, progress))))
                        
                        // If we completed the animation, activate the alert
                        if i == totalSteps {
                            await send(.activateAlert)
                        }
                    }
                }
                .cancellable(id: CheckInCancelID.activationAnimation)
                
            // Long press gestures
            case .longPressStarted:
                guard state.isAlertActive && state.canDeactivateAlert else { return .none }
                state.isLongPressing = true
                state.longPressProgress = 0.0
                
                return .run { send in
                    await haptics.impact(.heavy)
                    
                    // Instantly jump to 80%
                    await send(.binding(.set(\.longPressProgress, 0.8)))
                    
                    let totalDuration: Double = 3.0
                    let updateInterval: Double = 0.016 // ~60fps for smooth animation
                    let totalSteps = Int(totalDuration / updateInterval)
                    
                    for i in 1...totalSteps {
                        guard Task.isCancelled == false else { break }
                        
                        let linearProgress = Double(i) / Double(totalSteps)
                        // Only animate the last 20% (from 0.8 to 1.0)
                        let progress = 0.8 + (linearProgress * 0.2)
                        
                        try? await Task.sleep(for: .milliseconds(Int(updateInterval * 1000)))
                        await send(.binding(.set(\.longPressProgress, min(1.0, progress))))
                        
                        // If we completed the animation, deactivate the alert
                        if i == totalSteps {
                            await send(.binding(.set(\.lastDeactivationTime, Date())))
                            await send(.deactivateAlert)
                        }
                    }
                }
                .cancellable(id: CheckInCancelID.longPress, cancelInFlight: true)
                
            case .longPressEnded:
                state.isLongPressing = false
                state.longPressProgress = 0.0
                return .cancel(id: CheckInCancelID.longPress)
                
            case .dragGestureChanged:
                // Cancel long press if user drags finger while pressing
                if state.isLongPressing {
                    state.isLongPressing = false
                    state.longPressProgress = 0.0
                    return .cancel(id: CheckInCancelID.longPress)
                }
                return .none
                
            case .dragGestureEnded:
                // Handle drag gesture end, similar to long press end
                if state.isLongPressing {
                    state.isLongPressing = false
                    state.longPressProgress = 0.0
                    return .cancel(id: CheckInCancelID.longPress)
                }
                return .none
                
            // Timer management
            case .startTimer:
                return .run { send in
                    while true {
                        await send(.updateTimer)
                        try? await Task.sleep(for: .seconds(1))
                    }
                }
                .cancellable(id: CheckInCancelID.timer)

            case .stopTimer:
                return .cancel(id: CheckInCancelID.timer)
                
            case .updateTimer:
                if let lastCheckIn = state.currentUser?.lastCheckedIn,
                   let interval = state.currentUser?.checkInInterval {
                    let timeSince = Date().timeIntervalSince(lastCheckIn)
                    let timeRemaining = interval - timeSince
                    
                    if timeRemaining > 0 {
                        // Still have time remaining - show countdown
                        let days = Int(timeRemaining) / 86400
                        let hours = Int(timeRemaining) % 86400 / 3600
                        let minutes = Int(timeRemaining) % 3600 / 60
                        
                        if days > 0 {
                            // Show days and hours: "2d 5h"
                            state.timeUntilNextCheckInText = "\(days)d \(hours)h"
                        } else if hours > 0 {
                            // Show hours and minutes: "5h 23m"
                            state.timeUntilNextCheckInText = "\(hours)h \(minutes)m"
                        } else {
                            // Show just minutes: "23m"
                            state.timeUntilNextCheckInText = "\(minutes)m"
                        }
                    } else {
                        // Overdue - show how long expired
                        let expiredTime = abs(timeRemaining)
                        let days = Int(expiredTime) / 86400
                        let hours = Int(expiredTime) % 86400 / 3600
                        let minutes = Int(expiredTime) % 3600 / 60
                        
                        if days > 30 {
                            // Show generic message for very old: "Expired long ago"
                            state.timeUntilNextCheckInText = "Expired long ago"
                        } else if days > 0 {
                            // Show only days: "Expired 2d ago"
                            state.timeUntilNextCheckInText = "Expired \(days)d ago"
                        } else if hours > 0 {
                            // Show only hours: "Expired 5h ago"
                            state.timeUntilNextCheckInText = "Expired \(hours)h ago"
                        } else {
                            // Show only minutes: "Expired 23m ago"
                            state.timeUntilNextCheckInText = "Expired \(minutes)m ago"
                        }
                    }
                } else {
                    state.timeUntilNextCheckInText = "--"
                }
                return .none
                
            case .resetTapProgress:
                state.alertTapCount = 0
                state.tapProgress = 0.0
                state.lastAlertTapTime = nil
                return .none
                
            case .debugCycleCheckInState:
                return .run { [currentUser = state.currentUser, userClient] _ in
                    guard var user = currentUser else { return }
                    
                    let now = Date()
                    let interval = user.checkInInterval
                    
                    // Cycle through different check-in states for testing button colors
                    if let lastCheckIn = user.lastCheckedIn {
                        let timeSince = now.timeIntervalSince(lastCheckIn)
                        let timeRemaining = interval - timeSince
                        
                        if timeRemaining > interval * 0.5 {
                            // Currently green -> set to yellow (between 50% and 20%)
                            user.lastCheckedIn = now.addingTimeInterval(-(interval * 0.6))
                        } else if timeRemaining > interval * 0.2 {
                            // Currently yellow -> set to orange (between 20% and 0%)
                            user.lastCheckedIn = now.addingTimeInterval(-(interval * 0.9))
                        } else if timeRemaining > 0 {
                            // Currently orange -> set to red (overdue)
                            user.lastCheckedIn = now.addingTimeInterval(-interval - 3600) // 1 hour overdue
                        } else if timeRemaining > -2678400 { // More than 31 days overdue (-31 * 24 * 60 * 60)
                            // Currently red (recent overdue) -> set to very overdue (31+ days)
                            user.lastCheckedIn = now.addingTimeInterval(-2678400 - interval) // 31 days + interval overdue
                        } else {
                            // Currently very overdue -> set back to green (just checked in)
                            user.lastCheckedIn = now
                        }
                    } else {
                        // No check-in yet -> set to recent check-in (green)
                        user.lastCheckedIn = now
                    }
                    
                    // Update shared state directly for debug purposes - using UserClient
                    try await userClient.updateUser(user, "")
                }
            }
        }
    }
}

struct CheckInView: View, FeatureView {
    /// The feature type that this view is paired with (same file)
    typealias PairedFeature = CheckInFeature
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

                    // Debug button (only in debug builds)
                    // #if DEBUG
                    // debugButtonView()
                    // #endif

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
                if !store.isAlertActive && !store.isLongPressing && !store.isActivating {
                    store.send(.alertButtonTapped, animation: .default)
                }
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
                        .animation(.easeInOut(duration: 0.2), value: store.tapProgress)
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
                        .animation(.easeInOut(duration: 0.1), value: store.longPressProgress)
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
            // Use a gesture for handling the long press (match reference: 3.0 seconds)
            .onLongPressGesture(minimumDuration: 0.1, pressing: { isPressing in
                if store.isAlertActive && store.canDeactivateAlert && !store.isActivating {
                    if isPressing {
                        store.send(.longPressStarted)
                    } else {
                        store.send(.longPressEnded)
                    }
                }
            }, perform: {
                // Do nothing - deactivation is handled in the animation loop
            })
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
    }
    
    // #if DEBUG
    // @ViewBuilder
    // private func debugButtonView() -> some View {
    //     Button(action: {
    //         store.send(.debugCycleCheckInState)
    //     }) {
    //         Text("🔄 DEBUG: Cycle Check-in State")
    //             .font(.system(size: 13, weight: .medium, design: .rounded))
    //             .foregroundColor(.primary)
    //             .frame(maxWidth: .infinity)
    //             .frame(height: 44)
    //             .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    //             .overlay(
    //                 RoundedRectangle(cornerRadius: 12)
    //                     .stroke(.quaternary, lineWidth: 0.5)
    //             )
    //     }
    //     .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    // }
    // #endif
}

#Preview {
    CheckInView(
        store: Store(initialState: CheckInFeature.State()) {
            CheckInFeature()
        }
    )
}