import CinemaKit
import UIKit

class SearchTmdbSearchResultTableCell: UITableViewCell {
  static let rowHeight: CGFloat = 100
  static let posterSize = PosterSize(minWidth: 60)
  @IBOutlet private var posterView: UIImageView!
  @IBOutlet private var titleLabel: UILabel!
  @IBOutlet private var yearLabel: UILabel!
  private lazy var activityIndicator = UIActivityIndicatorView(style: .gray)

  override func awakeFromNib() {
    super.awakeFromNib()
    posterView.layer.borderColor = UIColor.posterBorder.cgColor
    posterView.layer.borderWidth = 0.5
  }

  func configure(for model: ExternalMovieViewModel,
                 posterProvider: PosterProvider,
                 onNeedsReload: @escaping () -> Void) {
    titleLabel.text = model.movie.title
    if let year = model.movie.releaseYear {
      yearLabel.text = String(year)
    }
    switch model.state {
      case .new:
        accessoryType = .none
        selectionStyle = .default
      case .updateInProgress:
        accessoryView = activityIndicator
        activityIndicator.startAnimating()
        selectionStyle = .none
      case .addedToLibrary:
        accessoryType = .checkmark
        selectionStyle = .none
    }
    switch model.poster {
      case .unknown:
        model.poster = .loading
        configurePoster(nil)
        DispatchQueue.global(qos: .userInteractive).async {
          fetchPoster(for: model,
                      using: posterProvider,
                      size: SearchTmdbSearchResultTableCell.posterSize,
                      purpose: .searchResult,
                      then: onNeedsReload)
        }
      case .loading:
        configurePoster(nil)
      case let .available(posterImage):
        configurePoster(posterImage)
      case .unavailable:
        configurePoster(#imageLiteral(resourceName: "GenericPoster"))
    }
  }

  private func configurePoster(_ image: UIImage?) {
    posterView.image = image
    if image == nil {
      posterView.alpha = 0.0
    } else if posterView.alpha < 1.0 {
      UIView.animate(withDuration: 0.2) {
        self.posterView.alpha = 1.0
      }
    }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    activityIndicator.stopAnimating()
  }
}
