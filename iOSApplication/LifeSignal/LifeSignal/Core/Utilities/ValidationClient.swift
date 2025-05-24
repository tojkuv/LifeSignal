import DependenciesMacros
import Foundation
import ComposableArchitecture

enum ValidationResult: Equatable {
    case valid
    case invalid(String)

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    var errorMessage: String? {
        if case .invalid(let msg) = self { return msg }
        return nil
    }
}

@DependencyClient
struct ValidationClient {
    // Validation
    var validatePhoneNumber: @Sendable (String) -> ValidationResult = { _ in .valid }
    var validateName: @Sendable (String) -> ValidationResult = { _ in .valid }
    var validateVerificationCode: @Sendable (String) -> ValidationResult = { _ in .valid }

    // Phone formatting
    var formatPhoneNumber: @Sendable (String, String) -> String = { _, _ in "" }
    var formatPhoneNumberForEditing: @Sendable (String, String) -> String = { _, _ in "" }

    // General formatting
    var currency: @Sendable (Double, Locale?) -> String = { _, _ in "" }
    var date: @Sendable (Date, DateFormatter.Style, DateFormatter.Style?) -> String = { _, _, _ in "" }
    var relativeTime: @Sendable (Date) -> String = { _ in "" }
    var percentage: @Sendable (Double, Int?) -> String = { _, _ in "" }
    var fileSize: @Sendable (Int64) -> String = { _ in "" }
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

        formatPhoneNumber: { phoneNumber, region in
            let digits = phoneNumber.filter { $0.isNumber }

            guard !digits.isEmpty else { return "" }

            switch region {
            case "US", "CA":
                return formatUSPhoneNumber(digits)
            case "UK":
                return formatUKPhoneNumber(digits)
            case "AU":
                return formatAUPhoneNumber(digits)
            default:
                return formatUSPhoneNumber(digits)
            }
        },

        formatPhoneNumberForEditing: { phoneNumber, region in
            let digits = phoneNumber.filter { $0.isNumber }

            guard !digits.isEmpty else { return "" }

            switch region {
            case "US", "CA":
                return formatUSPhoneNumberForEditing(digits)
            case "UK":
                return formatUKPhoneNumberForEditing(digits)
            case "AU":
                return formatAUPhoneNumberForEditing(digits)
            default:
                return formatUSPhoneNumberForEditing(digits)
            }
        },

        // General formatting functionality
        currency: { amount, locale in
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = locale ?? .current
            return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
        },

        date: { date, dateStyle, timeStyle in
            let formatter = DateFormatter()
            formatter.dateStyle = dateStyle
            formatter.timeStyle = timeStyle ?? .none
            return formatter.string(from: date)
        },

        relativeTime: { date in
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return formatter.localizedString(for: date, relativeTo: Date())
        },

        percentage: { value, fractionDigits in
            let formatter = NumberFormatter()
            formatter.numberStyle = .percent
            formatter.minimumFractionDigits = fractionDigits ?? 0
            formatter.maximumFractionDigits = fractionDigits ?? 2
            return formatter.string(from: NSNumber(value: value)) ?? "0%"
        },

        fileSize: { bytes in
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useAll]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: bytes)
        }
    )

    static let testValue = ValidationClient(
        validatePhoneNumber: { _ in .valid },
        validateName: { _ in .valid },
        validateVerificationCode: { _ in .valid },
        formatPhoneNumber: { phoneNumber, _ in phoneNumber },
        formatPhoneNumberForEditing: { phoneNumber, _ in phoneNumber },
        currency: { amount, _ in "$\(amount)" },
        date: { date, _, _ in "Mock Date" },
        relativeTime: { _ in "Mock Relative Time" },
        percentage: { value, _ in "\(Int(value * 100))%" },
        fileSize: { bytes in "\(bytes) bytes" }
    )
}

extension DependencyValues {
    var validationClient: ValidationClient {
        get { self[ValidationClient.self] }
        set { self[ValidationClient.self] = newValue }
    }

    // Backward compatibility aliases
    var phoneFormatterClient: ValidationClient {
        get { self[ValidationClient.self] }
        set { self[ValidationClient.self] = newValue }
    }

    var formatterClient: ValidationClient {
        get { self[ValidationClient.self] }
        set { self[ValidationClient.self] = newValue }
    }
}

// MARK: - Private formatting functions

private func formatUSPhoneNumber(_ digits: String) -> String {
    let limitedDigits = String(digits.prefix(10))

    if limitedDigits.count == 10 {
        let areaCode = limitedDigits.prefix(3)
        let prefix = limitedDigits.dropFirst(3).prefix(3)
        let lineNumber = limitedDigits.dropFirst(6)
        return "+1 (\(areaCode)) \(prefix)-\(lineNumber)"
    } else if limitedDigits.count > 0 {
        return "+1 \(limitedDigits)"
    } else {
        return ""
    }
}

private func formatUKPhoneNumber(_ digits: String) -> String {
    let limitedDigits = String(digits.prefix(10))

    if limitedDigits.count == 10 {
        let areaCode = limitedDigits.prefix(4)
        let prefix = limitedDigits.dropFirst(4).prefix(3)
        let lineNumber = limitedDigits.dropFirst(7)
        return "+44 \(areaCode) \(prefix) \(lineNumber)"
    } else if limitedDigits.count > 0 {
        return "+44 \(limitedDigits)"
    } else {
        return ""
    }
}

private func formatAUPhoneNumber(_ digits: String) -> String {
    let limitedDigits = String(digits.prefix(10))

    if limitedDigits.count == 10 {
        let areaCode = limitedDigits.prefix(4)
        let prefix = limitedDigits.dropFirst(4).prefix(3)
        let lineNumber = limitedDigits.dropFirst(7)
        return "+61 \(areaCode) \(prefix) \(lineNumber)"
    } else if limitedDigits.count > 0 {
        return "+61 \(limitedDigits)"
    } else {
        return ""
    }
}

private func formatUSPhoneNumberForEditing(_ digits: String) -> String {
    let limitedDigits = String(digits.prefix(10))

    if limitedDigits.count > 6 {
        let areaCode = limitedDigits.prefix(3)
        let prefix = limitedDigits.dropFirst(3).prefix(3)
        let lineNumber = limitedDigits.dropFirst(6)
        return "\(areaCode)-\(prefix)-\(lineNumber)"
    } else if limitedDigits.count > 3 {
        let areaCode = limitedDigits.prefix(3)
        let prefix = limitedDigits.dropFirst(3)
        return "\(areaCode)-\(prefix)"
    } else if limitedDigits.count > 0 {
        return limitedDigits
    } else {
        return ""
    }
}

private func formatUKPhoneNumberForEditing(_ digits: String) -> String {
    let limitedDigits = String(digits.prefix(10))

    if limitedDigits.count > 7 {
        let areaCode = limitedDigits.prefix(4)
        let prefix = limitedDigits.dropFirst(4).prefix(3)
        let lineNumber = limitedDigits.dropFirst(7)
        return "\(areaCode)-\(prefix)-\(lineNumber)"
    } else if limitedDigits.count > 4 {
        let areaCode = limitedDigits.prefix(4)
        let prefix = limitedDigits.dropFirst(4)
        return "\(areaCode)-\(prefix)"
    } else if limitedDigits.count > 0 {
        return limitedDigits
    } else {
        return ""
    }
}

private func formatAUPhoneNumberForEditing(_ digits: String) -> String {
    let limitedDigits = String(digits.prefix(10))

    if limitedDigits.count > 7 {
        let areaCode = limitedDigits.prefix(4)
        let prefix = limitedDigits.dropFirst(4).prefix(3)
        let lineNumber = limitedDigits.dropFirst(7)
        return "\(areaCode)-\(prefix)-\(lineNumber)"
    } else if limitedDigits.count > 4 {
        let areaCode = limitedDigits.prefix(4)
        let prefix = limitedDigits.dropFirst(4)
        return "\(areaCode)-\(prefix)"
    } else if limitedDigits.count > 0 {
        return limitedDigits
    } else {
        return ""
    }
}