import DependenciesMacros
import Foundation
import ComposableArchitecture

enum ValidationResult: Equatable {
  case valid, invalid(String)
  var isValid: Bool { if case .valid = self { return true }; return false }
  var errorMessage: String? { if case .invalid(let msg) = self { return msg }; return nil }
}

@DependencyClient
struct ValidationClient {
  var validatePhoneNumber: @Sendable (String) -> ValidationResult = { _ in .valid }
  var validateName: @Sendable (String) -> ValidationResult = { _ in .valid }
  var validateVerificationCode: @Sendable (String) -> ValidationResult = { _ in .valid }
  var formatPhoneNumber: @Sendable (String) -> String = { $0 }
}

extension ValidationClient: DependencyKey {
  static let liveValue = ValidationClient(
    validatePhoneNumber: { phone in
      let cleaned = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
      if cleaned.isEmpty { return .invalid("Phone number is required") }
      if cleaned.hasPrefix("+") {
        return cleaned.count >= 8 && cleaned.count <= 16 ? .valid : .invalid("Invalid international phone number")
      } else {
        return cleaned.count == 10 ? .valid : .invalid("Phone number must be 10 digits")
      }
    },
    validateName: { name in
      let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.isEmpty { return .invalid("Name is required") }
      return trimmed.count >= 2 && trimmed.count <= 50 ? .valid : .invalid("Name must be 2-50 characters")
    },
    validateVerificationCode: { code in
      let cleaned = code.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
      return cleaned.count == 6 ? .valid : .invalid("Verification code must be 6 digits")
    },
    formatPhoneNumber: { phone in
      let cleaned = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
      return cleaned.count == 10 ?
        String(format: "(%@) %@-%@", String(cleaned.prefix(3)), String(cleaned.dropFirst(3).prefix(3)), String(cleaned.dropFirst(6))) :
        phone
    }
  )
  
  static let testValue = ValidationClient(
    validatePhoneNumber: { _ in .valid },
    validateName: { _ in .valid },
    validateVerificationCode: { _ in .valid },
    formatPhoneNumber: { _ in "(555) 123-4567" }
  )
}

extension DependencyValues {
  var validationClient: ValidationClient {
    get { self[ValidationClient.self] }
    set { self[ValidationClient.self] = newValue }
  }
}