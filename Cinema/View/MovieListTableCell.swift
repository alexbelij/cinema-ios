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

  func configure(for item: MovieListItem, posterProvider: PosterProvider) {
    titleLabel!.text = item.movie.fullTitle
    runtimeLabel!.text = item.movie.runtime == nil
        ? NSLocalizedString("details.missing.runtime", comment: "")
        : Utils.formatDuration(item.movie.runtime!)
    configurePoster(for: item, posterProvider: posterProvider)
  }

  private func configurePoster(for item: MovieListItem, posterProvider: PosterProvider) {
    switch item.image {
      case .unknown:
        posterView.image = .genericPosterImage(minWidth: posterView.frame.size.width)
        var workItem: DispatchWorkItem?
        workItem = DispatchWorkItem {
          let poster = posterProvider.poster(for: item.movie.id, size: PosterSize(minWidth: 46))
          DispatchQueue.main.async {
            if let posterImage = poster {
              item.image = .available(posterImage)
            } else {
              item.image = .unavailable
            }
            if !workItem!.isCancelled {
              self.configurePoster(for: item, posterProvider: posterProvider)
            }
          }
        }
        self.workItem = workItem
        DispatchQueue.global(qos: .userInteractive).async(execute: workItem!)
      case let .available(posterImage):
        posterView.image = posterImage
      case .unavailable:
        posterView.image = .genericPosterImage(minWidth: posterView.frame.size.width)
    }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    self.workItem?.cancel()
    self.workItem = nil
  }
}
