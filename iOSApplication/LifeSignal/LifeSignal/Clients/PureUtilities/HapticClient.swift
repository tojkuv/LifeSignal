import DependenciesMacros
import Foundation
import UIKit
import ComposableArchitecture

@DependencyClient
struct HapticClient {
  @DependencyEndpoint
  var impact: @Sendable (UIImpactFeedbackGenerator.FeedbackStyle) async -> Void
  @DependencyEndpoint
  var notification: @Sendable (UINotificationFeedbackGenerator.FeedbackType) async -> Void
  @DependencyEndpoint
  var selection: @Sendable () async -> Void
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
  
  static let testValue = HapticClient(
    impact: { _ in },
    notification: { _ in },
    selection: { }
  )
  
  static let mockValue = HapticClient(
    impact: { _ in },
    notification: { _ in },
    selection: { }
  )
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