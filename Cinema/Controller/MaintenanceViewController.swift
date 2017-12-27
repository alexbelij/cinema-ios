import Dispatch
import UIKit

class MaintenanceViewController: UIViewController {

  var primaryText: String! {
    didSet {
      guard isViewLoaded else { return }
      DispatchQueue.main.async {
        self.primaryLabel.text = self.primaryText
      }
    }
  }
  var secondaryText: String? {
    didSet {
      guard isViewLoaded else { return }
      DispatchQueue.main.async {
        self.secondaryLabel.text = self.secondaryText
        self.secondaryLabel.isHidden = self.secondaryText == nil
      }
    }
  }
  var dismissHandler: DismissHandler = .standard

  @IBOutlet private weak var primaryLabel: UILabel!
  @IBOutlet private weak var secondaryLabel: UILabel!
  @IBOutlet private weak var actionButton: UIButton!
  @IBOutlet private weak var progressBar: UIProgressView!

  private var performActionFunction: (() -> Void)!
  private var initiation: ActionInitiation!
  private var actionCompletion: (() -> Void)!
  private var buttonState: ButtonState = .startAction

  func run<Action, Result>(_ action: Action,
                           initiation: ActionInitiation,
                           completion: @escaping (ActionResult<Result>) -> Void)
      where Action: MaintenanceAction, Action.ResultType == Result {
    self.performActionFunction = { [weak self] in
      guard let `self` = self else { return }
      action.performAction { result in
        completion(result)
        DispatchQueue.main.async {
          self.actionButton.setTitle(NSLocalizedString("continue", comment: ""), for: .normal)
          self.actionButton.isHidden = false
          self.progressBar.isHidden = true
        }
      }
    }
    self.initiation = initiation
    self.actionCompletion = {}
    self.loadViewIfNeeded()
    self.progressBar.observedProgress = action.progress
  }

  override func viewWillAppear(_ animated: Bool) {
    guard primaryText != nil else { fatalError("primary text is not set") }
    super.viewWillAppear(animated)
    primaryLabel.text = primaryText
    secondaryLabel.text = secondaryText
    if case let ActionInitiation.button(title) = initiation! {
      actionButton.setTitle(title, for: .normal)
      actionButton.isHidden = false
    } else {
      actionButton.isHidden = true
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if case ActionInitiation.runAutomatically = initiation! {
      startAction()
    }
  }

  @IBAction func actionButtonClicked(_ sender: Any) {
    switch buttonState {
      case .startAction:
        actionButton.isHidden = true
        startAction()
      case .dismiss:
        switch dismissHandler {
          case .standard: self.dismiss(animated: true)
          case let .custom(handler): handler()
        }
    }
  }

  private func startAction() {
    self.progressBar.isHidden = false
    self.buttonState = .dismiss
    DispatchQueue.global(qos: .userInitiated).async {
      self.performActionFunction()
    }
  }

  enum ActionInitiation {
    case runAutomatically
    case button(title: String)
  }

  enum DismissHandler {
    case standard
    case custom(handler: () -> Void)
  }

  private enum ButtonState {
    case startAction
    case dismiss
  }
}
