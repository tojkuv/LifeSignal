import Foundation

/// Utility for formatting phone numbers
struct PhoneFormatter {
    /// Format a phone number based on the region for display
    /// - Parameters:
    ///   - phoneNumber: The phone number to format
    ///   - region: The region code (e.g., "US", "UK")
    /// - Returns: A formatted phone number string for display
    static func formatPhoneNumber(_ phoneNumber: String, region: String) -> String {
        // Remove any non-digit characters
        let digits = phoneNumber.filter { $0.isNumber }

        // If empty, return empty string
        if digits.isEmpty {
            return ""
        }

        // Format based on region
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
    }

    /// Format a phone number based on the region for editing (with hyphens)
    /// - Parameters:
    ///   - phoneNumber: The phone number to format
    ///   - region: The region code (e.g., "US", "UK")
    /// - Returns: A formatted phone number string with hyphens for editing
    static func formatPhoneNumberForEditing(_ phoneNumber: String, region: String) -> String {
        // Remove any non-digit characters
        let digits = phoneNumber.filter { $0.isNumber }

        // If empty, return empty string
        if digits.isEmpty {
            return ""
        }

        // Format based on region
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
    }

    /// Format a US/Canada phone number
    /// - Parameter digits: The digits to format
    /// - Returns: A formatted phone number string
    private static func formatUSPhoneNumber(_ digits: String) -> String {
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

    /// Format a UK phone number
    /// - Parameter digits: The digits to format
    /// - Returns: A formatted phone number string
    private static func formatUKPhoneNumber(_ digits: String) -> String {
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

    /// Format an Australian phone number
    /// - Parameter digits: The digits to format
    /// - Returns: A formatted phone number string
    private static func formatAUPhoneNumber(_ digits: String) -> String {
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

    /// Format a US/Canada phone number for editing (XXX-XXX-XXXX)
    /// - Parameter digits: The digits to format
    /// - Returns: A formatted phone number string with hyphens
    static func formatUSPhoneNumberForEditing(_ digits: String) -> String {
        // Limit to 10 digits
        let limitedDigits = String(digits.prefix(10))

        // Format with hyphens
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

    /// Format a UK phone number for editing (XXXX-XXX-XXX)
    /// - Parameter digits: The digits to format
    /// - Returns: A formatted phone number string with hyphens
    static func formatUKPhoneNumberForEditing(_ digits: String) -> String {
        // Limit to 10 digits
        let limitedDigits = String(digits.prefix(10))

        // Format with hyphens
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

    /// Format an Australian phone number for editing (XXXX-XXX-XXX)
    /// - Parameter digits: The digits to format
    /// - Returns: A formatted phone number string with hyphens
    static func formatAUPhoneNumberForEditing(_ digits: String) -> String {
        // Limit to 10 digits
        let limitedDigits = String(digits.prefix(10))

        // Format with hyphens
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
}
