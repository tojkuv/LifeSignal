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
    @StateObject private var viewModel = RespondersViewModel()
    var body: some View {
        // Simplified scrollable view with direct LazyVStack
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 12) {
                if viewModel.responders.isEmpty {
                    Text("No responders yet")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else {
                    // Use the sortedResponders from the view model
                    ForEach(viewModel.getSortedResponders()) { responder in
                        ResponderCardView(contact: responder, refreshID: viewModel.refreshID, viewModel: viewModel)
                    }
                }
            }
            .padding(.horizontal)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            // Add observer for refresh notifications
            NotificationCenter.default.addObserver(forName: NSNotification.Name("RefreshRespondersView"), object: nil, queue: .main) { _ in
                viewModel.refreshID = UUID()
            }

            // Force refresh the view when it appears
            viewModel.refreshID = UUID()

            // Debug print contacts
            viewModel.debugPrintContacts()
        }
        .toolbar {
            // Respond to All button (grayed out when there are no pending pings)
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    // Show confirmation alert before responding to all pings
                    if viewModel.pendingPingsCount > 0 {
                        HapticFeedback.selectionFeedback()
                        viewModel.showClearAllPingsConfirmation = true
                    }
                }) {
                    Image(systemName: viewModel.pendingPingsCount > 0 ? "bell.badge.slash.fill" : "bell.fill")
                        .foregroundColor(viewModel.pendingPingsCount > 0 ? .blue : Color.blue.opacity(0.5))
                        .font(.system(size: 18))
                }
                .disabled(viewModel.pendingPingsCount == 0)
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

        .alert(isPresented: $viewModel.showClearAllPingsConfirmation) {
            Alert(
                title: Text("Clear All Pings"),
                message: Text("Are you sure you want to clear all pending pings?"),
                primaryButton: .default(Text("Clear All")) {
                    viewModel.respondToAllPings()
                },
                secondaryButton: .cancel()
            )
        }

    }
}

struct ResponderCardView: View {
    let contact: Contact
    let refreshID: UUID // Used to force refresh when ping state changes
    let viewModel: RespondersViewModel
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
            if let contact = viewModel.responders.first(where: { $0.id == id.id }) {
                ContactDetailsSheetView(contact: contact)
            }
        }
    }
}