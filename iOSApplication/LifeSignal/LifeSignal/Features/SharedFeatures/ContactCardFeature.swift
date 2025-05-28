import SwiftUI
import Foundation
import ComposableArchitecture
import Perception

// MARK: - Contact Card Feature

@Reducer
struct ContactCardFeature {
    @ObservableState
    struct State: Equatable, Identifiable {
        let contact: Contact
        let style: CardStyle
        var id: String { contact.id.uuidString }
        
        init(contact: Contact, style: CardStyle) {
            self.contact = contact
            self.style = style
        }
        
        enum CardStyle: Equatable {
            case responder(statusText: String)
            case dependent(statusText: String, statusColor: Color)
            
            var hasFlashingAnimation: Bool {
                switch self {
                case .responder:
                    return false
                case .dependent:
                    return true
                }
            }
        }
        
        // MARK: - Computed Properties
        
        var shouldShowPingBadge: Bool {
            switch style {
            case .responder:
                return false
            case .dependent:
                return contact.hasOutgoingPing
            }
        }
        
        var shouldShowFlashingAnimation: Bool {
            switch style {
            case .responder:
                return false
            case .dependent:
                return contact.hasManualAlertActive
            }
        }
        
        var statusText: String {
            switch style {
            case .responder(let text):
                return text
            case .dependent(let text, _):
                return text
            }
        }
        
        var hasStatusColor: Bool {
            switch style {
            case .responder:
                return contact.hasIncomingPing || contact.hasOutgoingPing
            case .dependent(_, let statusColor):
                // Use statusColor parameter to determine if background should be shown
                return statusColor != .secondary
            }
        }
    }
    
    enum Action {
        case tapped
        case refreshTimeDisplays
    }
    
    @Dependency(\.timeFormattingClient) var timeFormattingClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .tapped:
                return .none
                
            case .refreshTimeDisplays:
                // This could be used to refresh time-based displays if needed
                return .none
            }
        }
    }
}

// MARK: - Contact Card View

struct ContactCardView: View {
    @Bindable var store: StoreOf<ContactCardFeature>
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        WithPerceptionTracking {
            cardContent
                .padding()
                .background(cardBackground)
                .cornerRadius(12)
                .modifier(CardFlashingAnimation(isActive: store.shouldShowFlashingAnimation))
                .onTapGesture {
                    store.send(.tapped)
                    onTap()
                }
        }
    }
}

// MARK: - Content Views

private extension ContactCardView {
    
    @ViewBuilder
    var cardContent: some View {
        HStack(spacing: 12) {
            avatarView
            nameAndStatusView
            Spacer()
            trailingContentView
        }
    }
    
    @ViewBuilder
    var avatarView: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(Color(UIColor.systemGroupedBackground))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(store.contact.name.prefix(1)))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                )

            if store.shouldShowPingBadge {
                pingBadge
            }
        }
    }
    
    @ViewBuilder
    var nameAndStatusView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(store.contact.name)
                    .font(.body)
                    .foregroundColor(.primary)
            }

            if !store.statusText.isEmpty {
                Text(store.statusText)
                    .font(.footnote)
                    .foregroundColor(statusTextColor)
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }
    
    @ViewBuilder
    var trailingContentView: some View {
        switch store.style {
        case .responder:
            EmptyView()
        case .dependent:
            EmptyView() // Dependents don't have trailing content
        }
    }
    
    @ViewBuilder
    var pingBadge: some View {
        if case .dependent = store.style, store.contact.hasOutgoingPing {
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
    }
}

// MARK: - Computed Properties

private extension ContactCardView {
    
    var statusTextColor: Color {
        if store.hasStatusColor {
            // Status text: use the actual status color (not opacity)
            switch store.style {
            case .responder:
                return .blue
            case .dependent(_, let statusColor):
                // Use the statusColor passed from the feature
                return statusColor
            }
        } else {
            // Default text: secondary color
            return .secondary
        }
    }
    
    @ViewBuilder
    var cardBackground: some View {
        if store.hasStatusColor {
            // Status cards: use systemGroupedBackground base (same as sheet) + status color overlay
            Color(UIColor.systemGroupedBackground)
                .overlay(statusOverlayColor)
        } else {
            // Default cards: secondary system background
            Color(UIColor.secondarySystemGroupedBackground)
        }
    }
    
    @ViewBuilder
    var statusOverlayColor: some View {
        switch store.style {
        case .responder:
            if store.contact.hasIncomingPing || store.contact.hasOutgoingPing {
                Color.blue.opacity(0.1)
            }
        case .dependent(_, let statusColor):
            // Use the statusColor passed from the feature for background
            if statusColor == .red {
                Color.red.opacity(0.1)
            } else if statusColor == .orange {
                (colorScheme == .light ? Color.orange : Color.yellow).opacity(0.1)
            }
            // Background color determined by statusColor parameter
        }
    }
}

// MARK: - Card Flashing Animation

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

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // Responder Card with Ping (Blue background)
        ContactCardView(
            store: Store(
                initialState: ContactCardFeature.State(
                    contact: Contact.mockData[0],
                    style: .responder(statusText: "Pinged you")
                )
            ) {
                ContactCardFeature()
            },
            onTap: {}
        )
        
        // Dependent Card with Alert (Red background)
        ContactCardView(
            store: Store(
                initialState: ContactCardFeature.State(
                    contact: Contact.mockData[1],
                    style: .dependent(
                        statusText: "Sent out an alert",
                        statusColor: .red
                    )
                )
            ) {
                ContactCardFeature()
            },
            onTap: {}
        )
        
        // Dependent Card Non-responsive (Orange background)
        ContactCardView(
            store: Store(
                initialState: ContactCardFeature.State(
                    contact: Contact.mockData[2],
                    style: .dependent(
                        statusText: "Non-responsive",
                        statusColor: .orange
                    )
                )
            ) {
                ContactCardFeature()
            },
            onTap: {}
        )
        
        // Dependent Card with Outgoing Ping (Blue background)
        ContactCardView(
            store: Store(
                initialState: ContactCardFeature.State(
                    contact: Contact.mockData[3],
                    style: .dependent(
                        statusText: "You pinged them",
                        statusColor: .blue
                    )
                )
            ) {
                ContactCardFeature()
            },
            onTap: {}
        )
    }
    .padding()
}