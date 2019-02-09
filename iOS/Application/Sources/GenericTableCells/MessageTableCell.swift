import UIKit

class MessageTableCell: UITableViewCell {
  enum MessageStyle {
    case `default`
    case error
  }

  var messageStyle: MessageStyle = .default {
    didSet {
      switch messageStyle {
        case .default:
          label.textColor = .black
        case .error:
          label.textColor = .red
      }
    }
  }

  var message: String {
    get {
      return label.text ?? ""
    }
    set {
      label.text = newValue
    }
  }
  @IBOutlet private var label: UILabel!
}
