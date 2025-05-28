import SwiftUI
import UIKit

struct LimitedDigitTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let digitLimit: Int
    let keyboardType: UIKeyboardType
    let isDisabled: Bool
    let onTextChange: (String) -> Void
    var isFocused: Bool = false
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        textField.borderStyle = .none
        textField.font = UIFont.preferredFont(forTextStyle: .body)
        textField.textAlignment = .center
        textField.isEnabled = !isDisabled
        textField.textColor = UIColor.label
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.isEnabled = !isDisabled
        uiView.placeholder = placeholder
        
        // Update coordinator's parent reference when digitLimit changes
        context.coordinator.parent = self
        
        // Handle focus state
        if isFocused && !uiView.isFirstResponder {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        } else if !isFocused && uiView.isFirstResponder {
            DispatchQueue.main.async {
                uiView.resignFirstResponder()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: LimitedDigitTextField
        
        init(_ parent: LimitedDigitTextField) {
            self.parent = parent
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let currentText = textField.text ?? ""
            guard let stringRange = Range(range, in: currentText) else { return false }
            
            let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
            let digitCount = updatedText.filter { $0.isNumber }.count
            
            // Prevent input if it would exceed the digit limit
            if digitCount > parent.digitLimit {
                return false
            }
            
            // Update the binding and trigger callback
            DispatchQueue.main.async {
                self.parent.text = updatedText
                self.parent.onTextChange(updatedText)
            }
            
            return true
        }
    }
}