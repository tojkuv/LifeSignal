import SwiftUI
import Foundation
import UIKit

struct ResponderCardView: View {
    let contact: Contact
    let refreshID: UUID // Used to force refresh when ping state changes
    @EnvironmentObject private var userViewModel: UserViewModel
    @State private var selectedContactID: ContactID?

    var statusText: String {
        if contact.hasIncomingPing, let pingTime = contact.incomingPingTimestamp {
            return "Pinged \(TimeManager.shared.formatTimeAgo(pingTime))"
        }
        return ""
    }

    var body: some View {
        ContactCardView(
            contact: contact,
            statusColor: contact.hasIncomingPing ? .blue : .secondary,
            statusText: statusText,
            context: .responder,
            trailingContent: {
                if contact.hasIncomingPing {
                    Button(action: {
                        userViewModel.respondToPing(from: contact)
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
                    .accessibilityLabel("Respond to ping from \(contact.name)")
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
    }
}