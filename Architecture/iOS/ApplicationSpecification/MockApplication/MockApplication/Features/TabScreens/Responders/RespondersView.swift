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
        VStack {
            ScrollView {
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
                .padding()
                .padding(.bottom, 30)
            }
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
        .onAppear {
            // Add observer for refresh notifications
            NotificationCenter.default.addObserver(forName: NSNotification.Name("RefreshRespondersView"), object: nil, queue: .main) { _ in
                refreshID = UUID()
            }

            // Force refresh the view when it appears
            refreshID = UUID()
        }
        .toolbar {
            // Respond to All button (grayed out when there are no pending pings)
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    // Respond to all pings
                    for contact in userViewModel.contacts.filter({ $0.hasIncomingPing }) {
                        userViewModel.respondToPing(from: contact)
                    }
                    // Force refresh immediately
                    refreshID = UUID()
                    // Post notification to refresh other views that might be affected
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshRespondersView"), object: nil)
                }) {
                    Image(systemName: userViewModel.pendingPingsCount > 0 ? "bell.badge.slash.fill" : "bell.fill")
                        .foregroundColor(userViewModel.pendingPingsCount > 0 ? .blue : Color.blue.opacity(0.5))
                        .font(.system(size: 18))
                }
                .disabled(userViewModel.pendingPingsCount == 0)
            }

            // QR Scanner button
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    AVCaptureDevice.requestAccess(for: .video) { granted in
                        if granted {
                            DispatchQueue.main.async {
                                showQRScanner = true
                            }
                        } else {
                            DispatchQueue.main.async {
                                showCameraDeniedAlert = true
                            }
                        }
                    }
                }) {
                    Image(systemName: "qrcode.viewfinder")
                }
            }
        }
        .sheet(isPresented: $showQRScanner, onDismiss: {
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
        }) {
            // Use our new QRScannerView from the QRCodeSystem feature
            QRScannerView { result in
                pendingScannedCode = result
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
                    userViewModel.updateLastCheckedIn()
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
        .onAppear {
            // Refresh the view when it appears
            refreshID = UUID()
        }
    }
}