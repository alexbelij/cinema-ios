import CinemaKit
import UIKit

class MovieListListItemTableCell: UITableViewCell {
  static let rowHeight: CGFloat = 100
  static let posterSize = PosterSize(minWidth: 60)
  private static let separatorInsetsWithSectionIndex = UIEdgeInsets(top: 0, left: 90, bottom: 0, right: 16)
  private static let separatorInsetsWithoutSectionIndex = UIEdgeInsets(top: 0, left: 90, bottom: 0, right: 0)
  private static let runtimeFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .full
    formatter.allowedUnits = [.hour, .minute]
    formatter.zeroFormattingBehavior = [.dropAll]
    return formatter
  }()

  @IBOutlet private var posterView: UIImageView!
  @IBOutlet private var titleLabel: UILabel!
  @IBOutlet private var secondaryLabel: UILabel!
  @IBOutlet private var tertiaryLabel: UILabel!

  override func awakeFromNib() {
    super.awakeFromNib()
    posterView.layer.borderColor = UIColor.posterBorder.cgColor
    posterView.layer.borderWidth = 0.5
  }

  func configure(for item: MovieListController.ListItem,
                 posterProvider: PosterProvider,
                 isSectionIndexVisible: Bool,
                 onNeedsReload: @escaping () -> Void) {
    titleLabel.text = item.movie.fullTitle
    if let seconds = item.movie.runtime?.converted(to: UnitDuration.seconds).value {
      secondaryLabel.text = MovieListListItemTableCell.runtimeFormatter.string(from: seconds)!
    } else {
      secondaryLabel.text = NSLocalizedString("details.missing.runtime", comment: "")
    }
    tertiaryLabel.text = item.movie.diskType.localizedName
    switch item.poster {
      case .unknown:
        item.poster = .loading
        configurePoster(nil)
        DispatchQueue.global(qos: .userInteractive).async {
          fetchPoster(for: item,
                      using: posterProvider,
                      size: MovieListListItemTableCell.posterSize,
                      purpose: .list,
                      then: onNeedsReload)
        }
      case .loading:
        configurePoster(nil)
      case let .available(posterImage):
        configurePoster(posterImage)
      case .unavailable:
        configurePoster(#imageLiteral(resourceName: "GenericPoster"))
    }
    separatorInset = isSectionIndexVisible
        ? MovieListListItemTableCell.separatorInsetsWithSectionIndex
        : MovieListListItemTableCell.separatorInsetsWithoutSectionIndex
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
}
