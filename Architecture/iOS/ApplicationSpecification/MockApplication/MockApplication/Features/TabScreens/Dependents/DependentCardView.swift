import SwiftUI
import Foundation
import UIKit

/// A view modifier that creates a flashing animation
struct FlashingAnimation: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? 0.5 : 1.0)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

/// A view modifier that creates a flashing animation for the entire card
struct CardFlashingAnimation: ViewModifier {
    let isActive: Bool
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(isAnimating && isActive ? 0.2 : 0.1))
            )
            .onAppear {
                if isActive {
                    withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                }
            }
    }
}

struct DependentCardView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    let contact: Contact
    let refreshID: UUID // Used to force refresh when ping state changes

    // Use @State for alert control
    @State private var showPingAlert = false
    @State private var isPingConfirmation = false
    @State private var selectedContactID: ContactID?

    // Debug state
    @State private var hasLogged = false

    var statusColor: Color {
        if contact.manualAlertActive {
            return .red
        } else if contact.isNonResponsive {
            return .yellow
        } else {
            return .secondary
        }
    }

    var statusText: String {
        if contact.manualAlertActive {
            return "Alert Active"
        } else if contact.isNonResponsive {
            return "Not responsive"
        } else {
            return contact.formattedTimeRemaining
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Debug logging using onAppear
            Text("")
                .frame(width: 0, height: 0)
                .opacity(0)
                .onAppear {
                    if !hasLogged {
                        print("DependentCardView for \(contact.name) (isDependent: \(contact.isDependent), isResponder: \(contact.isResponder))")
                        hasLogged = true
                    }
                }
            // Avatar with badge
            ZStack(alignment: .topTrailing) {
                // Avatar circle
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(contact.name.prefix(1)))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    )

                // Badge for alert status
                if contact.manualAlertActive || contact.isNonResponsive || contact.hasOutgoingPing {
                    Circle()
                        .fill(contact.manualAlertActive ? Color.red :
                              contact.isNonResponsive ? Color.yellow :
                              Color.blue)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: contact.manualAlertActive ? "exclamationmark.octagon.fill" :
                                  contact.isNonResponsive ? "exclamationmark.triangle.fill" :
                                  "bell.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .modifier(FlashingAnimation())
                        )
                        .offset(x: 5, y: -5)
                }
            }

            // Name and status
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(contact.name)
                        .font(.body)
                        .foregroundColor(.primary)
                }

                if !statusText.isEmpty {
                    Text(statusText)
                        .font(.footnote)
                        .foregroundColor(statusColor)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)

            Spacer()

            // No ping icon here - removed as requested
        }
        .padding()
        .background(
            contact.manualAlertActive ? Color.red.opacity(0.1) :
            contact.isNonResponsive ? Color.yellow.opacity(0.15) :
            Color(UIColor.systemGray6)
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .modifier(CardFlashingAnimation(isActive: contact.manualAlertActive))
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            selectedContactID = ContactID(id: contact.id)
        }
        .sheet(item: $selectedContactID) { id in
            if let contact = userViewModel.contacts.first(where: { $0.id == id.id }) {
                ContactDetailsSheet(contact: contact)
            }
        }
        .alert(isPresented: $showPingAlert) {
            if isPingConfirmation {
                return Alert(
                    title: Text("Ping Sent"),
                    message: Text("The contact was successfully pinged."),
                    dismissButton: .default(Text("OK"))
                )
            } else if contact.hasOutgoingPing {
                return Alert(
                    title: Text("Clear Ping"),
                    message: Text("Do you want to clear the pending ping to this contact?"),
                    primaryButton: .default(Text("Clear")) {
                        // Use the view model to clear the ping
                        userViewModel.clearPing(for: contact)

                        // Debug print
                        print("Clearing ping for contact: \(contact.name)")

                        // Force refresh immediately
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
                    },
                    secondaryButton: .cancel()
                )
            } else {
                return Alert(
                    title: Text("Send Ping"),
                    message: Text("Are you sure you want to ping this contact?"),
                    primaryButton: .default(Text("Ping")) {
                        // Use the view model to ping the dependent
                        userViewModel.pingDependent(contact)

                        // Debug print
                        print("Setting ping for contact: \(contact.name)")

                        // Force refresh immediately
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)

                        // Show confirmation alert
                        isPingConfirmation = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showPingAlert = true
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}