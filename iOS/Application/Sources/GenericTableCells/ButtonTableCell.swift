import UIKit

class ButtonTableCell: UITableViewCell {
  enum ButtonStyle {
    case `default`
    case destructive
  }

  var actionTitle: String {
    get {
      return label.text ?? ""
    }
    set {
      label.text = newValue
    }
  }
  @IBOutlet private weak var label: UILabel!

  var actionTitleAlignment: NSTextAlignment = .left {
    didSet {
      label.textAlignment = actionTitleAlignment
    }
  }

  var buttonStyle: ButtonStyle = .default {
    didSet {
      switch buttonStyle {
        case .default:
          label.textColor = tintColor
        case .destructive:
          label.textColor = .destructive
      }
    }
  }

  @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
  var showsActivityIndicator: Bool = false {
    didSet {
      if showsActivityIndicator {
        activityIndicator.startAnimating()
        label.isHidden = true
      } else {
        activityIndicator.stopAnimating()
        label.isHidden = false
      }
    }
  }
}
