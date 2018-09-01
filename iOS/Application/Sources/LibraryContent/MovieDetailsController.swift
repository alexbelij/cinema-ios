import CinemaKit
import UIKit

protocol MovieDetailsControllerDelegate: class {
  func movieDetailsControllerDidDismiss(_ controller: MovieDetailsController)
}

class MovieDetailsController: UIViewController {
  enum RemoteProperty<Type> {
    case loading
    case available(Type)
    case unavailable
  }

  weak var delegate: MovieDetailsControllerDelegate?

  var movieTitle: String = "" {
    didSet {
      self.loadViewIfNeeded()
      self.titleLabel.text = movieTitle
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
        runtimeLabel.text = MovieDetailsController.runtimeFormatter.string(from: seconds)!
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
        releaseDateLabel.text = MovieDetailsController.releaseDateFormatter.string(from: releaseDate)
        releaseDateStackView.isHidden = false
      } else {
        releaseDateStackView.isHidden = true
      }
    }
  }
  @IBOutlet private weak var releaseDateLabel: UILabel!
  @IBOutlet private weak var releaseDateStackView: UIStackView!

  var certification: String? {
    didSet {
      self.loadViewIfNeeded()
      if let text = certification {
        self.certificationLabel.text = text
        self.certificationStackView.isHidden = false
      } else {
        self.certificationStackView.isHidden = true
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

  var overview: String? {
    didSet {
      self.loadViewIfNeeded()
      if let text = overview?.nilIfEmptyString {
        self.overviewLabel.text = text
      } else {
        self.overviewLabel.text = NSLocalizedString("details.missing.overview", comment: "")
      }
    }
  }
  @IBOutlet private weak var overviewLabel: UILabel!
}

// MARK: - View Controller Lifecycle

extension MovieDetailsController {
  override func viewDidLoad() {
    super.viewDidLoad()
    posterView.layer.borderColor = UIColor.posterBorder.cgColor
    posterView.layer.borderWidth = 0.5
    storyLineLabel.text = NSLocalizedString("details.storyline", comment: "")

    reassign(property: \MovieDetailsController.movieTitle)
    reassign(property: \MovieDetailsController.poster)
    reassign(property: \MovieDetailsController.genreIds)
    reassign(property: \MovieDetailsController.runtime)
    reassign(property: \MovieDetailsController.releaseDate)
    reassign(property: \MovieDetailsController.certification)
    reassign(property: \MovieDetailsController.diskType)
    reassign(property: \MovieDetailsController.overview)
  }

  private func reassign<Type>(property: ReferenceWritableKeyPath<MovieDetailsController, Type>) {
    let value = self[keyPath: property]
    self[keyPath: property] = value
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    if isMovingFromParent {
      self.delegate?.movieDetailsControllerDidDismiss(self)
    }
  }
}
