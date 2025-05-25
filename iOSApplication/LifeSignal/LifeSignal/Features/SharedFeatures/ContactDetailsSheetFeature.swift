import SwiftUI
import Foundation
import ComposableArchitecture

@Reducer
struct ContactDetailsSheetFeature {
    @ObservableState
    struct State: Equatable {
        var contact: Contact
        var isNotResponsive: Bool = false
        var shouldDismiss: Bool = false
        
        init(contact: Contact) {
            self.contact = contact
        }
    }

    enum Action {
        // Contact interactions
        case pingContact
        case removeContact
        
        // Status updates
        case updateResponderStatus(Bool)
        case updateDependentStatus(Bool)
        case contactUpdated(Contact)
        
        // UI navigation
        case dismiss
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .pingContact:
                return .none
                
            case .dismiss:
                state.shouldDismiss = true
                return .none
                
            case .updateResponderStatus(let isResponder):
                state.contact.isResponder = isResponder
                return .none
                
            case .updateDependentStatus(let isDependent):
                state.contact.isDependent = isDependent
                return .none
                
            case .removeContact:
                return .none
                
            case .contactUpdated(let contact):
                state.contact = contact
                return .none
            }
        }
    }
}

// Simple View for MVP
struct ContactDetailsSheetView: View {
    @Bindable var store: StoreOf<ContactDetailsSheetFeature>
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(store.contact.name)
                    .font(.title)
                
                Text(store.contact.phoneNumber)
                    .font(.subheadline)
                
                if !store.contact.note.isEmpty {
                    Text(store.contact.note)
                        .padding()
                }
                
                Button("Ping Contact") {
                    store.send(.pingContact, animation: .default)
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Contact Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        store.send(.dismiss, animation: .default)
                    }
                }
            }
        }
    }
    
    func formatInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        if hours < 24 {
            return "\(hours) hours"
        } else {
            let days = hours / 24
            return "\(days) days"
        }
    }
}