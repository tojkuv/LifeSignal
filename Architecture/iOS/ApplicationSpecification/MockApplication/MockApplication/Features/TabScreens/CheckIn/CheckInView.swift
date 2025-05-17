import SwiftUI
import Foundation

struct CheckInView: View {
    @EnvironmentObject private var userViewModel: UserViewModel

    // State for UI updates
    @State private var currentTime: Date = Date()
    @State private var isCheckInButtonCoolingDown: Bool = false
    @State private var timeUntilNextCheckInText: String = ""
    @State private var updateTimer: Timer? = nil

    // State for alert activation/deactivation
    @State private var consecutiveTaps: Int = 0
    @State private var isLongPressing: Bool = false
    @State private var longPressTimer: Timer? = nil
    @State private var longPressProgress: CGFloat = 0.0
    @State private var lastTapTime: Date? = nil
    @State private var canDeactivateAlert: Bool = false
    @State private var canActivateAlert: Bool = true // New state to track if button can receive taps
    @State private var tapResetTimer: Timer? = nil
    @State private var tapProgress: CGFloat = 0.0
    @State private var tapShrinkTimer: Timer? = nil
    @State private var isAnimatingFinalTap: Bool = false
    @State private var shouldActivateAlert: Bool = false

    // MARK: - Helper Methods

    /// Calculate the progress for the check-in circle (0.0 to 1.0)
    private func calculateCheckInProgress() -> CGFloat {
        let now = Date()
        let totalInterval = userViewModel.checkInInterval
        let elapsed = now.timeIntervalSince(userViewModel.lastCheckIn)
        let remaining = max(0, totalInterval - elapsed)
        return CGFloat(remaining / totalInterval)
    }

    /// Format the time remaining until check-in expiration
    /// Shows only the two highest units (days and hours, or hours and minutes)
    private func formatTimeRemaining() -> String {
        let now = Date()
        let checkInExpiration = userViewModel.checkInExpiration
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

    /// Update the time until next check-in text
    private func updateTimeDisplay() {
        timeUntilNextCheckInText = formatTimeRemaining()
        // Force UI update
        currentTime = Date()
    }

    /// Check if alert is active when view appears and set canDeactivateAlert and canActivateAlert accordingly
    private func checkAlertStatus() {
        if userViewModel.sendAlertActive {
            canDeactivateAlert = true
            canActivateAlert = false // Can't activate when alert is already active
            print("DEBUG: Alert is active, canDeactivateAlert set to true, canActivateAlert set to false")
        } else {
            canActivateAlert = true
            print("DEBUG: Alert is not active, canActivateAlert set to true")
        }
    }

    var body: some View {
        // Scrollable view for better horizontal mode support
        ScrollView(.vertical, showsIndicators: true) {
            // Single vertical stack for the entire view
            // Use equal spacing between all components
            VStack {
                // Use Spacer with minLength to ensure equal spacing
                Spacer(minLength: 16)
                // Top spacer for equal spacing
                // Alert Button
                ZStack(alignment: .center) {
                    Button(action: {
                        handleAlertButtonTap()
                    }) {
                        ZStack {
                            // Background
                            RoundedRectangle(cornerRadius: 12)
                                .fill(userViewModel.sendAlertActive ? Color.red.opacity(0.3) : Color(UIColor.secondarySystemGroupedBackground))
                                .frame(maxWidth: .infinity)
                                .frame(height: 100) // Same height as countdown

                            // Progress animation layer (below text)
                            if !userViewModel.sendAlertActive {
                                GeometryReader { geometry in
                                    // Rectangle that grows from center to edges
                                    Rectangle()
                                        .fill(Color.red.opacity(0.3)) // Use the same red color as the active alert button
                                        .frame(width: geometry.size.width * tapProgress, height: geometry.size.height)
                                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                                        .opacity(0.7) // Reduce opacity to ensure text remains visible in light mode
                                }
                                .animation(.linear(duration: 0.3), value: tapProgress)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            // Deactivation animation layer (below text)
                            if isLongPressing && userViewModel.sendAlertActive && canDeactivateAlert {
                                GeometryReader { geometry in
                                    // Growing rectangle that expands horizontally from center
                                    Rectangle()
                                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                                        .frame(width: geometry.size.width * longPressProgress, height: geometry.size.height)
                                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                                }
                                .animation(.linear, value: longPressProgress)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            // Stack for main text and subtext
                            VStack(alignment: .center, spacing: 4) {
                                // Main button text
                                Text(userViewModel.sendAlertActive ? "Alert Is Active" : "Activate Alert")
                                    .font(.system(size: 18, weight: .semibold))
                                    .tracking(0.5) // Add letter spacing for better readability
                                    .foregroundColor(.primary) // Always use primary color for main text

                                // Subtext - directly below main text
                                if userViewModel.sendAlertActive && canDeactivateAlert {
                                    // "Hold to deactivate" text (visible whenever alert is active and can be deactivated)
                                    Text("Hold to Deactivate")
                                        .font(.system(size: 10, weight: .medium))
                                        .tracking(0.5) // Add letter spacing for better readability
                                        .foregroundColor(.secondary) // Use secondary color for subtext
                                } else if !userViewModel.sendAlertActive && canActivateAlert {
                                    // "Tap repeatedly to activate" text (visible whenever alert is not active and button can receive taps)
                                    Text("Tap Repeatedly to Activate")
                                        .font(.system(size: 10, weight: .medium))
                                        .tracking(0.5) // Add letter spacing for better readability
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
                            if userViewModel.sendAlertActive && canDeactivateAlert {
                                startLongPress()
                            }
                        }
                        .onEnded { _ in
                            print("DEBUG: Long press ended, isLongPressing: \(isLongPressing), progress: \(longPressProgress)")
                            if userViewModel.sendAlertActive && canDeactivateAlert && isLongPressing && longPressProgress >= 0.99 {
                                print("DEBUG: Deactivating alert")
                                userViewModel.toggleSendAlertActive(false)
                                resetLongPress()
                                canDeactivateAlert = false
                                canActivateAlert = false // Disable activation temporarily
                                // Haptic feedback
                                HapticFeedback.notificationFeedback(type: .success)

                                // Enable activation after 2 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    print("DEBUG: 2 second delay passed, can activate alert now")
                                    self.canActivateAlert = true
                                }
                            }
                        }
                )
                // Add a DragGesture to detect when the user's finger moves away
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            // User is pressing down
                            if userViewModel.sendAlertActive && canDeactivateAlert && !isLongPressing {
                                startLongPress()
                            }
                        }
                        .onEnded { _ in
                            // User lifted finger
                            if isLongPressing {
                                resetLongPress()
                            }
                        }
                )

                // Subtext has been moved inside the button's VStack
            }
            .padding(.horizontal)

                // Equal spacing between components
                Spacer(minLength: 16)

                // Main countdown display - fixed height with centered style
                VStack {
                    Text("Interval Time Left")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(0.5) // Add letter spacing for better readability
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 12)

                    // Center content vertically and horizontally
                    // Time text (centered)
                    Text(timeUntilNextCheckInText)
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
                .padding(.horizontal)

                // Equal spacing between components
                Spacer(minLength: 16)

                // Check-in button - same height as alert button (100)
                Button(action: {
                    // Only process if not in cooling down state
                    if !isCheckInButtonCoolingDown {
                        // Add haptic feedback
                        HapticFeedback.notificationFeedback(type: .success)

                        // Update the user view model to check in
                        userViewModel.checkIn()

                        // Force update the time display immediately
                        updateTimeDisplay()

                        // Note: The userViewModel.checkIn() method already triggers the silent notification

                        // Set cooling down state
                        isCheckInButtonCoolingDown = true

                        // Reset after 1 second
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            isCheckInButtonCoolingDown = false
                        }
                    }
                }) {
                    Text("Check-in")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(0.5) // Add letter spacing for better readability
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200) // Twice the height of alert button
                        .background(isCheckInButtonCoolingDown ? Color.blue.opacity(0.6) : Color.blue)
                        .cornerRadius(12)
                }
                .disabled(isCheckInButtonCoolingDown)
                .padding(.horizontal)
                .padding(.bottom, 8) // Extra bottom padding to avoid tab bar clipping
                // Bottom spacer for equal spacing
                Spacer(minLength: 16)
            }
            .padding(.vertical, 8)
        }
        // Add some horizontal padding to the scroll view
        .padding(.horizontal, 8)
        // Adjust for safe area insets to avoid tab bar clipping
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            // Initialize the time display
            updateTimeDisplay()

            // Check if alert is already active when view appears
            checkAlertStatus()

            // Set up a timer to update the time display every second
            updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                self.updateTimeDisplay()
            }
        }
        .onDisappear {
            // Clean up the timer when the view disappears
            updateTimer?.invalidate()
            updateTimer = nil
        }

        .alert(isPresented: $userViewModel.showAlertConfirmation) {
            Alert(
                title: Text("Confirm Alert"),
                message: Text("Are you sure you want to send an alert to your responders?"),
                primaryButton: .destructive(Text("Send Alert")) {
                    HapticFeedback.notificationFeedback(type: .error)
                    userViewModel.triggerAlert()
                },
                secondaryButton: .cancel()
            )
        }
        .onDisappear {
            // Clean up timers when view disappears
            longPressTimer?.invalidate()
            longPressTimer = nil
            tapResetTimer?.invalidate()
            tapResetTimer = nil
            tapShrinkTimer?.invalidate()
            tapShrinkTimer = nil

            // Reset animation states
            isAnimatingFinalTap = false
            shouldActivateAlert = false
        }
    }
}

// MARK: - Alert Button Methods
extension CheckInView {
    /// Handle tap on the alert button
    func handleAlertButtonTap() {
        if userViewModel.sendAlertActive {
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

        // Haptic feedback is now at the beginning of the function

        // Check if this is a consecutive tap (within 2 seconds of the last tap)
        if let lastTap = lastTapTime, now.timeIntervalSince(lastTap) < 2.0 {
            consecutiveTaps += 1
            print("DEBUG: Consecutive tap #\(consecutiveTaps)")

            // Increase tap progress by 20% (0.2) with each tap
            // Use DispatchQueue.main.async to ensure UI updates happen on the main thread
            DispatchQueue.main.async {
                self.tapProgress = min(1.0, CGFloat(self.consecutiveTaps) * 0.2) // 5 taps * 0.2 = 1.0 (100%)
            }

            // If we've reached 5 taps, prepare to activate the alert
            if consecutiveTaps >= 5 && !isAnimatingFinalTap {
                print("DEBUG: 5 taps reached, animating to full width")
                isAnimatingFinalTap = true
                shouldActivateAlert = true

                // Animate to full width on the main thread
                DispatchQueue.main.async {
                    withAnimation(.linear(duration: 0.3)) {
                        self.tapProgress = 1.0
                    }
                }

                // Wait for animation to complete before activating alert
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    if self.shouldActivateAlert {
                        print("DEBUG: Animation complete, activating alert")
                        self.userViewModel.toggleSendAlertActive(true)
                        self.consecutiveTaps = 0
                        self.lastTapTime = nil
                        self.tapProgress = 0.0
                        self.canDeactivateAlert = false
                        self.isAnimatingFinalTap = false
                        self.shouldActivateAlert = false

                        // Provide success haptic feedback
                        HapticFeedback.notificationFeedback(type: .success)

                        // Enable deactivation after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            print("DEBUG: 2 second delay passed, can deactivate alert now")
                            self.canDeactivateAlert = true
                        }
                    }
                }
            }
        } else {
            // Start a new sequence of taps
            consecutiveTaps = 1
            // Update UI on main thread
            DispatchQueue.main.async {
                self.tapProgress = 0.2 // 20% for the first tap
            }
            print("DEBUG: Starting new tap sequence")
        }

        // Update the last tap time
        lastTapTime = now

        // Create a new reset timer (2 seconds - as specified in the requirements)
        // Use RunLoop.main to ensure the timer runs on the main thread
        tapResetTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            if self.consecutiveTaps > 0 && self.consecutiveTaps < 5 {
                print("DEBUG: Tap sequence timed out, resetting counter from \(self.consecutiveTaps) to 0")
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

        print("DEBUG: Starting long press, canDeactivateAlert: \(canDeactivateAlert)")

        // Initial haptic feedback to indicate the hold has started
        HapticFeedback.lightImpact()

        // Reset any existing timer
        longPressTimer?.invalidate()
        longPressTimer = nil

        // Start fresh
        isLongPressing = true
        longPressProgress = 0.0

        // Create a timer that updates the progress every 0.05 seconds (smoother updates)
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if self.longPressProgress < 1.0 {
                self.longPressProgress += 0.0167 // Increase by ~1.67% each time (reaches 100% in 3 seconds)
                // Print progress every 10%
                if Int(self.longPressProgress * 100) % 10 == 0 {
                    print("DEBUG: Long press progress: \(Int(self.longPressProgress * 100))%")

                    // Add haptic feedback at 25%, 50%, 75% progress points
                    if Int(self.longPressProgress * 100) == 30 ||
                       Int(self.longPressProgress * 100) == 60 ||
                       Int(self.longPressProgress * 100) == 90 {
                        HapticFeedback.lightImpact()
                    }
                }
            } else {
                // Progress is complete, but we'll let the gesture's onEnded handle the action
                print("DEBUG: Long press progress complete")
                self.longPressTimer?.invalidate()
                self.longPressTimer = nil

                // If the user is still pressing, deactivate the alert
                if self.userViewModel.sendAlertActive && self.canDeactivateAlert && self.isLongPressing {
                    print("DEBUG: Timer completed, deactivating alert")
                    self.userViewModel.toggleSendAlertActive(false)
                    self.resetLongPress()
                    self.canDeactivateAlert = false
                    self.canActivateAlert = false // Disable activation temporarily
                    // Haptic feedback
                    HapticFeedback.notificationFeedback(type: .success)

                    // Enable activation after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        print("DEBUG: 2 second delay passed, can activate alert now")
                        self.canActivateAlert = true
                    }
                }
            }
        }
    }

    /// Reset the long press state
    func resetLongPress() {
        print("DEBUG: Resetting long press, progress was: \(Int(longPressProgress * 100))%")
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
        tapShrinkTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
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
}

#Preview {
    CheckInView()
        .environmentObject(UserViewModel())
}
