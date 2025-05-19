//
// ViewSamples.swift
// Sample implementations of SwiftUI views using TCA for the LifeSignal iOS application
//

import SwiftUI
import ComposableArchitecture

// MARK: - Sample Feature View

/// A sample view that demonstrates the TCA pattern
struct SampleFeatureView: View {
    /// The store for the feature
    @Bindable var store: StoreOf<SampleFeature>
    
    /// The body of the view
    var body: some View {
        VStack(spacing: 20) {
            // Name input
            TextField("Name", text: $store.name.sending(\.nameChanged))
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            
            // Count display
            Text("Count: \(store.count)")
                .font(.title)
            
            // Buttons
            HStack(spacing: 20) {
                Button("-") {
                    store.send(.decrementButtonTapped)
                }
                .buttonStyle(.bordered)
                
                Button("+") {
                    store.send(.incrementButtonTapped)
                }
                .buttonStyle(.bordered)
            }
            
            // Reset button
            Button {
                store.send(.resetButtonTapped)
            } label: {
                if store.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Reset")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isLoading)
            
            // Detail button
            Button("Show Detail") {
                store.send(.detailButtonTapped)
            }
            .buttonStyle(.bordered)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Sample Feature")
        .alert(
            title: { _ in Text("Error") },
            unwrapping: $store.error,
            actions: { _ in
                Button("OK") {
                    store.send(.dismissError)
                }
            },
            message: { error in
                Text(error)
            }
        )
        .sheet(
            item: $store.scope(
                state: \.destination?.detail,
                action: \.destination.detail
            )
        ) { store in
            NavigationStack {
                DetailFeatureView(store: store)
                    .navigationTitle("Detail")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                store.send(.cancelButtonTapped)
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Detail Feature View

/// A detail view that demonstrates child features
struct DetailFeatureView: View {
    /// The store for the feature
    @Bindable var store: StoreOf<DetailFeature>
    
    /// The body of the view
    var body: some View {
        VStack(spacing: 20) {
            // Name display
            Text("Name: \(store.name)")
                .font(.headline)
            
            // Count display
            Text("Count: \(store.count)")
                .font(.title)
            
            // Buttons (only shown in edit mode)
            if store.isEditing {
                HStack(spacing: 20) {
                    Button("-") {
                        store.send(.decrementButtonTapped)
                    }
                    .buttonStyle(.bordered)
                    
                    Button("+") {
                        store.send(.incrementButtonTapped)
                    }
                    .buttonStyle(.bordered)
                }
                
                // Save button
                Button("Save") {
                    store.send(.saveButtonTapped)
                }
                .buttonStyle(.borderedProminent)
            } else {
                // Edit button
                Button("Edit") {
                    store.send(.editButtonTapped)
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Custom Components

/// A custom button style
struct PrimaryButtonStyle: ButtonStyle {
    /// Whether the button is disabled
    var isDisabled: Bool = false
    
    /// The color of the button
    var color: Color = .blue
    
    /// The body of the button style
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(maxWidth: .infinity)
            .background(isDisabled ? Color.gray : color)
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// A custom text field style
struct RoundedTextFieldStyle: TextFieldStyle {
    /// The body of the text field style
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}

/// A custom card view
struct CardView<Content: View>: View {
    /// The content of the card
    let content: Content
    
    /// Whether the card has a shadow
    var hasShadow: Bool = true
    
    /// The corner radius of the card
    var cornerRadius: CGFloat = 12
    
    /// The padding of the card
    var padding: CGFloat = 16
    
    /// Initialize with content
    init(hasShadow: Bool = true, cornerRadius: CGFloat = 12, padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.hasShadow = hasShadow
        self.cornerRadius = cornerRadius
        self.padding = padding
    }
    
    /// The body of the view
    var body: some View {
        content
            .padding(padding)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(cornerRadius)
            .if(hasShadow) { view in
                view.shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
    }
}

/// A conditional view modifier
extension View {
    /// Apply a modifier conditionally
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Preview

/// A preview for the sample feature view
struct SampleFeatureView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SampleFeatureView(
                store: Store(
                    initialState: SampleFeature.State(
                        name: "John Doe",
                        count: 42
                    )
                ) {
                    SampleFeature()
                }
            )
        }
    }
}

/// A preview for the detail feature view
struct DetailFeatureView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DetailFeatureView(
                store: Store(
                    initialState: DetailFeature.State(
                        name: "John Doe",
                        count: 42,
                        isEditing: true
                    )
                ) {
                    DetailFeature()
                }
            )
        }
    }
}
