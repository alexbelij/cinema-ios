import UIKit
import Dispatch

class AddItemViewController: UIViewController {

  private var library: MediaLibrary!
  private var movieDb: MovieDbClient!
  private var itemToAdd: PartialMediaItem!
  private var diskType: DiskType!

  @IBOutlet weak var posterView: UIImageView!
  @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
  @IBOutlet weak var label: UILabel!
  @IBOutlet weak var messageLabel: UILabel!

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
    posterView.layer.borderColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.2).cgColor
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
                           runtime: self.movieDb.runtime(for: self.itemToAdd.id) ?? -1,
                           year: self.itemToAdd.year ?? -1,
                           diskType: self.diskType)
      let success: Bool
      do {
        try self.library.add(item)
        success = true
      } catch {
        success = false
      }
      DispatchQueue.main.async {
        self.activityIndicator.stopAnimating()
        if success {
          self.label.text = NSLocalizedString("addItem.done.success.text", comment: "")
          self.messageLabel.text = String(format: NSLocalizedString("addItem.done.success.messageFormat", comment: ""),
                                          item.title)
        } else {
          self.label.text = NSLocalizedString("addItem.done.success.text", comment: "")
          self.messageLabel.text = String(format: NSLocalizedString("addItem.done.failure.messageFormat", comment: ""),
                                          item.title)
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
