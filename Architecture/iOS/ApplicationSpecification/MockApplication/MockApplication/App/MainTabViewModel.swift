import Foundation
import SwiftUI
import Combine

/// View model for the main tab view
/// This class is designed to mirror the structure of TabFeature.State in the TCA implementation
class MainTabViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// The selected tab
    @Published var selectedTab: Int = 0
    
    /// Whether the alert icon is active
    @Published var isAlertActive: Bool = false
    
    /// The number of pending pings
    @Published var pendingPingsCount: Int = 0
    
    /// The number of non-responsive dependents
    @Published var nonResponsiveDependentsCount: Int = 0
    
    // MARK: - Initialization
    
    init() {
        // In a real app, we would load tab state from a service
    }
    
    // MARK: - Methods
    
    /// Set the selected tab
    /// - Parameter tab: The tab to select
    func setSelectedTab(_ tab: Int) {
        selectedTab = tab
    }
    
    /// Update alert status
    /// - Parameter isActive: Whether the alert is active
    func updateAlertStatus(_ isActive: Bool) {
        isAlertActive = isActive
    }
    
    /// Update pending pings count
    /// - Parameter count: The number of pending pings
    func updatePendingPingsCount(_ count: Int) {
        pendingPingsCount = count
    }
    
    /// Update non-responsive dependents count
    /// - Parameter count: The number of non-responsive dependents
    func updateNonResponsiveDependentsCount(_ count: Int) {
        nonResponsiveDependentsCount = count
    }
}
