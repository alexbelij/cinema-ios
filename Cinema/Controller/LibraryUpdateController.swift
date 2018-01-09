import UIKit

class LibraryUpdateController: UIViewController {
  var poster: UIImage? {
    didSet {
      loadViewIfNeeded()
      posterView.image = poster ?? .genericPosterImage(minWidth: posterView.frame.size.width)
    }
  }
  @IBOutlet private weak var posterView: UIImageView!
  @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
  @IBOutlet private weak var label: UILabel!
  @IBOutlet private weak var messageLabel: UILabel!

  enum UpdateResult {
    case success(addedItemTitle: String)
    case failure(Error)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    posterView.image = .genericPosterImage(minWidth: posterView.frame.size.width)
    posterView.layer.borderColor = UIColor.posterBorder.cgColor
    posterView.layer.borderWidth = 0.5
    label.text = NSLocalizedString("addItem.progress", comment: "")
  }

  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    self.activityIndicator.startAnimating()
  }

  func endUpdate(result: UpdateResult) {
    switch result {
      case let .success(addedItemTitle):
        self.label.text = NSLocalizedString("addItem.succeeded", comment: "")
        self.messageLabel.text = String(format: NSLocalizedString("addItem.succeeded.changes", comment: ""),
                                        addedItemTitle)
      case let .failure(error):
        self.label.text = NSLocalizedString("addItem.failed", comment: "")
        self.messageLabel.text = L10n.errorMessage(for: error)
    }
    self.activityIndicator.stopAnimating()
    self.messageLabel.isHidden = false
  }
}
