import DependenciesMacros
import Foundation
import SwiftUI
import ComposableArchitecture

@DependencyClient
struct ContactFormatterClient {
  var statusDisplay: @Sendable (Contact.Status) -> (String, Color) = { _ in ("", .gray) }
  var lastSeenText: @Sendable (Date) -> String = { _ in "" }
}

extension ContactFormatterClient: DependencyKey {
  static let liveValue = ContactFormatterClient(
    statusDisplay: { status in
      switch status {
      case .active: return ("Online", .green)
      case .away: return ("Away", .yellow)
      case .busy: return ("Busy", .red)
      case .offline: return ("Offline", .gray)
      }
    },

    lastSeenText: { date in
      let now = Date()
      let interval = now.timeIntervalSince(date)

      if interval < 60 {
        return "Just now"
      } else if interval < 3600 {
        let minutes = Int(interval / 60)
        return "\(minutes)m ago"
      } else if interval < 86400 {
        let hours = Int(interval / 3600)
        return "\(hours)h ago"
      } else {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
      }
    }
  )

  static let testValue = ContactFormatterClient(
    statusDisplay: { status in ("Mock Status", .gray) },
    lastSeenText: { _ in "Mock Time" }
  )
}

extension DependencyValues {
  var contactFormatterClient: ContactFormatterClient {
    get { self[ContactFormatterClient.self] }
    set { self[ContactFormatterClient.self] = newValue }
  }
}