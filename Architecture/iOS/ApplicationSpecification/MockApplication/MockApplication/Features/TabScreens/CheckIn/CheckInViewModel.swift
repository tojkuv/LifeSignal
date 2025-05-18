import Foundation
import SwiftUI
import Combine

/// View model for the check-in feature
/// This class is designed to mirror the structure of CheckInFeature.State in the TCA implementation
class CheckInViewModel: ObservableObject {
    // MARK: - Published Properties

    // Time and interval properties
    @Published var timeUntilNextCheckInText: String = ""
    @Published var lastCheckIn: Date
    @Published var checkInInterval: TimeInterval

    // Alert activation/deactivation properties
    @Published var isAlertActive: Bool = false
    @Published var consecutiveTaps: Int = 0
    @Published var isLongPressing: Bool = false
    @Published var longPressProgress: CGFloat = 0.0
    @Published var canDeactivateAlert: Bool = false
    @Published var canActivateAlert: Bool = true
    @Published var tapProgress: CGFloat = 0.0
    @Published var isAnimatingFinalTap: Bool = false
    @Published var shouldActivateAlert: Bool = false

    // Check-in button state
    @Published var isCheckInButtonCoolingDown: Bool = false

    // No alert confirmation needed

    // MARK: - Private Properties
    private var updateTimer: Timer?
    private var longPressTimer: Timer?
    private var tapResetTimer: Timer?
    private var tapShrinkTimer: Timer?
    private var lastTapTime: Date?

    // MARK: - Computed Properties

    /// The check-in expiration time
    var checkInExpiration: Date {
        return lastCheckIn.addingTimeInterval(checkInInterval)
    }

    /// Background color for the check-in button
    var checkInButtonBackgroundColor: Color {
        return isCheckInButtonCoolingDown ? Color.blue.opacity(0.6) : Color.blue
    }

    // MARK: - Initialization

    init() {
        // Initialize with mock data or load from UserDefaults
        self.lastCheckIn = UserDefaults.standard.object(forKey: "lastCheckIn") as? Date ?? Date().addingTimeInterval(-5 * 60 * 60) // 5 hours ago
        self.checkInInterval = UserDefaults.standard.double(forKey: "checkInInterval") > 0 ? UserDefaults.standard.double(forKey: "checkInInterval") : 12 * 60 * 60 // 12 hours

        // Load alert state from UserDefaults
        self.isAlertActive = UserDefaults.standard.bool(forKey: "sendAlertActive")

        // Initialize the time display
        updateTimeDisplay()

        // Set initial alert status
        checkAlertStatus()
    }

    deinit {
        cleanUpTimers()
    }

    // MARK: - Timer Methods

    /// Start the timer to update the time display
    func startUpdateTimer() {
        // Clean up any existing timer
        updateTimer?.invalidate()

        // Set up a timer to update the time display every second
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimeDisplay()
        }
    }

    /// Clean up all timers
    func cleanUpTimers() {
        updateTimer?.invalidate()
        updateTimer = nil

        longPressTimer?.invalidate()
        longPressTimer = nil

        tapResetTimer?.invalidate()
        tapResetTimer = nil

        tapShrinkTimer?.invalidate()
        tapShrinkTimer = nil
    }

    // MARK: - Time Display Methods

    /// Update the time until next check-in text
    func updateTimeDisplay() {
        timeUntilNextCheckInText = formatTimeRemaining()
    }

    /// Format the time remaining until check-in expiration
    /// Shows only the two highest units (days and hours, or hours and minutes)
    private func formatTimeRemaining() -> String {
        let now = Date()
        let timeRemaining = checkInExpiration.timeIntervalSince(now)

        if timeRemaining <= 0 {
            return "Overdue"
        }

        // Calculate the components
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour, .minute, .second], from: now, to: checkInExpiration)

        // Get the values
        let days = components.day ?? 0
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        let seconds = components.second ?? 0

        // Format based on the highest two units
        if days > 0 {
            // Show days and hours
            return String(format: "%dd %dh", days, hours)
        } else if hours > 0 {
            // Show hours and minutes
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            // Show minutes and seconds
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            // Only seconds left
            return String(format: "%ds", seconds)
        }
    }

    /// Calculate the progress for the check-in circle (0.0 to 1.0)
    func calculateCheckInProgress() -> CGFloat {
        let now = Date()
        let totalInterval = checkInInterval
        let elapsed = now.timeIntervalSince(lastCheckIn)
        let remaining = max(0, totalInterval - elapsed)
        return CGFloat(remaining / totalInterval)
    }

    // MARK: - Check-in Methods

    /// Perform a check-in action
    func performCheckIn() {
        // Only process if not in cooling down state
        guard !isCheckInButtonCoolingDown else { return }

        // Add haptic feedback
        HapticFeedback.notificationFeedback(type: .success)

        // Update the check-in time
        lastCheckIn = Date()

        // Save to UserDefaults
        UserDefaults.standard.set(lastCheckIn, forKey: "lastCheckIn")
        UserDefaults.standard.set(checkInExpiration, forKey: "checkInExpiration")

        // Force update the time display immediately
        updateTimeDisplay()

        // Show a silent notification for check-in
        NotificationManager.shared.showCheckInNotification()

        // Set cooling down state
        isCheckInButtonCoolingDown = true

        // Reset after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.isCheckInButtonCoolingDown = false
        }
    }

    // MARK: - Alert Button Methods

    /// Check if alert is active and set canDeactivateAlert and canActivateAlert accordingly
    func checkAlertStatus() {
        if isAlertActive {
            canDeactivateAlert = true
            canActivateAlert = false // Can't activate when alert is already active
        } else {
            canActivateAlert = true
        }
    }

    /// Handle tap on the alert button
    func handleAlertButtonTap() {
        if isAlertActive {
            // If alert is active, tapping doesn't do anything (use long press to deactivate)
            return
        }

        // If we're already animating the final tap or can't activate alert, don't process more taps
        if isAnimatingFinalTap || !canActivateAlert {
            return
        }

        // Always provide haptic feedback for each tap to improve user experience
        HapticFeedback.triggerHaptic()

        let now = Date()

        // Cancel any existing reset timer
        tapResetTimer?.invalidate()
        tapResetTimer = nil

        // Cancel any existing shrink timer
        tapShrinkTimer?.invalidate()
        tapShrinkTimer = nil

        // Check if this is a consecutive tap (within 2 seconds of the last tap)
        if let lastTap = lastTapTime, now.timeIntervalSince(lastTap) < 2.0 {
            consecutiveTaps += 1

            // Increase tap progress by 20% (0.2) with each tap
            // Use DispatchQueue.main.async to ensure UI updates happen on the main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.tapProgress = min(1.0, CGFloat(self.consecutiveTaps) * 0.2) // 5 taps * 0.2 = 1.0 (100%)
            }

            // If we've reached 5 taps, prepare to activate the alert
            if consecutiveTaps >= 5 && !isAnimatingFinalTap {
                isAnimatingFinalTap = true
                shouldActivateAlert = true

                // Animate to full width on the main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    withAnimation(.linear(duration: 0.3)) {
                        self.tapProgress = 1.0
                    }
                }

                // Wait for animation to complete before activating alert
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                    guard let self = self, self.shouldActivateAlert else { return }

                    self.isAlertActive = true
                    self.consecutiveTaps = 0
                    self.lastTapTime = nil
                    self.tapProgress = 0.0
                    self.canDeactivateAlert = false
                    self.isAnimatingFinalTap = false
                    self.shouldActivateAlert = false

                    // Directly trigger the alert without confirmation
                    self.triggerAlert()

                    // Provide success haptic feedback
                    HapticFeedback.notificationFeedback(type: .success)

                    // Enable deactivation after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.canDeactivateAlert = true
                    }
                }
            }
        } else {
            // Start a new sequence of taps
            consecutiveTaps = 1
            // Update UI on main thread
            DispatchQueue.main.async { [weak self] in
                self?.tapProgress = 0.2 // 20% for the first tap
            }
        }

        // Update the last tap time
        lastTapTime = now

        // Create a new reset timer (2 seconds - as specified in the requirements)
        // Use RunLoop.main to ensure the timer runs on the main thread
        tapResetTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.consecutiveTaps > 0 && self.consecutiveTaps < 5 {
                self.consecutiveTaps = 0
                self.lastTapTime = nil

                // Start the shrink timer to gradually reduce the progress bar
                self.startShrinkTimer()
            }
        }
        RunLoop.main.add(tapResetTimer!, forMode: .common)

        // Start the shrink timer to gradually reduce the progress bar if not tapped again
        startShrinkTimer()
    }

    /// Start the long press timer
    func startLongPress() {
        // If already long pressing, don't restart the timer
        guard !isLongPressing else { return }

        // Initial haptic feedback to indicate the hold has started
        HapticFeedback.lightImpact()

        // Reset any existing timer
        longPressTimer?.invalidate()
        longPressTimer = nil

        // Start fresh
        isLongPressing = true
        longPressProgress = 0.0

        // Create a timer that updates the progress every 0.05 seconds (smoother updates)
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            if self.longPressProgress < 1.0 {
                self.longPressProgress += 0.0167 // Increase by ~1.67% each time (reaches 100% in 3 seconds)

                // Add haptic feedback at 30%, 60%, 90% progress points
                if Int(self.longPressProgress * 100) == 30 ||
                    Int(self.longPressProgress * 100) == 60 ||
                    Int(self.longPressProgress * 100) == 90 {
                    HapticFeedback.lightImpact()
                }
            } else {
                // Progress is complete
                self.longPressTimer?.invalidate()
                self.longPressTimer = nil

                // If the user is still pressing, deactivate the alert
                if self.isAlertActive && self.canDeactivateAlert && self.isLongPressing {
                    self.isAlertActive = false
                    self.resetLongPress()
                    self.canDeactivateAlert = false
                    self.canActivateAlert = false // Disable activation temporarily

                    // Save alert state to UserDefaults
                    UserDefaults.standard.set(false, forKey: "sendAlertActive")

                    // Haptic feedback
                    HapticFeedback.notificationFeedback(type: .success)

                    // Show a silent notification for alert deactivation
                    NotificationManager.shared.showAlertDeactivationNotification()

                    // Enable activation after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.canActivateAlert = true
                    }
                }
            }
        }
    }

    /// Handle long press ended
    func handleLongPressEnded() {
        if isAlertActive && canDeactivateAlert && isLongPressing && longPressProgress >= 0.99 {
            isAlertActive = false
            resetLongPress()
            canDeactivateAlert = false
            canActivateAlert = false // Disable activation temporarily

            // Save alert state to UserDefaults
            UserDefaults.standard.set(false, forKey: "sendAlertActive")

            // Haptic feedback
            HapticFeedback.notificationFeedback(type: .success)

            // Show a silent notification for alert deactivation
            NotificationManager.shared.showAlertDeactivationNotification()

            // Enable activation after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.canActivateAlert = true
            }
        }
    }

    /// Handle drag gesture changed
    func handleDragGestureChanged() {
        // User is pressing down
        if isAlertActive && canDeactivateAlert && !isLongPressing {
            startLongPress()
        }
    }

    /// Handle drag gesture ended
    func handleDragGestureEnded() {
        // User lifted finger
        if isLongPressing {
            resetLongPress()
        }
    }

    /// Reset the long press state
    func resetLongPress() {
        isLongPressing = false
        longPressProgress = 0.0
        longPressTimer?.invalidate()
        longPressTimer = nil
    }

    /// Start the timer to gradually shrink the tap progress bar
    func startShrinkTimer() {
        // Cancel any existing shrink timer
        tapShrinkTimer?.invalidate()
        tapShrinkTimer = nil

        // Don't start shrinking if we're in the final animation
        if isAnimatingFinalTap {
            return
        }

        // Only start if there's progress to shrink
        guard tapProgress > 0 else { return }

        // Create a timer that gradually reduces the progress
        tapShrinkTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Don't shrink if we're in the final animation
            if self.isAnimatingFinalTap {
                self.tapShrinkTimer?.invalidate()
                self.tapShrinkTimer = nil
                return
            }

            // Update UI on main thread
            DispatchQueue.main.async {
                // Reduce by 2% each time
                self.tapProgress = max(0, self.tapProgress - 0.02)

                // If progress reaches 0, stop the timer
                if self.tapProgress <= 0 {
                    self.tapProgress = 0
                    self.tapShrinkTimer?.invalidate()
                    self.tapShrinkTimer = nil
                }
            }
        }
        // Add to RunLoop.main to ensure it runs on the main thread
        RunLoop.main.add(tapShrinkTimer!, forMode: .common)
    }

    /// Trigger an alert to responders
    func triggerAlert() {
        // Save alert state to UserDefaults
        UserDefaults.standard.set(true, forKey: "sendAlertActive")

        // Show a silent notification for alert activation that is tracked in the notification center
        NotificationManager.shared.showAlertActivationNotification()
    }
}