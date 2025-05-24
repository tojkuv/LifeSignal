import Foundation
import SwiftUI
import ComposableArchitecture

@Reducer
struct CheckInFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.lastCheckInDate) var lastCheckInTime: Date? = nil
        @Shared(.hasActiveAlert) var isAlertActive: Bool = false
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
            if let lastCheckIn = lastCheckInTime {
                let timeSince = Date().timeIntervalSince(lastCheckIn)
                if timeSince < 3600 { return .green }
                if timeSince < 7200 { return .yellow }
                return .red
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
        case checkIn
        case activateAlert
        case deactivateAlert
        case alertButtonTapped
        case longPressStarted
        case longPressEnded
        case updateTimer
        case startTimer
        case stopTimer
        case checkInResponse(Result<Void, Error>)
        case alertResponse(Result<Void, Error>)
        
        // Missing actions from the view
        case checkAlertStatus
        case cleanUpTimers
        case startUpdateTimer
        case handleAlertButtonTap
        case startLongPress
        case handleLongPressEnded
        case handleDragGestureChanged
        case handleDragGestureEnded
    }

    @Dependency(\.hapticClient) var haptics
    @Dependency(\.notificationRepository) var notificationRepository
    @Dependency(\.analytics) var analytics

    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .checkIn:
                guard state.canCheckIn else { return .none }
                state.isCheckingIn = true
                state.errorMessage = nil
                
                return .run { send in
                    await analytics.track(.featureUsed(feature: "check_in", context: [:]))
                    await send(.checkInResponse(Result {
                        // Simulate check-in API call
                        try await Task.sleep(for: .milliseconds(1000))
                        await notificationRepository.sendLocalNotification(.checkIn, "Check-in Complete", "You've successfully checked in")
                    }))
                }
                
            case .activateAlert:
                guard state.canActivateAlert else { return .none }
                state.errorMessage = nil
                
                return .run { send in
                    await haptics.notification(.warning)
                    await analytics.track(.featureUsed(feature: "emergency_alert_activate", context: [:]))
                    await send(.alertResponse(Result {
                        // In production, this would trigger emergency protocols
                        await notificationRepository.sendLocalNotification(.emergencyAlert, "Emergency Alert Activated", "Your contacts have been notified")
                    }))
                }
                
            case .deactivateAlert:
                guard state.canDeactivateAlert else { return .none }
                state.errorMessage = nil
                
                return .run { send in
                    await haptics.notification(.success)
                    await analytics.track(.featureUsed(feature: "emergency_alert_deactivate", context: [:]))
                    await send(.alertResponse(Result {
                        // In production, this would cancel emergency protocols
                        await notificationRepository.sendLocalNotification(.alertCancelled, "Emergency Alert Cancelled", "The emergency alert has been cancelled")
                    }))
                }
                
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
                
            case .updateTimer:
                state.timeUntilNextCheckInText = "--:--:--"
                return .none
                
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
                
            case .checkInResponse(.success):
                state.isCheckingIn = false
                state.showConfirmation = true
                
                return .run { [lastCheckInTime = state.$lastCheckInTime] send in
                    lastCheckInTime.withLock { $0 = Date() }
                    await haptics.notification(.success)
                    try? await Task.sleep(for: .seconds(3))
                    await send(.binding(.set(\.showConfirmation, false)))
                }
                
            case let .checkInResponse(.failure(error)):
                state.isCheckingIn = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .alertResponse(.success):
                state.alertTapCount = 0
                state.tapProgress = 0.0
                return .run { [isAlertActive = state.$isAlertActive] send in
                    isAlertActive.withLock { $0 = !$0 }
                }
                
            case let .alertResponse(.failure(error)):
                state.errorMessage = error.localizedDescription
                return .none
                
            // Handle missing actions from view
            case .checkAlertStatus:
                return .send(.updateTimer)
                
            case .cleanUpTimers:
                return .cancel(id: CancelID.timer)
                
            case .startUpdateTimer:
                return .send(.startTimer)
                
            case .handleAlertButtonTap:
                return .send(.alertButtonTapped)
                
            case .startLongPress:
                return .send(.longPressStarted)
                
            case .handleLongPressEnded:
                return .send(.longPressEnded)
                
            case .handleDragGestureChanged:
                // Handle drag gesture for alert interface
                return .none
                
            case .handleDragGestureEnded:
                // Handle end of drag gesture
                return .none
            }
        }
    }
    
    private enum CancelID {
        case timer
        case longPress
    }
}
