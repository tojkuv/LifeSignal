import DependenciesMacros
import Foundation
import ComposableArchitecture

@DependencyClient
struct PhoneFormatterClient {
    var formatPhoneNumber: @Sendable (String, String) -> String = { _, _ in "" }
    var formatPhoneNumberForEditing: @Sendable (String, String) -> String = { _, _ in "" }
    
    // General formatting functionality (previously in FormatterClient)
    var currency: @Sendable (Double, Locale?) -> String = { _, _ in "" }
    var date: @Sendable (Date, DateFormatter.Style, DateFormatter.Style?) -> String = { _, _, _ in "" }
    var relativeTime: @Sendable (Date) -> String = { _ in "" }
    var percentage: @Sendable (Double, Int?) -> String = { _, _ in "" }
    var fileSize: @Sendable (Int64) -> String = { _ in "" }
}

extension PhoneFormatterClient: DependencyKey {
    static let liveValue = PhoneFormatterClient(
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
    
    static let testValue = PhoneFormatterClient(
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
    var phoneFormatterClient: PhoneFormatterClient {
        get { self[PhoneFormatterClient.self] }
        set { self[PhoneFormatterClient.self] = newValue }
    }
    
    // Backward compatibility - FormatterClient functionality merged into PhoneFormatterClient
    var formatterClient: PhoneFormatterClient {
        get { self[PhoneFormatterClient.self] }
        set { self[PhoneFormatterClient.self] = newValue }
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