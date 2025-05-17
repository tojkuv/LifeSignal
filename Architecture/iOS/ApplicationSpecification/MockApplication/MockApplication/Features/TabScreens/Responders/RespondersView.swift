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
    @State private var showQRScanner = false
    @State private var showCheckInConfirmation = false
    @State private var showCameraDeniedAlert = false
    @State private var newContact: Contact? = nil
    @State private var pendingScannedCode: String? = nil
    @State private var showContactAddedAlert = false
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
        .sheet(isPresented: $showQRScanner) {
            // Use our new QRScannerView from the QRCodeSystem feature
            QRScannerView { result in
                pendingScannedCode = result
                showQRScanner = false
                // Directly create contact and show Add Contact sheet
                if let code = pendingScannedCode {
                    newContact = Contact(
                        id: UUID().uuidString,
                        name: "Riley Johnson",
                        phone: "555-123-4567",
                        qrCodeId: code,
                        lastCheckIn: Date(),
                        note: "I live with my elderly mother who needs daily medication.",
                        manualAlertActive: false,
                        isNonResponsive: false,
                        hasIncomingPing: false,
                        incomingPingTimestamp: nil,
                        isResponder: true,
                        isDependent: false
                    )
                    pendingScannedCode = nil
                }
            }
        }
        .sheet(item: $newContact, onDismiss: {
            newContact = nil
        }) { contact in
            // Use our new AddContactSheetView from the QRCodeSystem feature
            AddContactSheetView(
                qrCodeId: contact.qrCodeId,
                onAddContact: { confirmedContact in
                    userViewModel.contacts.append(confirmedContact)
                    // Show alert after sheet closes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showContactAddedAlert = true
                    }
                },
                onClose: { newContact = nil }
            )
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
        .alert(isPresented: $showCameraDeniedAlert) {
            Alert(
                title: Text("Camera Access Denied"),
                message: Text("Please enable camera access in Settings to scan QR codes."),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showContactAddedAlert) {
            Alert(
                title: Text("Contact Added"),
                message: Text("The contact was successfully added."),
                dismissButton: .default(Text("OK"))
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