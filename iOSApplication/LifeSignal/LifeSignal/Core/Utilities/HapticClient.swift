import DependenciesMacros
import Foundation
import UIKit
import ComposableArchitecture

@DependencyClient
struct HapticClient {
  var impact: @Sendable (UIImpactFeedbackGenerator.FeedbackStyle) async -> Void = { _ in }
  var notification: @Sendable (UINotificationFeedbackGenerator.FeedbackType) async -> Void = { _ in }
  var selection: @Sendable () async -> Void = { }
}

extension HapticClient: DependencyKey {
  static let liveValue = HapticClient(
    impact: { style in
      await MainActor.run {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
      }
    },
    notification: { type in
      await MainActor.run {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
      }
    },
    selection: {
      await MainActor.run {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
      }
    }
  )
  
  static let testValue = HapticClient()
  static let mockValue = HapticClient()
}

extension DependencyValues {
  var hapticClient: HapticClient {
    get { self[HapticClient.self] }
    set { self[HapticClient.self] = newValue }
  }
  
  // Backward compatibility
  var haptics: HapticClient {
    get { self[HapticClient.self] }
    set { self[HapticClient.self] = newValue }
  }
}