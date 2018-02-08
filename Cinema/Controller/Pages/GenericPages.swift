import UIKit

class ProgressPage: UIViewController {
  var primaryText: String! {
    didSet {
      primaryLabel.text = primaryText
    }
  }
  @IBOutlet private var primaryLabel: UILabel!

  var secondaryText: String? {
    didSet {
      secondaryLabel.text = secondaryText
    }
  }
  @IBOutlet private var secondaryLabel: UILabel!

  @IBOutlet private var progressView: UIProgressView!

  static func initWith(primaryText: String, secondaryText: String? = nil, progress: Progress) -> ProgressPage {
    let page = UIStoryboard(name: "GenericPages", bundle: nil).instantiate(ProgressPage.self)
    page.loadViewIfNeeded()
    page.primaryText = primaryText
    page.secondaryText = secondaryText
    page.progressView.observedProgress = progress
    return page
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    primaryLabel.text = primaryText
    secondaryLabel.text = secondaryText
  }
}

class ActionPage: UIViewController {
  var primaryText: String! {
    didSet {
      primaryLabel.text = primaryText
    }
  }
  @IBOutlet private var primaryLabel: UILabel!

  var secondaryText: String? {
    didSet {
      secondaryLabel.text = secondaryText
    }
  }
  @IBOutlet private var secondaryLabel: UILabel!

  var actionTitle: String! {
    didSet {
      button.setTitle(actionTitle, for: .normal)
    }
  }

  @IBOutlet private var button: UIButton!
  private var actionHandler: (() -> Void)!

  static func initWith(primaryText: String,
                       secondaryText: String? = nil,
                       actionTitle: String,
                       actionHandler: @escaping () -> Void) -> ActionPage {
    let page = UIStoryboard(name: "GenericPages", bundle: nil).instantiate(ActionPage.self)
    page.loadViewIfNeeded()
    page.primaryText = primaryText
    page.secondaryText = secondaryText
    page.actionTitle = actionTitle
    page.actionHandler = actionHandler
    return page
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    primaryLabel.text = primaryText
    secondaryLabel.text = secondaryText
    button.setTitle(actionTitle, for: .normal)
  }

  @IBAction private func continueButtonTapped() {
    actionHandler()
  }
}
