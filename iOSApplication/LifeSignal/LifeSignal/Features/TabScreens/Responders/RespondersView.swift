import SwiftUI
import Foundation
import UIKit
import AVFoundation
import PhotosUI
import ComposableArchitecture
import Perception

struct RespondersView: View {
    @Perception.Bindable var store: StoreOf<RespondersFeature>
    
    var body: some View {
        WithPerceptionTracking {
            // Simplified scrollable view with direct LazyVStack
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 12) {
                    if store.responders.isEmpty {
                        Text("No responders yet")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else {
                        // Use the responders from the feature state
                        ForEach(store.responders) { responder in
                            ResponderCardView(contact: responder, store: store)
                        }
                    }

                    // Add extra padding at the bottom to ensure content doesn't overlap with tab bar
                    Spacer()
                        .frame(height: 20)
                }
                .padding(.horizontal)
                .padding(.bottom, 70) // Add padding to ensure content doesn't overlap with tab bar
            }
            .background(Color(UIColor.systemGroupedBackground))
            .edgesIgnoringSafeArea(.bottom) // Extend background to bottom edge
            .onAppear {
                store.send(.refreshResponders)
            }
            .toolbar {
                // Respond to All button (grayed out when there are no pending pings)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        store.send(.respondToAllPings)
                    }) {
                        Image(systemName: store.pendingPingsCount > 0 ? "bell.badge.slash.fill" : "bell.fill")
                            .foregroundColor(store.pendingPingsCount > 0 ? .blue : Color.blue.opacity(0.5))
                            .font(.system(size: 18))
                    }
                    .disabled(store.pendingPingsCount == 0)
                }

                // Notification Center button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // This should be handled by parent feature if needed
                    }) {
                        Image(systemName: "square.fill.text.grid.1x2")
                    }
                }
            }

            .alert($store.scope(state: \.confirmationAlert, action: \.confirmationAlert))
            .sheet(item: $store.scope(state: \.contactDetails, action: \.contactDetails)) { store in
                ContactDetailsSheetView(store: store)
            }
        }
    }
}

struct ResponderCardView: View {
    let contact: Contact
    let store: StoreOf<RespondersFeature>

    var statusText: String {
        if contact.hasIncomingPing, let pingTime = contact.incomingPingTimestamp {
            // Format time ago directly
            let calendar = Calendar.current
            let now = Date()
            let components = calendar.dateComponents([.minute, .hour, .day], from: pingTime, to: now)

            if let day = components.day, day > 0 {
                return "Pinged you " + (day == 1 ? "yesterday" : "\(day) days ago")
            } else if let hour = components.hour, hour > 0 {
                return "Pinged you " + (hour == 1 ? "an hour ago" : "\(hour) hours ago")
            } else if let minute = components.minute, minute > 0 {
                return "Pinged you " + (minute == 1 ? "a minute ago" : "\(minute) minutes ago")
            } else {
                return "Pinged you just now"
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
        .padding() // This padding is inside the card
        .background(
            contact.hasIncomingPing ? Color.blue.opacity(0.1) : Color(UIColor.secondarySystemGroupedBackground)
        )
        .cornerRadius(12)
        .onTapGesture {
            // Haptic feedback handled by TCA action
            store.send(.selectContact(contact))
        }
    }
}