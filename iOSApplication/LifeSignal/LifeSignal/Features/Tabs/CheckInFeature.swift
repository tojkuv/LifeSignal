import SwiftUI
import Foundation
import ComposableArchitecture
import Perception

@Reducer
struct CheckInFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.lastCheckInDate) var lastCheckInTime: Date? = nil
        var isAlertActive: Bool = false
        @Shared(.currentUser) var currentUser: User? = nil
        
        var isCheckingIn = false
        var showConfirmation = false
        var checkInMessage = ""
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
            if let lastCheckIn = lastCheckInTime,
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
            if let lastCheckIn = lastCheckInTime {
                return Date().timeIntervalSince(lastCheckIn) < 300 // 5 minute cooldown
            }
            return false
        }
    }

    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        // Core check-in functionality
        case checkIn
        case performCheckIn
        case checkInResponse(Result<Void, Error>)
        
        // Alert system
        case activateAlert
        case deactivateAlert
        case checkAlertStatus
        case alertResponse(Result<Void, Error>)
        
        // Alert button interactions
        case alertButtonTapped
        case handleAlertButtonTap
        
        // Long press gestures
        case longPressStarted
        case longPressEnded
        case startLongPress
        case handleLongPressEnded
        
        // Drag gestures
        case handleDragGestureChanged
        case handleDragGestureEnded
        
        // Timer management
        case startTimer
        case stopTimer
        case updateTimer
        case startUpdateTimer
        case cleanUpTimers
    }

    @Dependency(\.hapticClient) var haptics
    @Dependency(\.notificationClient) var notificationClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            // Core check-in functionality
            case .checkIn:
                guard state.canCheckIn else { return .none }
                state.isCheckingIn = true
                state.errorMessage = nil
                
                return .run { send in
                    await send(.checkInResponse(Result {
                        // Simulate check-in API call
                        try await Task.sleep(for: .milliseconds(1000))
                        let notification = NotificationItem(type: .checkInReminder, title: "Check-in Complete", message: "You've successfully checked in")
                        try await notificationClient.sendNotification(notification)
                    }))
                }

            case .performCheckIn:
                // Handle perform check-in action
                return .send(.checkIn)

            case .checkInResponse(.success):
                state.isCheckingIn = false
                state.showConfirmation = true
                state.$lastCheckInTime.withLock { $0 = Date() }
                
                return .run { _ in
                    await haptics.notification(.success)
                    try? await Task.sleep(for: .seconds(3))
                    // Note: showConfirmation reset would be handled by binding if needed
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
                
                return .run { send in
                    await haptics.notification(.warning)
                    await send(.alertResponse(Result {
                        // In production, this would trigger emergency protocols
                        let notification = NotificationItem(type: .emergencyAlert, title: "Emergency Alert Activated", message: "Your contacts have been notified")
                        try await notificationClient.sendNotification(notification)
                    }))
                }
                
            case .deactivateAlert:
                guard state.canDeactivateAlert else { return .none }
                state.errorMessage = nil
                
                return .run { send in
                    await haptics.notification(.success)
                    await send(.alertResponse(Result {
                        // In production, this would cancel emergency protocols
                        let notification = NotificationItem(type: .system, title: "Emergency Alert Cancelled", message: "The emergency alert has been cancelled")
                        try await notificationClient.sendNotification(notification)
                    }))
                }

            case .checkAlertStatus:
                return .send(.updateTimer)

            case .alertResponse(.success):
                state.alertTapCount = 0
                state.tapProgress = 0.0
                return .run { [isAlertActive = state.$isAlertActive] send in
                    isAlertActive.withLock { $0 = !$0 }
                }

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

            case .handleAlertButtonTap:
                return .send(.alertButtonTapped)
                
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

            case .startLongPress:
                return .send(.longPressStarted)

            case .handleLongPressEnded:
                return .send(.longPressEnded)
                
            // Drag gestures
            case .handleDragGestureChanged:
                // Handle drag gesture for alert interface
                return .none

            case .handleDragGestureEnded:
                // Handle drag gesture end
                return .none
                
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
                if let lastCheckIn = state.lastCheckInTime,
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
                

            case .startUpdateTimer:
                return .send(.startTimer)

            case .cleanUpTimers:
                return .cancel(id: CancelID.timer)
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
                // Check if alert is already active when view appears
                store.send(.checkAlertStatus)

                // Start the timer to update the time display
                store.send(.startUpdateTimer)
            }
            .onDisappear {
                // Clean up all timers when the view disappears
                store.send(.cleanUpTimers)
            }
        }
    }

    /// Alert button view
    @ViewBuilder
    private func alertButtonView() -> some View {
        ZStack(alignment: .center) {
            Button(action: {
                store.send(.handleAlertButtonTap, animation: .default)
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
                            store.send(.startLongPress)
                        }
                    }
                    .onEnded { _ in
                        store.send(.handleLongPressEnded)
                    }
            )
            // Add a DragGesture to detect when the user's finger moves away
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        store.send(.handleDragGestureChanged)
                    }
                    .onEnded { _ in
                        store.send(.handleDragGestureEnded)
                    }
            )
        }
    }

    /// Countdown view
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

    /// Check-in button view
    @ViewBuilder
    private func checkInButtonView() -> some View {
        Button(action: {
            store.send(.performCheckIn, animation: .default)
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