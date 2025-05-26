import SwiftUI
import Foundation
import UIKit
import AVFoundation
import PhotosUI

struct DependentsView: View {
    @StateObject private var viewModel = DependentsViewModel()
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Computed Properties

    /// Computed property to get sorted dependents from the view model
    private var sortedDependents: [Contact] {
        // This will be recalculated when the view model's refreshID changes
        return viewModel.getSortedDependents()
    }

    var body: some View {
        // Simplified scrollable view with direct LazyVStack
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 12) {
                if sortedDependents.isEmpty {
                    Text("No dependents yet")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else {
                    ForEach(sortedDependents) { dependent in
                        dependentCardView(for: dependent)
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
            // Force refresh when view appears to ensure sort is applied
            viewModel.forceRefresh()
            print("DependentsView appeared with sort mode: \(viewModel.displaySortMode)")
            print("DependentsView has \(viewModel.dependents.count) dependents")

            // Debug: print all dependents
            for (index, dependent) in viewModel.dependents.enumerated() {
                print("Dependent \(index+1): \(dependent.name) (isDependent: \(dependent.isDependent))")
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    ForEach(["Time Left", "Name", "Date Added"], id: \.self) { mode in
                        Button(action: {
                            HapticFeedback.selectionFeedback()
                            viewModel.updateSortMode(mode)
                            print("Sort mode changed to: \(mode)")
                        }) {
                            Label(mode, systemImage: viewModel.displaySortMode == mode ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(viewModel.displaySortMode)
                            .font(.caption)
                    }
                }
                .accessibilityLabel("Sort Dependents")
                .simultaneousGesture(TapGesture().onEnded { _ in
                    HapticFeedback.lightImpact()
                })
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: NotificationCenterView()) {
                    Image(systemName: "square.fill.text.grid.1x2")
                }
                .simultaneousGesture(TapGesture().onEnded { _ in
                    HapticFeedback.lightImpact()
                })
            }
        }
        .alert(isPresented: $viewModel.showPingAlert) {
            viewModel.makeAlert()
        }
        .sheet(item: $viewModel.selectedContact) { contact in
            ContactDetailsSheetView(contact: contact)
        }
    }

    /// Create a dependent card view for a contact
    /// - Parameter contact: The contact to create a card for
    /// - Returns: A view for the contact card
    private func dependentCardView(for contact: Contact) -> some View {
        cardContent(for: contact)
            .padding() // This padding is inside the card
            .background(viewModel.cardBackground(for: contact, colorScheme: colorScheme))
            .cornerRadius(12)
            .modifier(CardFlashingAnimation(isActive: contact.manualAlertActive))
            .onTapGesture {
                HapticFeedback.triggerHaptic()
                // Set the selected contact for the sheet presentation
                viewModel.selectedContact = contact
            }
    }

    /// Create the content for a dependent card
    /// - Parameter contact: The contact to create content for
    /// - Returns: A view for the card content
    private func cardContent(for contact: Contact) -> some View {
        HStack(spacing: 12) {
            // Avatar with badge
            avatarView(for: contact)

            // Name and status
            infoView(for: contact)

            Spacer()
        }
    }

    /// Create an avatar view for a contact
    /// - Parameter contact: The contact to create an avatar for
    /// - Returns: A view for the avatar
    private func avatarView(for contact: Contact) -> some View {
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

            // Ping badge (only for ping status)
            if contact.hasOutgoingPing {
                pingBadge()
            }
        }
    }

    /// Ping badge view
    @ViewBuilder
    private func pingBadge() -> some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 20, height: 20)
            .overlay(
                Image(systemName: "bell.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
            )
            .offset(x: 5, y: -5)
    }

    /// Create an info view for a contact
    /// - Parameter contact: The contact to create info for
    /// - Returns: A view for the contact info
    private func infoView(for contact: Contact) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(contact.name)
                    .font(.body)
                    .foregroundColor(.primary)
            }

            let statusText = viewModel.statusText(for: contact)
            if !statusText.isEmpty {
                Text(statusText)
                    .font(.footnote)
                    .foregroundColor(viewModel.statusColor(for: contact, colorScheme: colorScheme))
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
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

