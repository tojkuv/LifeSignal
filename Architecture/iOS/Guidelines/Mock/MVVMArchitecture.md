# MVVM Architecture Guidelines for Mock Application

**Navigation:** [Back to iOS Guidelines](../README.md) | [Production Guidelines](../Production/README.md)

---

## Overview

This document defines how to **build new features from scratch** in the mock application using MVVM. These guidelines create a consistent approach that ensures isolation, simplicity, and maintainability. These rules are non-negotiable and must be followed for all new feature development.

The mock application serves as a sandbox for UI development and iteration, allowing designers and developers to iterate on UI designs without affecting the production codebase.

> **Important:** The mock application is the source of truth for UI and UX design in the LifeSignal project. All UI and UX implemented in the production application must be derived from the mock application. This means that UI components, layouts, interactions, and visual design must be fully implemented and validated in the mock application before being implemented in the production application.

---

## 🔒 Global Constraints

- ❌ **Do not use shared state across view models**
- ❌ **Do not use clients, services, or injected dependencies**
- ❌ **Do not introduce new shared models** (e.g., `UserViewModel`)
- ❌ **Do not access any real data or networking layers**
- ✅ **Use mock data only** inside each feature's view model
- ✅ **Each feature is self-contained** — no cross-feature communication

---

## 🧱 Feature Structure

Each feature must include:
- A `ViewModel` conforming to `ObservableObject`
- A `View` using `@StateObject` for the view model
- Mock data for simulating logic/state
- Private computed subviews for internal layout
- No custom view initializers (except for SwiftUI's default `.init()`)

---

## 📌 View Rules

1. Each view owns its own view model:
   ```swift
   @StateObject private var viewModel = FeatureViewModel()
   ```

2. Views must **not**:
   - Accept view models via initializers
   - Pass view models to other views
   - Create or hold additional state
   - Initialize or configure logic — use view model methods only

3. Views must **only**:
   - Display data from the view model
   - Call view model methods without arguments
   - Use internal private computed subviews (not separate structs unless reused)

---

## 📌 ViewModel Rules

1. View models must:
   - Hold **all feature-specific state**
   - Contain **all business logic**
   - Be initialized with **no arguments**
   - Store any needed closures (e.g. for dismiss callbacks)

2. Use mock data to simulate:
   - User interactions
   - Network responses
   - Loading and error states

3. Example:
   ```swift
   class FeatureViewModel: ObservableObject {
       @Published var isLoading = false
       @Published var items: [String] = ["Mock Item 1", "Mock Item 2"]

       func loadMore() {
           isLoading = true
           DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
               self.items.append("Mock Item \(self.items.count + 1)")
               self.isLoading = false
           }
       }
   }
   ```

---

## 🖼️ Preview Guidelines

All views in the mock application **must** include previews that demonstrate:
- Default state
- Light mode appearance
- Dark mode appearance

Example of proper preview implementation:

```swift
struct FeatureView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode preview
            FeatureView()
                .previewDisplayName("Light Mode")

            // Dark mode preview
            FeatureView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
```

For views with multiple states, include previews for each significant state:

```swift
struct FeatureView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Default state in light mode
            FeatureView()
                .previewDisplayName("Default - Light")

            // Default state in dark mode
            FeatureView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Default - Dark")

            // Loading state preview
            let loadingView = FeatureView()
            // Access the view model to set loading state
            loadingView.viewModel.isLoading = true
            return loadingView
                .previewDisplayName("Loading State")
        }
    }
}
```

---

## 🧪 Testing Guidelines

**Testing should NOT be done in the mock application.**

- MVVM is not ideal for testing complex interactions and state flows
- All testing efforts should be directed to the TCA production application
- The mock application is for UI development and iteration only
- If you need to verify functionality, use previews and manual testing in the simulator

---

## 💡 View Example

```swift
struct FeatureView: View {
    @StateObject private var viewModel = FeatureViewModel()

    var body: some View {
        VStack {
            List(viewModel.items, id: \.self) { item in
                Text(item)
            }

            if viewModel.isLoading {
                ProgressView()
            }

            Button("Load More") {
                viewModel.loadMore()
            }
        }
    }

    private var emptyStateView: some View {
        VStack {
            Text("No items yet")
        }
    }
}
```

---

## 🔁 Design Philosophy

- **One source of truth per feature**
- **Strict state ownership**
- **No magic — all behavior must be obvious**
- **Keep logic isolated and composable**

---

## 🚫 Don't

- Don't use `@EnvironmentObject`, `@ObservedObject`, or global state
- Don't call services, APIs, or clients
- Don't reference or depend on other view models
- Don't mutate state from outside the view model
- Don't create new shared types — features must be modular

---

## ✅ Complete Feature Example

Here's a complete example of a feature implementation following these guidelines:

```swift
// MARK: - View Model
class ContactDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var contact: Contact
    @Published var isLoading = false
    @Published var showDeleteConfirmation = false

    // MARK: - Initialization
    init() {
        // Mock data
        self.contact = Contact(
            id: UUID().uuidString,
            name: "Jane Smith",
            phone: "+1 (555) 123-4567",
            roles: [.dependent, .responder],
            status: .responsive
        )
    }

    // MARK: - Methods
    func toggleRole(_ role: ContactRole) {
        // Simulate toggling a role with a brief loading state
        isLoading = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            // Toggle the role
            if self.contact.roles.contains(role) {
                self.contact.roles.removeAll { $0 == role }
            } else {
                self.contact.roles.append(role)
            }

            self.isLoading = false
        }
    }

    func deleteContact() {
        // Show confirmation dialog
        showDeleteConfirmation = true
    }

    func confirmDelete() {
        // In a real app, this would delete the contact
        // For mock, we just dismiss the confirmation
        showDeleteConfirmation = false
    }
}

// MARK: - View
struct ContactDetailView: View {
    @StateObject private var viewModel = ContactDetailViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                contactHeader

                Divider()

                rolesSection

                Divider()

                deleteButton
            }
            .padding()
        }
        .navigationTitle("Contact Details")
        .alert("Delete Contact", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.confirmDelete()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this contact? This action cannot be undone.")
        }
    }

    // MARK: - Private Subviews
    private var contactHeader: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 60)
                .overlay(
                    Text(String(viewModel.contact.name.prefix(1)))
                        .font(.title)
                        .foregroundColor(.primary)
                )

            VStack(alignment: .leading) {
                Text(viewModel.contact.name)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(viewModel.contact.phone)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private var rolesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Roles")
                .font(.headline)

            VStack(spacing: 8) {
                roleToggle(.dependent, "Dependent")
                roleToggle(.responder, "Responder")
            }
        }
    }

    private func roleToggle(_ role: ContactRole, _ title: String) -> some View {
        Toggle(isOn: Binding(
            get: { viewModel.contact.roles.contains(role) },
            set: { _ in viewModel.toggleRole(role) }
        )) {
            Text(title)
        }
        .disabled(viewModel.isLoading)
    }

    private var deleteButton: some View {
        Button {
            viewModel.deleteContact()
        } label: {
            Text("Delete Contact")
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(10)
        }
    }
}

// MARK: - Previews
struct ContactDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                ContactDetailView()
            }
            .previewDisplayName("Light Mode")

            NavigationView {
                ContactDetailView()
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}

// MARK: - Supporting Types
struct Contact {
    var id: String
    var name: String
    var phone: String
    var roles: [ContactRole]
    var status: ContactStatus
}

enum ContactRole {
    case dependent
    case responder
}

enum ContactStatus {
    case responsive
    case nonResponsive
    case alertActive
}
```

---

## 🎨 UI/UX Source of Truth

The mock application serves as the source of truth for UI and UX in the LifeSignal project. This means:

1. **Complete Implementation** - All UI components and interactions must be fully implemented in the mock application
2. **Visual Accuracy** - The mock application must accurately represent the final visual design
3. **Interaction Patterns** - All user interaction patterns must be implemented and validated
4. **Edge Cases** - All UI edge cases (empty states, error states, loading states) must be handled
5. **Accessibility** - All accessibility features must be implemented and tested
6. **Responsive Design** - UI must adapt to different screen sizes and orientations
7. **Dark Mode** - Both light and dark mode must be fully implemented

The production application will reference the mock application's UI/UX implementation when implementing features using TCA. Any UI/UX changes should be made in the mock application first, then propagated to the production application.

---

## 📋 Implementation Checklist

Use this checklist to verify your implementation follows the guidelines:

- [ ] View model is initialized with no arguments
- [ ] View uses `@StateObject` to own its view model
- [ ] All state is contained in the view model
- [ ] All logic is contained in the view model
- [ ] No dependencies on external services or clients
- [ ] No shared state across view models
- [ ] Mock data is used for all functionality
- [ ] UI is composed of private computed subviews
- [ ] Previews include both light and dark mode
- [ ] No custom view initializers
- [ ] No state passed between views
- [ ] All UI components follow the design system
- [ ] All interaction patterns are implemented
- [ ] All UI edge cases are handled
- [ ] UI adapts to different screen sizes

Following these principles ensures that every feature is isolated, maintainable, and aligned with our application architecture, while providing a complete UI/UX reference for the production application.
