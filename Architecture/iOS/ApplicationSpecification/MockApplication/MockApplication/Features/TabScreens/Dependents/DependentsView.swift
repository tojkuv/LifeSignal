import SwiftUI
import Foundation
import UIKit
import AVFoundation
import PhotosUI

/// Sort mode for the dependents list
enum SortMode: String, CaseIterable, Identifiable {
    case timeLeft = "Time Left"
    case name = "Name"
    case dateAdded = "Date Added"

    var id: String { self.rawValue }
}

struct DependentsView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @StateObject private var viewModel = DependentsViewModel()

    // State variables
    @State private var refreshID = UUID()
    @State private var showCheckInConfirmation = false
    @State private var sortMode: SortMode = .timeLeft

    // Debug state to track dependent count
    @State private var dependentCount: Int = 0

    // MARK: - Lifecycle

    init() {
        // Create a view model
        let viewModel = DependentsViewModel()
        // Set initial sort mode
        viewModel.selectedSortMode = .countdown
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    /// Computed property to get sorted dependents from the view model
    private var sortedDependents: [Contact] {
        // This will be recalculated when the view model's refreshID changes
        return viewModel.getSortedDependents()
    }

    /// Convert between the view's SortMode and the view model's SortMode
    private func convertSortMode(_ mode: SortMode) -> DependentsViewModel.SortMode {
        switch mode {
        case .timeLeft:
            return .countdown
        case .name:
            return .alphabetical
        case .dateAdded:
            return .recentlyAdded
        }
    }

    var body: some View {
        // Simplified scrollable view with direct LazyVStack
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 12) {
                if userViewModel.dependents.isEmpty {
                    Text("No dependents yet")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else {
                    ForEach(sortedDependents) { dependent in
                        DependentCardView(contact: dependent, refreshID: viewModel.refreshID)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            // Add observer for refresh notifications
            NotificationCenter.default.addObserver(forName: NSNotification.Name("RefreshDependentsView"), object: nil, queue: .main) { _ in
                refreshID = UUID()
            }

            // Set the user view model to ensure data is loaded
            viewModel.setUserViewModel(userViewModel)

            // Force refresh when view appears to ensure sort is applied
            refreshID = UUID()
            viewModel.forceRefresh()
            print("DependentsView appeared with sort mode: \(sortMode.rawValue)")
            print("DependentsView has \(userViewModel.dependents.count) dependents")

            // Debug: print all dependents
            for (index, dependent) in userViewModel.dependents.enumerated() {
                print("Dependent \(index+1): \(dependent.name) (isDependent: \(dependent.isDependent))")
            }
        }
        .onChange(of: userViewModel.dependents) { _, _ in
            // Refresh when dependents change
            viewModel.forceRefresh()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    ForEach(SortMode.allCases) { mode in
                        Button(action: {
                            HapticFeedback.selectionFeedback()
                            sortMode = mode
                            // Update view model's sort mode
                            viewModel.selectedSortMode = convertSortMode(mode)
                            // Force refresh when sort mode changes
                            refreshID = UUID()
                            viewModel.forceRefresh()
                            print("Sort mode changed to: \(mode.rawValue)")
                        }) {
                            Label(mode.rawValue, systemImage: sortMode == mode ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(sortMode.rawValue)
                            .font(.caption)
                    }
                }
                .accessibilityLabel("Sort Dependents")
                .hapticFeedback(style: .light)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: NotificationCenterView()) {
                    Image(systemName: "square.fill.text.grid.1x2")
                }
                .hapticFeedback(style: .light)
            }
        }


        .alert(isPresented: $showCheckInConfirmation) {
            Alert(
                title: Text("Confirm Check-in"),
                message: Text("Are you sure you want to check in now? This will reset your timer."),
                primaryButton: .default(Text("Check In")) {
                    userViewModel.checkIn()
                },
                secondaryButton: .cancel()
            )
        }

        .onAppear {
            // Sync view model with user view model
            viewModel.setUserViewModel(userViewModel)
        }
    }
}