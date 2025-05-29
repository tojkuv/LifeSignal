import Foundation

// MARK: - Shared Empty Proto Type

/// Empty protocol buffer response type used across all gRPC clients
/// This represents successful operations that don't return data (void responses)
struct Empty_Proto: Sendable {}