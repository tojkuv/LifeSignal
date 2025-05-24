import DependenciesMacros
import Foundation
import ComposableArchitecture
import os.log

@DependencyClient
struct LoggingClient {
  var debug: @Sendable (String, [String: Any]) -> Void = { _, _ in }
  var info: @Sendable (String, [String: Any]) -> Void = { _, _ in }
  var warning: @Sendable (String, [String: Any]) -> Void = { _, _ in }
  var error: @Sendable (String, Error?, [String: Any]) -> Void = { _, _, _ in }
}

extension LoggingClient: DependencyKey {
  static let liveValue = LoggingClient(
    debug: { message, metadata in
      let logger = Logger(subsystem: "com.lifesignal.app", category: "debug")
      let metadataString = metadata.isEmpty ? "" : " \(metadata)"
      logger.debug("\(message)\(metadataString)")
    },
    info: { message, metadata in
      let logger = Logger(subsystem: "com.lifesignal.app", category: "info")
      let metadataString = metadata.isEmpty ? "" : " \(metadata)"
      logger.info("\(message)\(metadataString)")
    },
    warning: { message, metadata in
      let logger = Logger(subsystem: "com.lifesignal.app", category: "warning")
      let metadataString = metadata.isEmpty ? "" : " \(metadata)"
      logger.warning("\(message)\(metadataString)")
    },
    error: { message, error, metadata in
      let logger = Logger(subsystem: "com.lifesignal.app", category: "error")
      let errorString = error?.localizedDescription ?? ""
      let metadataString = metadata.isEmpty ? "" : " \(metadata)"
      logger.error("\(message) \(errorString)\(metadataString)")
    }
  )
  
  static let testValue = LoggingClient(
    debug: { message, metadata in
      print("🐛 DEBUG: \(message) \(metadata)")
    },
    info: { message, metadata in
      print("ℹ️ INFO: \(message) \(metadata)")
    },
    warning: { message, metadata in
      print("⚠️ WARNING: \(message) \(metadata)")
    },
    error: { message, error, metadata in
      print("❌ ERROR: \(message) \(error?.localizedDescription ?? "") \(metadata)")
    }
  )
  
  static let mockValue = LoggingClient()
}

extension DependencyValues {
  var logging: LoggingClient {
    get { self[LoggingClient.self] }
    set { self[LoggingClient.self] = newValue }
  }
}