import SwiftUI
import ComposableArchitecture

// MARK: - Contact Card View

struct ContactCardView: View {
    let contact: Contact
    let style: CardStyle
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        cardContent
            .padding()
            .background(cardBackground)
            .cornerRadius(12)
            .modifier(CardFlashingAnimation(isActive: shouldShowFlashingAnimation))
            .onTapGesture(perform: onTap)
    }
}

// MARK: - Card Style

extension ContactCardView {
    
    enum CardStyle {
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
                    Text(String(contact.name.prefix(1)))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                )

            if shouldShowPingBadge {
                pingBadge
            }
        }
    }
    
    @ViewBuilder
    var nameAndStatusView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(contact.name)
                    .font(.body)
                    .foregroundColor(.primary)
            }

            if !statusText.isEmpty {
                Text(statusText)
                    .font(.footnote)
                    .foregroundColor(statusTextColor)
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }
    
    @ViewBuilder
    var trailingContentView: some View {
        switch style {
        case .responder:
            EmptyView()
        case .dependent:
            EmptyView() // Dependents don't have trailing content
        }
    }
    
    @ViewBuilder
    var pingBadge: some View {
        if case .dependent = style, contact.hasOutgoingPing {
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
    
    var statusTextColor: Color {
        if hasStatusColor {
            // Status text: use the actual status color (not opacity)
            switch style {
            case .responder:
                return .blue
            case .dependent:
                if contact.hasManualAlertActive {
                    return .red
                } else if contact.hasNotResponsiveAlert {
                    return colorScheme == .light ? .orange : .yellow
                } else if contact.hasOutgoingPing {
                    return .blue
                } else {
                    return .secondary
                }
            }
        } else {
            // Default text: secondary color
            return .secondary
        }
    }
    
    @ViewBuilder
    var cardBackground: some View {
        if hasStatusColor {
            // Status cards: use systemGroupedBackground base (same as sheet) + status color overlay
            Color(UIColor.systemGroupedBackground)
                .overlay(statusOverlayColor)
        } else {
            // Default cards: secondary system background
            Color(UIColor.secondarySystemGroupedBackground)
        }
    }
    
    var hasStatusColor: Bool {
        switch style {
        case .responder:
            return contact.hasIncomingPing || contact.hasOutgoingPing
        case .dependent:
            return contact.hasManualAlertActive || contact.hasNotResponsiveAlert || contact.hasOutgoingPing
        }
    }
    
    @ViewBuilder
    var statusOverlayColor: some View {
        switch style {
        case .responder:
            if contact.hasIncomingPing || contact.hasOutgoingPing {
                Color.blue.opacity(0.1)
            }
        case .dependent:
            if contact.hasManualAlertActive {
                Color.red.opacity(0.1)
            } else if contact.hasNotResponsiveAlert {
                (colorScheme == .light ? Color.orange : Color.yellow).opacity(0.1)
            } else if contact.hasOutgoingPing {
                Color.blue.opacity(0.1)
            }
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
            contact: Contact.mockData[0],
            style: .responder(statusText: "Pinged you 5 minutes ago"),
            onTap: {}
        )
        
        // Dependent Card with Alert (Red background)
        ContactCardView(
            contact: Contact.mockData[1],
            style: .dependent(
                statusText: "Sent out an Alert",
                statusColor: .red
            ),
            onTap: {}
        )
        
        // Dependent Card Non-responsive (Orange background)
        ContactCardView(
            contact: Contact.mockData[2],
            style: .dependent(
                statusText: "Non-responsive",
                statusColor: .orange
            ),
            onTap: {}
        )
        
        // Dependent Card with Outgoing Ping (Blue background)
        ContactCardView(
            contact: Contact.mockData[3],
            style: .dependent(
                statusText: "You Pinged Them",
                statusColor: .blue
            ),
            onTap: {}
        )
    }
    .padding()
}