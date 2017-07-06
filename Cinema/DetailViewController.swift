import Dispatch
import UIKit

class DetailViewController: UIViewController {

  var detailItem: MediaItem? {
    didSet {
      configureView()
    }
  }

  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var subtitleLabel: UILabel!
  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet weak var genreLabel: UILabel!
  @IBOutlet weak var runtimeLabel: UILabel!
  @IBOutlet weak var yearLabel: UILabel!
  @IBOutlet weak var certificationLabel: UILabel!
  @IBOutlet weak var diskLabel: UILabel!
  @IBOutlet weak var textView: UITextView!

  var movieDb: MovieDbClient!
  var library: MediaLibrary!

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
      runtimeLabel.text = mediaItem.runtime == -1
          ? NSLocalizedString("details.missing.runtime", comment: "")
          : Utils.formatDuration(mediaItem.runtime)
      yearLabel.text = "\(mediaItem.year)"
      diskLabel.text = localize(diskType: mediaItem.diskType)

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
      if let overview  = self.movieDb.overview(for: self.detailItem!.id), !overview.isEmpty {
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
      var genreString = self.movieDb.genres(for: self.detailItem!.id).reduce("") { (result, next) in
        if result.isEmpty {
          return next
        } else {
          return "\(result), \(next)"
        }
      }
      if genreString.isEmpty {
        genreString = NSLocalizedString("details.missing.genre", comment: "")
      }
      DispatchQueue.main.async {
        self.genreLabel.text = genreString
        group.leave()
      }
    }
    group.enter()
    queue.async {
      let text: String
      if let certification = self.movieDb.certification(for: self.detailItem!.id), !certification.isEmpty {
        let format = NSLocalizedString("details.certificationFormat", comment: "")
        text = String(format: format, certification)
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
    imageView.layer.borderColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.2).cgColor
    imageView.layer.borderWidth = 0.5
    genreLabel?.text = ""
    runtimeLabel?.text = ""
    yearLabel?.text = ""
    certificationLabel?.text = ""
    diskLabel?.text = ""
    textView?.text = ""
    configureView()
    super.viewDidLoad()
  }

  open override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if let navigationController = segue.destination as? UINavigationController,
       let editController = (navigationController).childViewControllers.last! as? EditItemTableViewController {
      editController.item = detailItem
      editController.library = library
    }
  }
}
