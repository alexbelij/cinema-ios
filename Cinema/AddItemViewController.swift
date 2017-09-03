import Dispatch
import UIKit

class AddItemViewController: UIViewController {

  private var library: MediaLibrary!
  private var movieDb: MovieDbClient!
  private var itemToAdd: PartialMediaItem!
  private var diskType: DiskType!

  @IBOutlet private weak var posterView: UIImageView!
  @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
  @IBOutlet private weak var label: UILabel!
  @IBOutlet private weak var messageLabel: UILabel!

  private var posterFetchWorkItem: DispatchWorkItem?

  func add(item: PartialMediaItem, as diskType: DiskType, to library: MediaLibrary, movieDb: MovieDbClient) {
    self.itemToAdd = item
    self.diskType = diskType
    self.library = library
    self.movieDb = movieDb
  }

  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    label.text = NSLocalizedString("addItem.progress.text", comment: "")
    posterView.image = .genericPosterImage(minWidth: posterView.frame.size.width)
    posterView.layer.borderColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.2).cgColor
    posterView.layer.borderWidth = 0.5
    posterFetchWorkItem = DispatchWorkItem {
      if let poster = self.movieDb.poster(for: self.itemToAdd.id, size: PosterSize(minWidth: 185)) {
        DispatchQueue.main.async {
          self.posterView.image = poster
        }
      }
      self.posterFetchWorkItem = nil
    }
    DispatchQueue.global(qos: .userInitiated).async(execute: posterFetchWorkItem!)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    activityIndicator.startAnimating()
    DispatchQueue.global(qos: .userInitiated).async {
      let item = MediaItem(id: self.itemToAdd.id,
                           title: self.itemToAdd.title,
                           runtime: self.movieDb.runtime(for: self.itemToAdd.id),
                           releaseDate: self.itemToAdd.releaseDate,
                           diskType: self.diskType,
                           genreIds: self.movieDb.genreIds(for: self.itemToAdd.id))
      var libraryError: Error? = nil
      do {
        try self.library.add(item)
      } catch {
        libraryError = error
      }
      DispatchQueue.main.async {
        self.activityIndicator.stopAnimating()
        if libraryError == nil {
          self.label.text = NSLocalizedString("addItem.done.success.text", comment: "")
          self.messageLabel.text = String(format: NSLocalizedString("addItem.done.success.messageFormat", comment: ""),
                                          item.title)
        } else {
          self.label.text = NSLocalizedString("addItem.done.failure.text", comment: "")
          self.messageLabel.text = Utils.localizedErrorMessage(for: libraryError!)
        }
        self.messageLabel.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
          self.posterFetchWorkItem?.cancel()
          self.dismiss(animated: true)
        }
      }
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    activityIndicator.stopAnimating()
  }
}
