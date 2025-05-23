import SwiftUI
import ComposableArchitecture

struct MainTabsView: View {
    @Bindable var store: StoreOf<MainTabsFeature>

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
                NavigationStack {
                    HomeView(store: store.scope(
                        state: \.home,
                        action: \.home
                    ))
                    .navigationTitle("Home")
                    .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(MainTabsFeature.State.Tab.home)
                
                NavigationStack {
                    RespondersView(store: store.scope(
                        state: \.responders,
                        action: \.responders
                    ))
                    .navigationTitle("Responders")
                    .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Label("Responders", systemImage: "person.2.fill")
                }
                .badge(store.pendingPingsCount > 0 ? "\(store.pendingPingsCount)" : nil)
                .tag(MainTabsFeature.State.Tab.responders)
                
                NavigationStack {
                    CheckInView(store: store.scope(
                        state: \.checkIn,
                        action: \.checkIn
                    ))
                    .navigationTitle("Check-In")
                    .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Label("Check-In", systemImage: "iphone")
                }
                .tag(MainTabsFeature.State.Tab.checkIn)
                
                NavigationStack {
                    DependentsView(store: store.scope(
                        state: \.dependents,
                        action: \.dependents
                    ))
                    .navigationTitle("Dependents")
                    .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Label("Dependents", systemImage: "person.3.fill")
                }
                .badge(store.nonResponsiveDependentsCount > 0 ? "\(store.nonResponsiveDependentsCount)" : nil)
                .tag(MainTabsFeature.State.Tab.dependents)
                
                NavigationStack {
                    ProfileView(store: store.scope(
                        state: \.profile,
                        action: \.profile
                    ))
                    .navigationTitle("Profile")
                    .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.dashed")
                }
                .tag(MainTabsFeature.State.Tab.profile)
            }
        }
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
            
            store.send(.onAppear)
        }
        .accentColor(.blue)
    }
}