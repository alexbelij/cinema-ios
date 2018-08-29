import UIKit

class TextFieldTableCell: UITableViewCell, UITextFieldDelegate {
  @IBOutlet private weak var textField: UITextField!

  override func awakeFromNib() {
    super.awakeFromNib()
    textField.delegate = self
    textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
  }

  var isEnabled: Bool {
    get {
      return textField.isEnabled
    }
    set {
      textField.isEnabled = newValue
      textField.textColor = newValue ? .black : .disabledControlText
    }
  }

  var textValue: String {
    get {
      return textField.text ?? ""
    }
    set {
      textField.text = newValue
    }
  }

  var shouldResignFirstResponderOnReturn: Bool = true

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    if shouldResignFirstResponderOnReturn {
      textField.resignFirstResponder()
      return false
    } else {
      return true
    }
  }

  var onChange: ((String) -> Void)?

  @objc
  func textFieldDidChange(_ textField: UITextField) {
    onChange?(textField.text ?? "")
  }
}
