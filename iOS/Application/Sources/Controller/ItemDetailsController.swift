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

  var poster: RemoteProperty<UIImage> = .loading {
    didSet {
      self.loadViewIfNeeded()
      switch poster {
        case .loading, .unavailable:
          self.posterView.image = #imageLiteral(resourceName: "GenericPoster")
        case let .available(image):
          self.posterView.image = image
      }
    }
  }
  @IBOutlet private weak var posterView: UIImageView!

  var genreIds = [GenreIdentifier]() {
    didSet {
      self.loadViewIfNeeded()
      let names = self.genreIds.compactMap(L10n.genreName).prefix(4)
      if names.isEmpty {
        self.genreStackView.isHidden = true
      } else {
        self.genreLabel.text = names.joined(separator: ", ")
        self.genreStackView.isHidden = false
      }
    }
  }
  @IBOutlet private weak var genreLabel: UILabel!
  @IBOutlet private weak var genreStackView: UIStackView!

  private static let runtimeFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.allowedUnits = [.hour, .minute]
    formatter.zeroFormattingBehavior = [.dropAll]
    return formatter
  }()

  var runtime: Measurement<UnitDuration>? {
    didSet {
      self.loadViewIfNeeded()
      if let seconds = self.runtime?.converted(to: UnitDuration.seconds).value {
        runtimeLabel.text = ItemDetailsController.runtimeFormatter.string(from: seconds)!
        runtimeStackView.isHidden = false
      } else {
        runtimeStackView.isHidden = true
      }
    }
  }
  @IBOutlet private weak var runtimeLabel: UILabel!
  @IBOutlet private weak var runtimeStackView: UIStackView!

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
        releaseDateStackView.isHidden = false
      } else {
        releaseDateStackView.isHidden = true
      }
    }
  }
  @IBOutlet private weak var releaseDateLabel: UILabel!
  @IBOutlet private weak var releaseDateStackView: UIStackView!

  var certification: RemoteProperty<String> = .loading {
    didSet {
      self.loadViewIfNeeded()
      self.certificationStackView.isHidden = true
      switch certification {
        case .loading, .unavailable: break
        case let .available(certification):
          self.certificationLabel.text = certification
          self.certificationStackView.isHidden = false
      }
    }
  }
  @IBOutlet private weak var certificationLabel: UILabel!
  @IBOutlet private weak var certificationStackView: UIStackView!

  var diskType: DiskType? {
    didSet {
      self.loadViewIfNeeded()
      guard let diskType = self.diskType else { return }
      diskLabel.text = diskType.localizedName
    }
  }
  @IBOutlet private weak var diskLabel: UILabel!

  @IBOutlet private weak var storyLineLabel: UILabel!

  var overview: RemoteProperty<String> = .loading {
    didSet {
      self.loadViewIfNeeded()
      switch overview {
        case .loading:
          self.overviewLabel.text = NSLocalizedString("loading", comment: "")
        case .unavailable:
          self.overviewLabel.text = NSLocalizedString("details.missing.overview", comment: "")
        case let .available(overview):
          self.overviewLabel.text = overview
      }
    }
  }
  @IBOutlet private weak var overviewLabel: UILabel!
}

// MARK: - View Controller Lifecycle

extension ItemDetailsController {
  override func viewDidLoad() {
    super.viewDidLoad()
    posterView.layer.borderColor = UIColor.posterBorder.cgColor
    posterView.layer.borderWidth = 0.5
    storyLineLabel.text = NSLocalizedString("details.storyline", comment: "")

    reassign(property: \ItemDetailsController.itemTitle)
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