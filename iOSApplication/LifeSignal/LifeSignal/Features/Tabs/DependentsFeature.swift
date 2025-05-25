import SwiftUI
import Foundation
import UIKit
import AVFoundation
import PhotosUI
import ComposableArchitecture
import Perception

// Define Alert enum outside to avoid circular dependencies
enum DependentsAlert: Equatable {
    case confirmRemove(Contact)
    case confirmPing(Contact)
}

@Reducer
struct DependentsFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.contacts) var allContacts: [Contact] = []
        @Shared(.currentUser) var currentUser: User? = nil
        
        var isLoading = false
        var errorMessage: String?
        var sortMode: SortMode = .timeLeft
        @Presents var contactDetails: ContactDetailsSheetFeature.State?
        @Presents var confirmationAlert: AlertState<DependentsAlert>?
        
        var dependents: [Contact] {
            let filtered = allContacts.filter { contact in
                // Filter for contacts marked as dependents
                contact.isDependent
            }
            
            switch sortMode {
            case .timeLeft:
                return filtered.sorted { (contact1, contact2) in
                    // Sort by time remaining until next check-in is due
                    let now = Date()
                    
                    func timeRemaining(for contact: Contact) -> TimeInterval {
                        guard let lastCheckIn = contact.lastCheckInTime else {
                            return -Double.infinity // No check-in means expired
                        }
                        let timeSince = now.timeIntervalSince(lastCheckIn)
                        return contact.interval - timeSince
                    }
                    
                    let remaining1 = timeRemaining(for: contact1)
                    let remaining2 = timeRemaining(for: contact2)
                    
                    // Sort by time remaining (ascending - least time remaining first)
                    return remaining1 < remaining2
                }
            case .name:
                return filtered.sorted { $0.name < $1.name }
            case .dateAdded:
                return filtered.sorted { $0.lastUpdated > $1.lastUpdated }
            }
        }
        
        enum SortMode: String, CaseIterable, Equatable {
            case timeLeft = "Time Left"
            case name = "Name"
            case dateAdded = "Date Added"
        }
        
        var dependentCount: Int {
            dependents.count
        }
        
        var activeDependents: [Contact] {
            dependents.filter { contact in
                // Consider a dependent "active" if they've checked in recently or have active pings
                contact.hasIncomingPing || contact.hasOutgoingPing || contact.manualAlertActive ||
                (contact.lastCheckInTime?.timeIntervalSinceNow ?? -Double.infinity) > -contact.interval
            }
        }
        
        var alertingDependents: [Contact] {
            dependents.filter { $0.manualAlertActive }
        }

        // MARK: - Formatting Functions

        func statusText(for contact: Contact) -> String {
            if contact.manualAlertActive {
                return "Alert Active"
            } else if contact.isResponder {
                return "Responder"
            } else {
                return "Dependent"
            }
        }

        func statusColor(for contact: Contact) -> Color {
            if contact.manualAlertActive {
                return .red
            } else if contact.isResponder {
                return .green
            } else {
                return .secondary
            }
        }

        func cardBackgroundColor(for contact: Contact) -> Color {
            if contact.manualAlertActive {
                return Color.red.opacity(0.1)
            } else if contact.isResponder {
                return Color.green.opacity(0.1)
            } else {
                return Color(UIColor.secondarySystemGroupedBackground)
            }
        }

        func statusDisplay(for contact: Contact) -> (String, Color) {
            // Determine status based on contact's current state
            if contact.manualAlertActive {
                return ("Alert Active", .red)
            } else if contact.hasIncomingPing {
                return ("Incoming Ping", .orange)
            } else if contact.hasOutgoingPing {
                return ("Outgoing Ping", .blue)
            } else if let lastCheckIn = contact.lastCheckInTime {
                let timeSinceCheckIn = Date().timeIntervalSince(lastCheckIn)
                if timeSinceCheckIn < contact.interval {
                    return ("Active", .green)
                } else if timeSinceCheckIn < contact.interval * 2 {
                    return ("Overdue", .yellow)
                } else {
                    return ("Unresponsive", .red)
                }
            } else {
                return ("No Check-in", .gray)
            }
        }

        func lastSeenText(for date: Date) -> String {
            let now = Date()
            let interval = now.timeIntervalSince(date)

            if interval < 60 {
                return "Just now"
            } else if interval < 3600 {
                let minutes = Int(interval / 60)
                return "\(minutes)m ago"
            } else if interval < 86400 {
                let hours = Int(interval / 3600)
                return "\(hours)h ago"
            } else if interval < 604800 { // 7 days
                let days = Int(interval / 86400)
                return "\(days)d ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                return formatter.string(from: date)
            }
        }

        func intervalText(for interval: TimeInterval) -> String {
            let hours = Int(interval / 3600)
            let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

            if hours > 0 && minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else if hours > 0 {
                return "\(hours)h"
            } else if minutes > 0 {
                return "\(minutes)m"
            } else {
                return "< 1m"
            }
        }

        func contactRoleText(for contact: Contact) -> String {
            if contact.isResponder && contact.isDependent {
                return "Responder & Dependent"
            } else if contact.isResponder {
                return "Responder"
            } else if contact.isDependent {
                return "Dependent"
            } else {
                return "Contact"
            }
        }

        func contactActivityStatus(for contact: Contact) -> (String, Color) {
            // More detailed activity status
            let now = Date()

            // Check for active alerts first
            if contact.manualAlertActive {
                if let alertTime = contact.manualAlertTimestamp {
                    let timeSinceAlert = now.timeIntervalSince(alertTime)
                    if timeSinceAlert < 300 { // 5 minutes
                        return ("🚨 Alert (Just Now)", .red)
                    } else if timeSinceAlert < 3600 { // 1 hour
                        let minutes = Int(timeSinceAlert / 60)
                        return ("🚨 Alert (\(minutes)m ago)", .red)
                    } else {
                        return ("🚨 Alert Active", .red)
                    }
                } else {
                    return ("🚨 Alert Active", .red)
                }
            }

            // Check for pings
            if contact.hasIncomingPing {
                if let pingTime = contact.incomingPingTimestamp {
                    let timeSincePing = now.timeIntervalSince(pingTime)
                    if timeSincePing < 300 { // 5 minutes
                        return ("📥 Pinged (Just Now)", .orange)
                    } else {
                        let minutes = Int(timeSincePing / 60)
                        return ("📥 Pinged (\(minutes)m ago)", .orange)
                    }
                } else {
                    return ("📥 Incoming Ping", .orange)
                }
            }

            if contact.hasOutgoingPing {
                if let pingTime = contact.outgoingPingTimestamp {
                    let timeSincePing = now.timeIntervalSince(pingTime)
                    if timeSincePing < 300 { // 5 minutes
                        return ("📤 Sent Ping (Just Now)", .blue)
                    } else {
                        let minutes = Int(timeSincePing / 60)
                        return ("📤 Sent Ping (\(minutes)m ago)", .blue)
                    }
                } else {
                    return ("📤 Outgoing Ping", .blue)
                }
            }

            // Check check-in status
            if let lastCheckIn = contact.lastCheckInTime {
                let timeSinceCheckIn = now.timeIntervalSince(lastCheckIn)
                let overdueFactor = timeSinceCheckIn / contact.interval

                if overdueFactor < 0.5 {
                    return ("✅ Recently Active", .green)
                } else if overdueFactor < 1.0 {
                    return ("⏰ Active", .green)
                } else if overdueFactor < 1.5 {
                    return ("⚠️ Overdue", .yellow)
                } else if overdueFactor < 2.0 {
                    return ("❗ Late Check-in", .orange)
                } else {
                    return ("❌ Unresponsive", .red)
                }
            } else {
                return ("❓ No Check-in", .gray)
            }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        // Data management
        case refreshDependents
        case setSortMode(State.SortMode)
        
        // Contact interactions
        case selectContact(Contact)
        case pingContact(Contact)
        case removeContact(Contact)
        case toggleDependentStatus(Contact)
        case showRemoveConfirmation(Contact)
        
        // UI presentations
        case contactDetails(PresentationAction<ContactDetailsSheetFeature.Action>)
        case confirmationAlert(PresentationAction<DependentsAlert>)
        
        // Network responses
        case pingResponse(Result<Void, Error>)
        case removeResponse(Result<Void, Error>)
        case dependentStatusResponse(Result<Contact, Error>)
        case refreshResponse(Result<[Contact], Error>)
    }

    @Dependency(\.contactsClient) var contactsClient
    @Dependency(\.hapticClient) var haptics

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce<State, Action> { state, action in
            switch action {
            case .binding:
                return .none

            // Data management
            case .refreshDependents:
                guard state.currentUser != nil else { return .none }
                state.isLoading = true
                state.errorMessage = nil

                let dependentCount = state.dependents.count

                return .run { send in
                    let result = await Result {
                        try await contactsClient.getContacts()
                    }
                    await send(.refreshResponse(result))
                }

            case let .setSortMode(mode):
                state.sortMode = mode
                return .run { _ in
                    await haptics.impact(.light)
                }

            // Contact interactions
            case let .selectContact(contact):
                state.contactDetails = ContactDetailsSheetFeature.State(contact: contact)
                return .run { _ in
                    await analytics.track(.featureUsed(feature: "dependent_details_view", context: [
                        "contact_id": contact.id.uuidString,
                        "has_manual_alert": "\(contact.manualAlertActive)",
                        "has_incoming_ping": "\(contact.hasIncomingPing)",
                        "has_outgoing_ping": "\(contact.hasOutgoingPing)"
                    ]))
                }

            case let .pingContact(contact):
                state.confirmationAlert = AlertState {
                    TextState("Ping Dependent")
                } actions: {
                    ButtonState(action: .confirmPing(contact)) {
                        TextState("Send Ping")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("Send a check-in ping to \(contact.name)?")
                }
                return .none

            case let .removeContact(contact):
                state.confirmationAlert = AlertState {
                    TextState("Remove Dependent")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmRemove(contact)) {
                        TextState("Remove")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("Are you sure you want to remove \(contact.name) as a dependent? This will not delete the contact entirely.")
                }
                return .none

            case let .toggleDependentStatus(contact):
                state.isLoading = true
                state.errorMessage = nil

                return .run { send in
                    await analytics.track(.contactDependentStatusChanged(contactId: contact.id, isDependent: !contact.isDependent))
                    await send(.dependentStatusResponse(Result {
                        try await contactsClient.updateContact(contact.id, !contact.isDependent)
                    }))
                }

            case let .showRemoveConfirmation(contact):
                return .send(.removeContact(contact))

            // UI presentations
            case .contactDetails:
                return .none

            case .confirmationAlert(.presented(.confirmPing(let contact))):
                state.isLoading = true
                state.errorMessage = nil

                return .run { send in
                    await haptics.notification(.warning)
                    await analytics.track(.featureUsed(feature: "ping_dependent", context: [
                        "contact_id": contact.id.uuidString,
                        "contact_name": contact.name
                    ]))
                    await send(.pingResponse(Result {
                        // Update ping status for the contact
                        _ = try await contactsClient.updatePingStatus(contact.id, true, false)
                        // In production, this would also send a notification to the dependent
                        try await Task.sleep(for: .milliseconds(1000))
                    }))
                }

            case .confirmationAlert(.presented(.confirmRemove(let contact))):
                state.isLoading = true
                state.errorMessage = nil

                return .run { send in
                    await haptics.notification(.success)
                    await analytics.track(.featureUsed(feature: "remove_dependent_status", context: [
                        "contact_id": contact.id.uuidString,
                        "contact_name": contact.name
                    ]))
                    await send(.dependentStatusResponse(Result {
                        // Remove dependent status rather than deleting the contact entirely
                        try await contactsClient.updateContact(contact.id, false)
                    }))
                }

            case .confirmationAlert:
                return .none

            // Network responses
            case .pingResponse(.success):
                state.isLoading = false
                return .run { _ in
                    await haptics.notification(.success)
                }

            case let .pingResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none

            case .removeResponse(.success):
                state.isLoading = false
                return .run { _ in
                    await haptics.notification(.success)
                }

            case let .removeResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none

            case let .dependentStatusResponse(.success(updatedContact)):
                state.isLoading = false
                state.$allContacts.withLock { contacts in
                    if let index = contacts.firstIndex(where: { $0.id == updatedContact.id }) {
                        contacts[index] = updatedContact
                    }
                }
                return .run { _ in
                    await haptics.notification(.success)
                }

            case let .dependentStatusResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none

            case let .refreshResponse(.success(contacts)):
                state.isLoading = false
                state.errorMessage = nil
                state.$allContacts.withLock { $0 = contacts }
                return .none

            case let .refreshResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
            }
        }
        .ifLet(\.$contactDetails, action: \.contactDetails) {
            ContactDetailsSheetFeature()
        }
        .ifLet(\.$confirmationAlert, action: \.confirmationAlert)
    }
}


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
                store.send(.refreshDependents, animation: .default)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        ForEach(DependentsFeature.State.SortMode.allCases, id: \.self) { sortMode in
                            Button(action: {
                                store.send(.setSortMode(sortMode), animation: .default)
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

    private func dependentCardView(for contact: Contact) -> some View {
        cardContent(for: contact)
            .padding() // This padding is inside the card
            .background(store.state.cardBackgroundColor(for: contact))
            .cornerRadius(12)
            .modifier(CardFlashingAnimation(isActive: contact.manualAlertActive))
            .onTapGesture {
                store.send(.selectContact(contact), animation: .default)
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

            let statusText = store.state.statusText(for: contact)
            if !statusText.isEmpty {
                Text(statusText)
                    .font(.footnote)
                    .foregroundColor(store.state.statusColor(for: contact))
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
