import Dispatch
import UIKit

class DetailViewController: UIViewController {

  var detailItem: MediaItem? {
    didSet {
      configureView()
    }
  }

  @IBOutlet private weak var titleLabel: UILabel!
  @IBOutlet private weak var subtitleLabel: UILabel!
  @IBOutlet private weak var imageView: UIImageView!
  @IBOutlet private weak var genreLabel: UILabel!
  @IBOutlet private weak var runtimeLabel: UILabel!
  @IBOutlet private weak var releaseDateLabel: UILabel!
  @IBOutlet private weak var certificationLabel: UILabel!
  @IBOutlet private weak var diskLabel: UILabel!
  @IBOutlet private weak var textView: UITextView!

  var movieDb: MovieDbClient!
  var library: MediaLibrary!

  private var popAfterDidAppear = false

  func configureView() {
    guard isViewLoaded else { return }
    if let mediaItem = detailItem {
      titleLabel.text = mediaItem.title
      if let subtitle = mediaItem.subtitle {
        subtitleLabel.isHidden = false
        subtitleLabel.text = subtitle
      } else {
        subtitleLabel.isHidden = true
      }
      runtimeLabel.text = mediaItem.runtime == nil
          ? NSLocalizedString("details.missing.runtime", comment: "")
          : Utils.formatDuration(mediaItem.runtime!)
      let dateFormatter = DateFormatter()
      dateFormatter.dateStyle = .long
      dateFormatter.timeStyle = .none
      releaseDateLabel.text = mediaItem.releaseDate == nil
          ? NSLocalizedString("details.missing.releaseDate", comment: "")
          : dateFormatter.string(from: mediaItem.releaseDate!)
      diskLabel.text = localize(diskType: mediaItem.diskType)
      var genreString = Utils.localizedGenreNames(for: self.detailItem!.genreIds)
                             .joined(separator: ", ")
      if genreString.isEmpty {
        genreString = NSLocalizedString("details.missing.genre", comment: "")
      }
      self.genreLabel.text = genreString

      if movieDb.isConnected {
        fetchAdditionalData()
      }
    }
  }

  private func fetchAdditionalData() {
    let queue = DispatchQueue.global(qos: .userInitiated)
    let group = DispatchGroup()
    group.enter()
    queue.async {
      if let poster = self.movieDb.poster(for: self.detailItem!.id, size: PosterSize(minWidth: 92)) {
        DispatchQueue.main.async {
          self.imageView.image = poster
          group.leave()
        }
      } else {
        group.leave()
      }
    }
    group.enter()
    queue.async {
      let text: String
      if let overview = self.movieDb.overview(for: self.detailItem!.id), !overview.isEmpty {
        text = overview
      } else {
        text = NSLocalizedString("details.missing.overview", comment: "")
      }
      DispatchQueue.main.async {
        self.textView.text = text
        group.leave()
      }
    }
    group.enter()
    queue.async {
      let text: String
      if let certification = self.movieDb.certification(for: self.detailItem!.id), !certification.isEmpty {
        text = certification
      } else {
        text = NSLocalizedString("details.missing.certification", comment: "")
      }
      DispatchQueue.main.async {
        self.certificationLabel.text = text
        group.leave()
      }
    }
    group.notify(queue: .main) {
      UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
  }

  private func localize(diskType: DiskType) -> String {
    switch diskType {
      case .dvd: return NSLocalizedString("mediaItem.disk.dvd", comment: "")
      case .bluRay: return NSLocalizedString("mediaItem.disk.bluRay", comment: "")
    }
  }

  override func viewDidLoad() {
    UIApplication.shared.isNetworkActivityIndicatorVisible = true
    imageView.image = .genericPosterImage(minWidth: imageView.frame.size.width)
    imageView.layer.borderColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.2).cgColor
    imageView.layer.borderWidth = 0.5
    genreLabel?.text = ""
    runtimeLabel?.text = ""
    releaseDateLabel?.text = ""
    certificationLabel?.text = ""
    diskLabel?.text = ""
    textView?.text = ""
    configureView()
    super.viewDidLoad()
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(reloadDetailItem),
                                           name: .didChangeMediaLibraryContent,
                                           object: nil)
  }

  @objc
  private func reloadDetailItem() {
    DispatchQueue.main.async {
      let items = self.library.mediaItems { $0.id == self.detailItem!.id }
      if let updatedItem = items.first {
        self.detailItem = updatedItem
      } else {
        // item was deleted
        self.popAfterDidAppear = true
      }
    }
  }

  open override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if popAfterDidAppear {
      self.navigationController!.popViewController(animated: true)
      popAfterDidAppear = false
    }
  }

  open override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    switch segue.unwrappedDestination {
      case let editVC as EditItemTableViewController:
        editVC.item = detailItem
        editVC.library = library
      default: fatalError("Unexpected segue: '\(self)' -> '\(segue.destination)'")
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}
