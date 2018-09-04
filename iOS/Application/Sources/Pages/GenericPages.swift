import UIKit

class WaitingPage: UIViewController {
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

  static func initWith(primaryText: String, secondaryText: String? = nil) -> WaitingPage {
    let page = UIStoryboard(name: "GenericPages", bundle: nil).instantiate(WaitingPage.self)
    page.primaryText = primaryText
    page.secondaryText = secondaryText
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

  var image: UIImage? {
    didSet {
      guard isViewLoaded else { return }
      imageView.image = image
    }
  }
  @IBOutlet private var imageView: UIImageView!

  private var primaryActionTitle: String?
  private var primaryActionHandler: (() -> Void)?
  @IBOutlet private var primaryButton: UIButton!

  private var secondaryActionTitle: String?
  private var secondaryActionHandler: (() -> Void)?
  @IBOutlet private var secondaryButton: UIButton!

  static func initWith(primaryText: String,
                       secondaryText: String? = nil,
                       image: UIImage? = nil,
                       actionTitle: String,
                       actionHandler: @escaping () -> Void) -> ActionPage {
    let page = UIStoryboard(name: "GenericPages", bundle: nil).instantiate(ActionPage.self)
    page.primaryText = primaryText
    page.secondaryText = secondaryText
    page.image = image
    page.primaryActionTitle = actionTitle
    page.primaryActionHandler = actionHandler
    return page
  }

  static func initWith(primaryText: String,
                       secondaryText: String? = nil,
                       image: UIImage? = nil) -> ActionPage {
    let page = UIStoryboard(name: "GenericPages", bundle: nil).instantiate(ActionPage.self)
    page.primaryText = primaryText
    page.secondaryText = secondaryText
    page.image = image
    page.primaryActionTitle = nil
    page.primaryActionHandler = nil
    page.secondaryActionTitle = nil
    page.secondaryActionHandler = nil
    return page
  }

  static func initWith(primaryText: String,
                       secondaryText: String? = nil,
                       image: UIImage? = nil,
                       primaryActionTitle: String,
                       primaryActionHandler: @escaping () -> Void,
                       secondaryActionTitle: String,
                       secondaryActionHandler: @escaping () -> Void) -> ActionPage {
    let page = UIStoryboard(name: "GenericPages", bundle: nil).instantiate(ActionPage.self)
    page.primaryText = primaryText
    page.secondaryText = secondaryText
    page.image = image
    page.primaryActionTitle = primaryActionTitle
    page.primaryActionHandler = primaryActionHandler
    page.secondaryActionTitle = secondaryActionTitle
    page.secondaryActionHandler = secondaryActionHandler
    return page
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    primaryLabel.text = primaryText
    secondaryLabel.text = secondaryText
    imageView.image = image
    primaryButton.setTitle(primaryActionTitle, for: .normal)
    primaryButton.isHidden = primaryActionHandler == nil
    secondaryButton.setTitle(secondaryActionTitle, for: .normal)
    secondaryButton.isHidden = secondaryActionHandler == nil
  }

  @IBAction private func primaryButtonTapped() {
    primaryButton.isUserInteractionEnabled = false
    primaryActionHandler?()
  }

  @IBAction private func secondaryButtonTapped() {
    primaryButton.isUserInteractionEnabled = false
    secondaryActionHandler?()
  }
}
