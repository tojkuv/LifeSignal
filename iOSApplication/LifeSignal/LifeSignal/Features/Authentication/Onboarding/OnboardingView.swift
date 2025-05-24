import SwiftUI
import ComposableArchitecture
import Perception

struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingFeature>
    
    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                VStack {
                    // Progress indicator - fixed position
                    progressIndicator
                    
                    // Content based on current step
                    Group {
                        switch store.currentStep {
                        case .welcome:
                            welcomeView
                        case .permissions:
                            permissionsView
                        case .profile:
                            // Profile step is handled in AuthenticationView
                            EmptyView()
                        case .complete:
                            completionView
                        }
                    }
                }
                .padding()
                .navigationTitle("Welcome to LifeSignal")
                .navigationBarTitleDisplayMode(.inline)
                .background(Color(UIColor.systemGroupedBackground))
            }
        }
    }
    
    private var progressIndicator: some View {
        ProgressView(value: store.progress)
            .progressViewStyle(LinearProgressViewStyle())
            .padding(.vertical)
    }
    
    private var welcomeView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "shield.checkered")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            Text("Welcome to LifeSignal")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Stay connected with your loved ones and ensure their safety with real-time check-ins and emergency alerts.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Spacer()
            
            Button(action: {
                store.send(.nextStep)
            }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
    }
    
    private var permissionsView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "bell.badge")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            Text("Enable Notifications")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("We'll send you important alerts about check-ins and emergency situations.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: {
                    // Request notification permissions
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                        DispatchQueue.main.async {
                            store.send(.nextStep)
                        }
                    }
                }) {
                    Text("Enable Notifications")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    store.send(.nextStep)
                }) {
                    Text("Maybe Later")
                        .font(.body)
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.green)
            
            Text("You're All Set!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Welcome to LifeSignal. Let's keep you and your loved ones safe.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Spacer()
            
            Button(action: {
                store.send(.completeOnboarding)
            }) {
                Text("Start Using LifeSignal")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
    }
}

// MARK: - Previews

#Preview("Onboarding View") {
    OnboardingView(
        store: Store(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }
    )
}