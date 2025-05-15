import SwiftUI
import Foundation
import UIKit
import AVFoundation
import PhotosUI

struct DependentsView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @StateObject private var viewModel = DependentsViewModel()

    // MARK: - Lifecycle

    init() {
        // Create a view model
        _viewModel = StateObject(wrappedValue: DependentsViewModel())
    }

    /// Computed property to get sorted dependents from the view model
    private var sortedDependents: [Contact] {
        // This will be recalculated when the view model's refreshID changes
        return viewModel.getSortedDependents()
    }

    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if userViewModel.dependents.isEmpty {
                        Text("No dependents yet")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else {
                        ForEach(sortedDependents) { dependent in
                            DependentCardView(contact: dependent, refreshID: viewModel.refreshID)
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
            NotificationCenter.default.addObserver(forName: NSNotification.Name("RefreshDependentsView"), object: nil, queue: .main) { _ in
                refreshID = UUID()
            }

            // Force refresh when view appears to ensure sort is applied
            refreshID = UUID()
            print("DependentsView appeared with sort mode: \(sortMode.rawValue)")
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    ForEach(SortMode.allCases) { mode in
                        Button(action: {
                            sortMode = mode
                            // Force refresh when sort mode changes
                            refreshID = UUID()
                            print("Sort mode changed to: \(mode.rawValue)")
                        }) {
                            Label(mode.rawValue, systemImage: sortMode == mode ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(sortMode.rawValue)
                            .font(.caption)
                    }
                }
                .accessibilityLabel("Sort Dependents")
            }
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
                    name: "Jordan Taylor",
                    phone: "555-123-4567",
                    qrCodeId: code,
                    lastCheckIn: Date(),
                    note: "I work night shifts at City Hospital (7PM-7AM). If no response, contact my supervisor Dr. Smith at 555-999-8888. I have a service dog named Max who stays with me. Emergency contacts: Sister Amy (555-777-4444), Building security (555-666-5555). I have a heart condition and take medication daily.",
                    manualAlertActive: false,
                    isNonResponsive: false,
                    hasIncomingPing: false,
                    incomingPingTimestamp: nil,
                    hasOutgoingPing: false,
                    outgoingPingTimestamp: nil,
                    manualAlertTimestamp: nil,
                    isResponder: false,
                    isDependent: true
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
            // Sync view model with user view model
            viewModel.setUserViewModel(userViewModel)
        }
    }
}