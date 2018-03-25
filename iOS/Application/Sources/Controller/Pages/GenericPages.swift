import UIKit

class ProgressPage: UIViewController {
  var primaryText: String! {
    didSet {
      guard isViewLoaded else { return }
      primaryLabel.text = primaryText
    }
  }
  @IBOutlet private var primaryLabel: UILabel!

  var secondaryText: String? {
    didSet {
      guard isViewLoaded else { return }
      secondaryLabel.text = secondaryText
    }
  }
  @IBOutlet private var secondaryLabel: UILabel!

  var progress: Progress! {
    didSet {
      guard isViewLoaded else { return }
      progressView.observedProgress = progress
    }
  }
  @IBOutlet private var progressView: UIProgressView!

  static func initWith(primaryText: String, secondaryText: String? = nil, progress: Progress) -> ProgressPage {
    let page = UIStoryboard(name: "GenericPages", bundle: nil).instantiate(ProgressPage.self)
    page.primaryText = primaryText
    page.secondaryText = secondaryText
    page.progress = progress
    return page
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    primaryLabel.text = primaryText
    secondaryLabel.text = secondaryText
    progressView.observedProgress = progress
  }
}

class ActionPage: UIViewController {
  var primaryText: String! {
    didSet {
      guard isViewLoaded else { return }
      primaryLabel.text = primaryText
    }
  }
  @IBOutlet private var primaryLabel: UILabel!

  var secondaryText: String? {
    didSet {
      guard isViewLoaded else { return }
      secondaryLabel.text = secondaryText
    }
  }
  @IBOutlet private var secondaryLabel: UILabel!

  var actionTitle: String! {
    didSet {
      guard isViewLoaded else { return }
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
