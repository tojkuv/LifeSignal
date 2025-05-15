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
            // Format time ago directly
            let calendar = Calendar.current
            let now = Date()
            let components = calendar.dateComponents([.minute, .hour, .day], from: pingTime, to: now)

            if let day = components.day, day > 0 {
                return "Pinged " + (day == 1 ? "yesterday" : "\(day) days ago")
            } else if let hour = components.hour, hour > 0 {
                return "Pinged " + (hour == 1 ? "an hour ago" : "\(hour) hours ago")
            } else if let minute = components.minute, minute > 0 {
                return "Pinged " + (minute == 1 ? "a minute ago" : "\(minute) minutes ago")
            } else {
                return "Pinged just now"
            }
        }
        return ""
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(contact.name.prefix(1)))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                )

            // Name and status
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(.body)
                    .foregroundColor(.primary)

                if !statusText.isEmpty {
                    Text(statusText)
                        .font(.footnote)
                        .foregroundColor(contact.hasIncomingPing ? Color.blue : Color.secondary)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)

            Spacer()

            // Trailing content (ping icon - non-interactive as per requirements)
            if contact.hasIncomingPing {
                // Display ping icon without button functionality
                Circle()
                    .fill(Color(UIColor.systemBackground))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 18))
                    )
                    .accessibilityLabel("Ping notification from \(contact.name)")
            }
        }
        .padding()
        .background(
            contact.hasIncomingPing ? Color.blue.opacity(0.1) : Color(UIColor.systemGray6)
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            selectedContactID = ContactID(id: contact.id)
        }
        .sheet(item: $selectedContactID) { id in
            if let contact = userViewModel.contacts.first(where: { $0.id == id.id }) {
                ContactDetailsSheet(contact: contact)
            }
        }
    }
}