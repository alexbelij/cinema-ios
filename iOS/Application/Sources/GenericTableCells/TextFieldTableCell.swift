import UIKit

class TextFieldTableCell: UITableViewCell, UITextFieldDelegate {
  @IBOutlet private var textField: UITextField!

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

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return false
  }

  var onChange: ((String) -> Void)?

  @objc
  func textFieldDidChange(_ textField: UITextField) {
    onChange?(textField.text ?? "")
  }
}
