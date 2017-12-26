import Dispatch
import UIKit

class MovieListTableCell: UITableViewCell {
  @IBOutlet private weak var posterView: UIImageView!
  @IBOutlet private weak var titleLabel: UILabel!
  @IBOutlet private weak var runtimeLabel: UILabel!
  private var workItem: DispatchWorkItem?

  override func awakeFromNib() {
    super.awakeFromNib()
    posterView.layer.borderColor = UIColor.posterBorder.cgColor
    posterView.layer.borderWidth = 0.5
  }

  func configure(for item: MediaItem, posterFetching: PosterProvider) {
    titleLabel!.text = item.fullTitle
    runtimeLabel!.text = item.runtime == nil
        ? NSLocalizedString("details.missing.runtime", comment: "")
        : Utils.formatDuration(item.runtime!)
    posterView.image = .genericPosterImage(minWidth: posterView.frame.size.width)
    var workItem: DispatchWorkItem?
    workItem = DispatchWorkItem {
      guard !workItem!.isCancelled else { return }
      if let poster = posterFetching.poster(for: item.id, size: PosterSize(minWidth: 46)) {
        DispatchQueue.main.async {
          self.posterView.image = poster
        }
      }
    }
    self.workItem = workItem
    DispatchQueue.global(qos: .userInteractive).async(execute: workItem!)
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    self.workItem?.cancel()
    self.workItem = nil
  }
}
