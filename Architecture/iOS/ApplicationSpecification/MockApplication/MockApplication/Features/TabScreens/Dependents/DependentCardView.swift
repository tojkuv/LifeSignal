import SwiftUI
import Foundation
import UIKit

struct DependentCardView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    let contact: Contact
    let refreshID: UUID // Used to force refresh when ping state changes

    // Use @State for alert control
    @State private var showPingAlert = false
    @State private var isPingConfirmation = false
    @State private var selectedContactID: ContactID?

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
        ContactCardView(
            contact: contact,
            statusColor: statusColor,
            statusText: statusText,
            context: .dependent,
            trailingContent: {
                if contact.hasOutgoingPing {
                    Button(action: {
                        // Show clear ping alert
                        isPingConfirmation = false
                        showPingAlert = true
                    }) {
                        Circle()
                            .fill(Color(UIColor.systemBackground))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "bell.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 18))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Clear ping to \(contact.name)")
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 40, height: 40)
                }
            },
            onTap: {
                triggerHaptic()
                selectedContactID = ContactID(id: contact.id)
            }
        )
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