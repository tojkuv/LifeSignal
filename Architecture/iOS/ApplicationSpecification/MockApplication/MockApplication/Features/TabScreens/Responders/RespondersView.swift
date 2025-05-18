import SwiftUI
import Foundation
import UIKit
import AVFoundation
import PhotosUI

// Extension to add partitioned functionality to Array
extension Array {
    func partitioned(by predicate: (Element) -> Bool) -> ([Element], [Element]) {
        var matching = [Element]()
        var nonMatching = [Element]()

        for element in self {
            if predicate(element) {
                matching.append(element)
            } else {
                nonMatching.append(element)
            }
        }

        return (matching, nonMatching)
    }
}

struct RespondersView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @State private var showCheckInConfirmation = false
    @State private var showClearAllPingsConfirmation = false
    @State private var refreshID = UUID() // Used to force refresh the view

    /// Computed property to sort responders with pending pings at the top
    private var sortedResponders: [Contact] {
        let responders = userViewModel.responders

        // Safety check - if responders is empty, return an empty array
        if responders.isEmpty {
            return []
        }

        // Partition into responders with incoming pings and others
        let (pendingPings, others) = responders.partitioned { $0.hasIncomingPing }

        // Sort pending pings by most recent incoming ping timestamp
        let sortedPendingPings = pendingPings.sorted {
            ($0.incomingPingTimestamp ?? .distantPast) > ($1.incomingPingTimestamp ?? .distantPast)
        }

        // Sort others alphabetically
        let sortedOthers = others.sorted { $0.name < $1.name }

        // Combine with pending pings at the top
        return sortedPendingPings + sortedOthers
    }

    var body: some View {
        // Simplified scrollable view with direct LazyVStack
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 12) {
                if userViewModel.responders.isEmpty {
                    Text("No responders yet")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else {
                    // Use the sortedResponders directly
                    ForEach(sortedResponders) { responder in
                        ResponderCardView(contact: responder, refreshID: refreshID)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            // Add observer for refresh notifications
            NotificationCenter.default.addObserver(forName: NSNotification.Name("RefreshRespondersView"), object: nil, queue: .main) { _ in
                refreshID = UUID()
            }

            // Force refresh the view when it appears
            refreshID = UUID()

            // Debug print contacts
            userViewModel.debugPrintContacts()
        }
        .toolbar {
            // Respond to All button (grayed out when there are no pending pings)
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    // Show confirmation alert before responding to all pings
                    if userViewModel.pendingPingsCount > 0 {
                        HapticFeedback.selectionFeedback()
                        showClearAllPingsConfirmation = true
                    }
                }) {
                    Image(systemName: userViewModel.pendingPingsCount > 0 ? "bell.badge.slash.fill" : "bell.fill")
                        .foregroundColor(userViewModel.pendingPingsCount > 0 ? .blue : Color.blue.opacity(0.5))
                        .font(.system(size: 18))
                }
                .disabled(userViewModel.pendingPingsCount == 0)
                .hapticFeedback(style: .light)
            }

            // Notification Center button
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: NotificationCenterView()) {
                    Image(systemName: "square.fill.text.grid.1x2")
                }
                .hapticFeedback(style: .light)
            }
        }


        .alert(isPresented: $showCheckInConfirmation) {
            Alert(
                title: Text("Confirm Check-in"),
                message: Text("Are you sure you want to check in now? This will reset your timer."),
                primaryButton: .default(Text("Check In")) {
                    userViewModel.checkIn()
                },
                secondaryButton: .cancel()
            )
        }

        .alert(isPresented: $showClearAllPingsConfirmation) {
            Alert(
                title: Text("Clear All Pings"),
                message: Text("Are you sure you want to clear all pending pings?"),
                primaryButton: .default(Text("Clear All")) {
                    // Respond to all pings
                    for contact in userViewModel.contacts.filter({ $0.hasIncomingPing }) {
                        userViewModel.respondToPing(from: contact)
                    }
                    // Force refresh immediately
                    refreshID = UUID()
                    // Post notification to refresh other views that might be affected
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshRespondersView"), object: nil)
                    // Force UI update for badge counter
                    userViewModel.objectWillChange.send()
                    // Show a silent local notification
                    NotificationManager.shared.showAllPingsClearedNotification()
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            // Refresh the view when it appears
            refreshID = UUID()
        }
    }
}

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
                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
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
            contact.hasIncomingPing ? Color.blue.opacity(0.1) : Color(UIColor.secondarySystemGroupedBackground)
        )
        .cornerRadius(12)
        .onTapGesture {
            HapticFeedback.triggerHaptic()
            selectedContactID = ContactID(id: contact.id)
        }
        .sheet(item: $selectedContactID) { id in
            if let contact = userViewModel.contacts.first(where: { $0.id == id.id }) {
                ContactDetailsSheet(contact: contact)
            }
        }
    }
}