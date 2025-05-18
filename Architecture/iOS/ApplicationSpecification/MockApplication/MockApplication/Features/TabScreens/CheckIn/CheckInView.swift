import SwiftUI
import Foundation

struct CheckInView: View {
    // Use StateObject to create the view model
    @StateObject private var viewModel = CheckInViewModel()

    var body: some View {
        // Scrollable view for better horizontal mode support
        ScrollView(.vertical, showsIndicators: true) {
            // Single vertical stack for the entire view with equal spacing
            VStack(spacing: 16) {
                // Alert Button
                alertButtonView

                // Countdown display
                countdownView

                // Check-in button
                checkInButtonView
            }
            .padding(.horizontal)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            // Check if alert is already active when view appears
            viewModel.checkAlertStatus()

            // Start the timer to update the time display
            viewModel.startUpdateTimer()
        }
        .onDisappear {
            // Clean up all timers when the view disappears
            viewModel.cleanUpTimers()
        }
    }

    /// Alert button view
    private var alertButtonView: some View {
        ZStack(alignment: .center) {
            Button(action: {
                viewModel.handleAlertButtonTap()
            }) {
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(viewModel.isAlertActive ? Color.red.opacity(0.3) : Color(UIColor.secondarySystemGroupedBackground))
                        .frame(maxWidth: .infinity)
                        .frame(height: 100) // Same height as countdown

                    // Progress animation layer (below text)
                    if !viewModel.isAlertActive {
                        GeometryReader { geometry in
                            // Rectangle that grows from center to edges
                            Rectangle()
                                .fill(Color.red.opacity(0.3)) // Use the same red color as the active alert button
                                .frame(width: geometry.size.width * viewModel.tapProgress, height: geometry.size.height)
                                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                                .opacity(0.7) // Reduce opacity to ensure text remains visible in light mode
                        }
                        .animation(.linear(duration: 0.3), value: viewModel.tapProgress)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Deactivation animation layer (below text)
                    if viewModel.isLongPressing && viewModel.isAlertActive && viewModel.canDeactivateAlert {
                        GeometryReader { geometry in
                            // Growing rectangle that expands horizontally from center
                            Rectangle()
                                .fill(Color(UIColor.secondarySystemGroupedBackground))
                                .frame(width: geometry.size.width * viewModel.longPressProgress, height: geometry.size.height)
                                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        }
                        .animation(.linear, value: viewModel.longPressProgress)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Stack for main text and subtext
                    VStack(alignment: .center, spacing: 4) {
                        // Main button text
                        Text(viewModel.isAlertActive ? "Alert Is Active" : "Activate Alert")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.primary) // Always use primary color for main text

                        // Subtext - directly below main text
                        if viewModel.isAlertActive && viewModel.canDeactivateAlert {
                            // "Hold to deactivate" text (visible whenever alert is active and can be deactivated)
                            Text("Hold to Deactivate")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary) // Use secondary color for subtext
                        } else if !viewModel.isAlertActive && viewModel.canActivateAlert {
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
                        if viewModel.isAlertActive && viewModel.canDeactivateAlert {
                            viewModel.startLongPress()
                        }
                    }
                    .onEnded { _ in
                        viewModel.handleLongPressEnded()
                    }
            )
            // Add a DragGesture to detect when the user's finger moves away
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        viewModel.handleDragGestureChanged()
                    }
                    .onEnded { _ in
                        viewModel.handleDragGestureEnded()
                    }
            )
        }
    }

    /// Countdown view
    private var countdownView: some View {
        VStack {
            Text("Interval Time Left")
                .font(.system(size: 14, weight: .semibold))
                .tracking(0.5) // Add letter spacing for better readability
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 12)

            // Center content vertically and horizontally
            // Time text (centered)
            Text(viewModel.timeUntilNextCheckInText)
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
    private var checkInButtonView: some View {
        Button(action: {
            viewModel.performCheckIn()
        }) {
            Text("Check-in")
                .font(.system(size: 26, weight: .bold))
                .tracking(0.5) // Add letter spacing for better readability
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 200) // Twice the height of alert button
                .background(viewModel.checkInButtonBackgroundColor)
                .cornerRadius(12)
        }
        .disabled(viewModel.isCheckInButtonCoolingDown)
    }
}

#Preview {
    CheckInView()
}
