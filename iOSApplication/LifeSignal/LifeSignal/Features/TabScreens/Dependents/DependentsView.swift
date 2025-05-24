import SwiftUI
import Foundation
import UIKit
import AVFoundation
import PhotosUI
import ComposableArchitecture
import Perception
struct DependentsView: View {
    @Bindable var store: StoreOf<DependentsFeature>
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Computed Properties

    /// Computed property to get sorted dependents from the view model
    private var sortedDependents: [Contact] {
        // This will be recalculated when the view model's refreshID changes
        return store.dependents
    }

    var body: some View {
        WithPerceptionTracking {
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
                store.send(.refreshDependents)
                print("DependentsView appeared with sort mode: \("Default")")
                print("DependentsView has \(store.dependents.count) dependents")

                // Debug: print all dependents
                for (index, dependent) in store.dependents.enumerated() {
                    print("Dependent \(index+1): \(dependent.name) (isDependent: \(dependent.isDependent))")
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        ForEach(DependentsFeature.State.SortMode.allCases, id: \.self) { sortMode in
                            Button(action: {
                                store.send(.setSortMode(sortMode))
                            }) {
                                Label(sortMode.rawValue, systemImage: store.sortMode == sortMode ? "checkmark" : "")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                            Text(store.sortMode.rawValue)
                                .font(.caption)
                        }
                    }
                    .accessibilityLabel("Sort Dependents")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // TODO: Add notification center navigation
                    } label: {
                        Image(systemName: "square.fill.text.grid.1x2")
                    }
                }
            }
            .alert(
                $store.scope(state: \.confirmationAlert, action: \.confirmationAlert)
            )
            .sheet(
                item: $store.scope(state: \.contactDetails, action: \.contactDetails)
            ) { store in
                ContactDetailsSheetView(store: store)
            }
        }
    }

    /// Create a dependent card view for a contact
    /// - Parameter contact: The contact to create a card for
    /// - Returns: A view for the contact card
    /// Get the background color for a contact card based on status
    /// Get status text for a contact
    private func statusText(for contact: Contact) -> String {
        if contact.manualAlertActive {
            return "Alert Active"
        } else if contact.isResponder {
            return "Responder"
        } else {
            return "Dependent"
        }
    }
    
    /// Get status color for a contact
    private func statusColor(for contact: Contact) -> Color {
        if contact.manualAlertActive {
            return .red
        } else if contact.isResponder {
            return .green
        } else {
            return .secondary
        }
    }
    
    private func cardBackgroundColor(for contact: Contact) -> Color {
        if contact.manualAlertActive {
            return Color.red.opacity(0.1)
        } else if contact.isResponder {
            return Color.green.opacity(0.1)
        } else {
            return Color(UIColor.secondarySystemGroupedBackground)
        }
    }
    
    private func dependentCardView(for contact: Contact) -> some View {
        cardContent(for: contact)
            .padding() // This padding is inside the card
            .background(cardBackgroundColor(for: contact))
            .cornerRadius(12)
            .modifier(CardFlashingAnimation(isActive: contact.manualAlertActive))
            .onTapGesture {
                store.send(.selectContact(contact))
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
                pingBadge
            }
        }
    }

    /// Ping badge view
    private var pingBadge: some View {
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

            let statusText = statusText(for: contact)
            if !statusText.isEmpty {
                Text(statusText)
                    .font(.footnote)
                    .foregroundColor(statusColor(for: contact))
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

