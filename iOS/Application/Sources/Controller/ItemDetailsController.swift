import CinemaKit
import UIKit

protocol ItemDetailsControllerDelegate: class {
  func itemDetailsControllerDidDismiss(_ controller: ItemDetailsController)
}

class ItemDetailsController: UIViewController {
  enum RemoteProperty<Type> {
    case loading
    case available(Type)
    case unavailable
  }

  weak var delegate: ItemDetailsControllerDelegate?

  var itemTitle: String = "" {
    didSet {
      self.loadViewIfNeeded()
      self.titleLabel.text = itemTitle
    }
  }
  @IBOutlet private weak var titleLabel: UILabel!

  var subtitle: String? {
    didSet {
      self.loadViewIfNeeded()
      if let subtitle = self.subtitle {
        self.subtitleLabel.isHidden = false
        self.subtitleLabel.text = subtitle
      } else {
        self.subtitleLabel.isHidden = true
      }
    }
  }
  @IBOutlet private weak var subtitleLabel: UILabel!

  var poster: RemoteProperty<UIImage> = .loading {
    didSet {
      self.loadViewIfNeeded()
      switch poster {
        case .loading, .unavailable:
          self.posterView.image = .genericPosterImage(minWidth: posterView.frame.size.width)
        case let .available(image):
          self.posterView.image = image
      }
    }
  }
  @IBOutlet private weak var posterView: UIImageView!

  var genreIds = [GenreIdentifier]() {
    didSet {
      self.loadViewIfNeeded()
      let names = self.genreIds.compactMap(L10n.genreName)
      if names.isEmpty {
        self.genreLabel.text = NSLocalizedString("details.missing.genre", comment: "")
      } else {
        self.genreLabel.text = names.joined(separator: ", ")
      }
    }
  }
  @IBOutlet private weak var genreLabel: UILabel!

  var runtime: Measurement<UnitDuration>? {
    didSet {
      self.loadViewIfNeeded()
      if let runtime = self.runtime {
        runtimeLabel.text = Utils.formatDuration(runtime)
      } else {
        runtimeLabel.text = NSLocalizedString("details.missing.runtime", comment: "")
      }
    }
  }
  @IBOutlet private weak var runtimeLabel: UILabel!

  private static let releaseDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .none
    return formatter
  }()

  var releaseDate: Date? {
    didSet {
      self.loadViewIfNeeded()
      if let releaseDate = self.releaseDate {
        releaseDateLabel.text = ItemDetailsController.releaseDateFormatter.string(from: releaseDate)
      } else {
        releaseDateLabel.text = NSLocalizedString("details.missing.releaseDate", comment: "")
      }
    }
  }
  @IBOutlet private weak var releaseDateLabel: UILabel!

  var certification: RemoteProperty<String> = .loading {
    didSet {
      self.loadViewIfNeeded()
      switch certification {
        case .loading:
          self.certificationLabel.text = NSLocalizedString("loading", comment: "")
        case .unavailable:
          self.certificationLabel.text = NSLocalizedString("details.missing.certification", comment: "")
        case let .available(certification):
          self.certificationLabel.text = certification
      }
    }
  }
  @IBOutlet private weak var certificationLabel: UILabel!

  var diskType: DiskType? {
    didSet {
      self.loadViewIfNeeded()
      if let diskType = self.diskType {
        diskLabel.text = diskType.localizedName
      } else {
        diskLabel.text = "[MISSING]"
      }
    }
  }
  @IBOutlet private weak var diskLabel: UILabel!

  var overview: RemoteProperty<String> = .loading {
    didSet {
      self.loadViewIfNeeded()
      switch overview {
        case .loading:
          self.overviewTextView.text = NSLocalizedString("loading", comment: "")
        case .unavailable:
          self.overviewTextView.text = NSLocalizedString("details.missing.overview", comment: "")
        case let .available(overview):
          self.overviewTextView.text = overview
      }
    }
  }
  @IBOutlet private weak var overviewTextView: UITextView!
}

// MARK: - View Controller Lifecycle

extension ItemDetailsController {
  override func viewDidLoad() {
    super.viewDidLoad()
    posterView.layer.borderColor = UIColor.posterBorder.cgColor
    posterView.layer.borderWidth = 0.5

    reassign(property: \ItemDetailsController.itemTitle)
    reassign(property: \ItemDetailsController.subtitle)
    reassign(property: \ItemDetailsController.poster)
    reassign(property: \ItemDetailsController.genreIds)
    reassign(property: \ItemDetailsController.runtime)
    reassign(property: \ItemDetailsController.releaseDate)
    reassign(property: \ItemDetailsController.certification)
    reassign(property: \ItemDetailsController.diskType)
    reassign(property: \ItemDetailsController.overview)
  }

  private func reassign<Type>(property: ReferenceWritableKeyPath<ItemDetailsController, Type>) {
    let value = self[keyPath: property]
    self[keyPath: property] = value
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    if isMovingFromParentViewController {
      self.delegate?.itemDetailsControllerDidDismiss(self)
    }
  }
}
