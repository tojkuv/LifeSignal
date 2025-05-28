import Foundation
import ComposableArchitecture
import DependenciesMacros

@DependencyClient
struct PhoneNumberFormatterClient {
    var formatPhoneNumber: @Sendable (String) -> String = { _ in "" }
    var formatPhoneNumberForDisplay: @Sendable (String) -> String = { _ in "" }
    var cleanPhoneNumber: @Sendable (String) -> String = { _ in "" }
    var isValidPhoneNumber: @Sendable (String) -> Bool = { _ in false }
    var formatAsYouType: @Sendable (String) -> String = { _ in "" }
    var formatVerificationCode: @Sendable (String) -> String = { _ in "" }
    var cleanVerificationCode: @Sendable (String) -> String = { _ in "" }
    var isValidVerificationCode: @Sendable (String) -> Bool = { _ in false }
    var limitVerificationCodeLength: @Sendable (String) -> String = { _ in "" }
    var limitPhoneNumberLength: @Sendable (String) -> String = { _ in "" }
}

extension PhoneNumberFormatterClient: DependencyKey {
    static let liveValue = PhoneNumberFormatterClient(
        formatPhoneNumber: { phoneNumber in
            let cleaned = Self.cleanPhoneNumber(phoneNumber)
            guard cleaned.count >= 10 else { return phoneNumber }
            
            if cleaned.count == 10 {
                // US format: (XXX) XXX-XXXX
                let areaCode = String(cleaned.prefix(3))
                let exchange = String(cleaned.dropFirst(3).prefix(3))
                let number = String(cleaned.dropFirst(6))
                return "(\(areaCode)) \(exchange)-\(number)"
            } else if cleaned.count == 11 && cleaned.hasPrefix("1") {
                // US format with country code: +1 (XXX) XXX-XXXX
                let areaCode = String(cleaned.dropFirst(1).prefix(3))
                let exchange = String(cleaned.dropFirst(4).prefix(3))
                let number = String(cleaned.dropFirst(7))
                return "+1 (\(areaCode)) \(exchange)-\(number)"
            } else {
                // International format: +XX XXXX XXXX XXXX
                return "+\(cleaned)"
            }
        },
        
        formatPhoneNumberForDisplay: { phoneNumber in
            let cleaned = Self.cleanPhoneNumber(phoneNumber)
            guard cleaned.count >= 10 else { return phoneNumber }
            
            if cleaned.count == 10 {
                // US format: (XXX) XXX-XXXX
                let areaCode = String(cleaned.prefix(3))
                let exchange = String(cleaned.dropFirst(3).prefix(3))
                let number = String(cleaned.dropFirst(6))
                return "(\(areaCode)) \(exchange)-\(number)"
            } else if cleaned.count == 11 && cleaned.hasPrefix("1") {
                // US format with country code: +1 (XXX) XXX-XXXX
                let areaCode = String(cleaned.dropFirst(1).prefix(3))
                let exchange = String(cleaned.dropFirst(4).prefix(3))
                let number = String(cleaned.dropFirst(7))
                return "+1 (\(areaCode)) \(exchange)-\(number)"
            } else {
                // International format with spacing
                if cleaned.count <= 12 {
                    let chunks = cleaned.chunked(into: 3)
                    return "+\(chunks.joined(separator: " "))"
                } else {
                    return "+\(cleaned)"
                }
            }
        },
        
        cleanPhoneNumber: Self.cleanPhoneNumber,
        
        isValidPhoneNumber: { phoneNumber in
            let cleaned = Self.cleanPhoneNumber(phoneNumber)
            // US numbers: 10 digits or 11 digits starting with 1
            // International: 7-15 digits
            return cleaned.count >= 7 && cleaned.count <= 15 && 
                   (cleaned.count == 10 || 
                    (cleaned.count == 11 && cleaned.hasPrefix("1")) ||
                    cleaned.count >= 7)
        },
        
        formatAsYouType: { input in
            let cleaned = Self.cleanPhoneNumber(input)
            
            if cleaned.isEmpty { return "" }
            
            if cleaned.count <= 3 {
                return "(\(cleaned)"
            } else if cleaned.count <= 6 {
                let areaCode = String(cleaned.prefix(3))
                let exchange = String(cleaned.dropFirst(3))
                return "(\(areaCode)) \(exchange)"
            } else if cleaned.count <= 10 {
                let areaCode = String(cleaned.prefix(3))
                let exchange = String(cleaned.dropFirst(3).prefix(3))
                let number = String(cleaned.dropFirst(6))
                return "(\(areaCode)) \(exchange)-\(number)"
            } else if cleaned.count == 11 && cleaned.hasPrefix("1") {
                let areaCode = String(cleaned.dropFirst(1).prefix(3))
                let exchange = String(cleaned.dropFirst(4).prefix(3))
                let number = String(cleaned.dropFirst(7))
                return "+1 (\(areaCode)) \(exchange)-\(number)"
            } else {
                // International format
                return "+\(cleaned)"
            }
        },
        
        formatVerificationCode: { code in
            let cleaned = Self.cleanVerificationCode(code)
            guard cleaned.count >= 3 else { return cleaned }
            
            // Format as XXX-XXX for 6-digit codes
            if cleaned.count <= 6 {
                let first = String(cleaned.prefix(3))
                let second = String(cleaned.dropFirst(3))
                return second.isEmpty ? first : "\(first)-\(second)"
            }
            return cleaned
        },
        
        cleanVerificationCode: Self.cleanVerificationCode,
        
        isValidVerificationCode: { code in
            let cleaned = Self.cleanVerificationCode(code)
            return cleaned.count == 6
        },
        
        limitVerificationCodeLength: { code in
            let cleaned = Self.cleanVerificationCode(code)
            return String(cleaned.prefix(6))
        },
        
        limitPhoneNumberLength: { phone in
            let cleaned = Self.cleanPhoneNumber(phone)
            // Allow up to 15 digits for international numbers
            return String(cleaned.prefix(15))
        }
    )
    
    static let testValue = PhoneNumberFormatterClient(
        formatPhoneNumber: { $0 },
        formatPhoneNumberForDisplay: { $0 },
        cleanPhoneNumber: { $0 },
        isValidPhoneNumber: { _ in true },
        formatAsYouType: { $0 },
        formatVerificationCode: { $0 },
        cleanVerificationCode: { $0 },
        isValidVerificationCode: { _ in true },
        limitVerificationCodeLength: { $0 },
        limitPhoneNumberLength: { $0 }
    )
    
    static let mockValue = PhoneNumberFormatterClient(
        formatPhoneNumber: { phoneNumber in
            // Simple mock formatting for testing
            let cleaned = phoneNumber.filter { $0.isNumber }
            guard cleaned.count >= 10 else { return phoneNumber }
            
            let areaCode = String(cleaned.prefix(3))
            let exchange = String(cleaned.dropFirst(3).prefix(3))
            let number = String(cleaned.dropFirst(6).prefix(4))
            return "(\(areaCode)) \(exchange)-\(number)"
        },
        formatPhoneNumberForDisplay: { phoneNumber in
            // Same as formatPhoneNumber for mock
            let cleaned = phoneNumber.filter { $0.isNumber }
            guard cleaned.count >= 10 else { return phoneNumber }
            
            let areaCode = String(cleaned.prefix(3))
            let exchange = String(cleaned.dropFirst(3).prefix(3))
            let number = String(cleaned.dropFirst(6).prefix(4))
            return "(\(areaCode)) \(exchange)-\(number)"
        },
        cleanPhoneNumber: { phoneNumber in
            phoneNumber.filter { $0.isNumber }
        },
        isValidPhoneNumber: { phoneNumber in
            let cleaned = phoneNumber.filter { $0.isNumber }
            return cleaned.count >= 10
        },
        formatAsYouType: { input in
            let cleaned = input.filter { $0.isNumber }
            
            if cleaned.isEmpty { return "" }
            
            if cleaned.count <= 3 {
                return "(\(cleaned)"
            } else if cleaned.count <= 6 {
                let areaCode = String(cleaned.prefix(3))
                let exchange = String(cleaned.dropFirst(3))
                return "(\(areaCode)) \(exchange)"
            } else {
                let areaCode = String(cleaned.prefix(3))
                let exchange = String(cleaned.dropFirst(3).prefix(3))
                let number = String(cleaned.dropFirst(6))
                return "(\(areaCode)) \(exchange)-\(number)"
            }
        },
        formatVerificationCode: { code in
            let cleaned = code.filter { $0.isNumber }
            guard cleaned.count >= 3 else { return cleaned }
            
            if cleaned.count <= 6 {
                let first = String(cleaned.prefix(3))
                let second = String(cleaned.dropFirst(3))
                return second.isEmpty ? first : "\(first)-\(second)"
            }
            return cleaned
        },
        cleanVerificationCode: { code in
            code.filter { $0.isNumber }
        },
        isValidVerificationCode: { code in
            let cleaned = code.filter { $0.isNumber }
            return cleaned.count == 6
        },
        limitVerificationCodeLength: { code in
            let cleaned = code.filter { $0.isNumber }
            return String(cleaned.prefix(6))
        },
        limitPhoneNumberLength: { phone in
            let cleaned = phone.filter { $0.isNumber }
            return String(cleaned.prefix(15))
        }
    )
    
    // Helper methods for cleaning input
    private static func cleanPhoneNumber(_ phoneNumber: String) -> String {
        return phoneNumber.filter { $0.isNumber }
    }
    
    private static func cleanVerificationCode(_ code: String) -> String {
        return code.filter { $0.isNumber }
    }
}

// String extension for chunking
private extension String {
    func chunked(into size: Int) -> [String] {
        return stride(from: 0, to: count, by: size).map {
            let start = index(startIndex, offsetBy: $0)
            let end = index(start, offsetBy: min(size, count - $0))
            return String(self[start..<end])
        }
    }
}

extension DependencyValues {
    var phoneNumberFormatter: PhoneNumberFormatterClient {
        get { self[PhoneNumberFormatterClient.self] }
        set { self[PhoneNumberFormatterClient.self] = newValue }
    }
}