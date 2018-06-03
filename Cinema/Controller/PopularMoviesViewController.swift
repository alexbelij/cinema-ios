import Dispatch
import UIKit

protocol PopularMoviesControllerDelegate: class {
  func popularMoviesController(_ controller: PopularMoviesController, didSelect movie: PartialMediaItem)
}

class PopularMoviesController: UICollectionViewController {
  weak var delegate: PopularMoviesControllerDelegate?
  var movieIterator: AnyIterator<PartialMediaItem> = AnyIterator(EmptyIterator())
  var maxMovieCount: Int = 10
  var posterProvider: PosterProvider = EmptyPosterProvider()
  private var items = [PartialMediaItem]()
  private let cellPosterSize = PosterSize(minWidth: 130)
  private var isFetchingItems = false
  private let emptyView = GenericEmptyView(accessory: .image(#imageLiteral(resourceName: "EmptyLibrary")),
                                           description: .basic(NSLocalizedString("popularMovies.empty", comment: "")))
}

// MARK: - View Controller Lifecycle

extension PopularMoviesController {
  override func viewDidLoad() {
    super.viewDidLoad()
    guard let flowLayout = self.collectionView?.collectionViewLayout as? UICollectionViewFlowLayout else {
      fatalError("unexpected collection view layout")
    }
    let totalCellWidth = flowLayout.itemSize.width * 2
    let contentWidth = collectionView!.frame.size.width
                       - collectionView!.contentInset.left - collectionView!.contentInset.right
    let spacing = (contentWidth - totalCellWidth) / 3.5
    flowLayout.minimumInteritemSpacing = spacing
    flowLayout.sectionInset = UIEdgeInsets(top: 10, left: spacing, bottom: 10, right: spacing)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if items.count < maxMovieCount {
      fetchItems(count: maxMovieCount - items.count)
    }
  }
}

// MARK: - UICollectionViewDataSource

extension PopularMoviesController {
  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return items.count
  }

  override func collectionView(_ collectionView: UICollectionView,
                               cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    // swiftlint:disable:next force_cast
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PosterCell", for: indexPath) as! PosterCell
    cell.configure(for: items[indexPath.row], posterProvider: posterProvider)
    return cell
  }
}

// MARK: - UICollectionViewDelegate

extension PopularMoviesController {
  override func collectionView(_ collectionView: UICollectionView,
                               viewForSupplementaryElementOfKind kind: String,
                               at indexPath: IndexPath) -> UICollectionReusableView {
    switch kind {
      case UICollectionElementKindSectionHeader:
        let reusableView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                           withReuseIdentifier: "TitleHeaderView",
                                                                           // swiftlint:disable:next force_cast
                                                                           for: indexPath) as! TitleHeaderView
        reusableView.configure(title: NSLocalizedString("popularMovies", comment: ""))
        return reusableView
      case UICollectionElementKindSectionFooter:
        return collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                               withReuseIdentifier: "TmdbFooterView",
                                                               for: indexPath)
      default:
        fatalError("Unexpected kind \(kind)")
    }
  }

  override func collectionView(_ collectionView: UICollectionView,
                               willDisplaySupplementaryView view: UICollectionReusableView,
                               forElementKind elementKind: String,
                               at indexPath: IndexPath) {
    guard elementKind == UICollectionElementKindSectionFooter,
          let footerView = view as? TmdbFooterView else { return }
    if isFetchingItems {
      footerView.activityIndicator.startAnimating()
    }
  }

  override func collectionView(_ collectionView: UICollectionView,
                               didEndDisplayingSupplementaryView view: UICollectionReusableView,
                               forElementOfKind elementKind: String,
                               at indexPath: IndexPath) {
    guard elementKind == UICollectionElementKindSectionFooter,
          let footerView = view as? TmdbFooterView else { return }
    footerView.activityIndicator.stopAnimating()
  }

  override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    self.delegate?.popularMoviesController(self, didSelect: items[indexPath.row])
  }
}

// MARK: - Data Management

extension PopularMoviesController {
  private func fetchItems(count: Int) {
    guard !isFetchingItems else { return }
    isFetchingItems = true
    if let footerView = self.collectionView!.supplementaryView(forElementKind: UICollectionElementKindSectionFooter,
                                                               at: IndexPath(row: 0, section: 0)) as? TmdbFooterView {
      footerView.activityIndicator.startAnimating()
    }
    DispatchQueue.global(qos: .userInitiated).async {
      for _ in 0..<count {
        guard let item = self.movieIterator.next() else { break }
        DispatchQueue.main.sync {
          self.items.append(item)
          self.collectionView?.insertItems(at: [IndexPath(row: self.items.count - 1, section: 0)])
        }
      }
      DispatchQueue.main.sync {
        self.isFetchingItems = false
        if let footerView = self.collectionView!.supplementaryView(forElementKind: UICollectionElementKindSectionFooter,
                                                                   at: IndexPath(row: 0,
                                                                                 section: 0)) as? TmdbFooterView {
          footerView.activityIndicator.stopAnimating()
          DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
            if self.items.isEmpty {
              self.collectionView!.backgroundView = self.emptyView
              footerView.imageView.isHidden = true
            } else {
              footerView.imageView.isHidden = false
            }
          }
        }
      }
    }
  }
}

// MARK: - Actions

extension PopularMoviesController {
  func removeItem(_ item: PartialMediaItem) {
    guard let index = items.index(of: item) else { return }
    self.items.remove(at: index)
    collectionView!.deleteItems(at: [IndexPath(row: index, section: 0)])
    fetchItems(count: 1)
  }
}

// MARK: - Header Views, Footer Views & Cells

class TitleHeaderView: UICollectionReusableView {
  @IBOutlet private weak var label: UILabel!

  func configure(title: String) {
    label.text = title
  }
}

class PosterCell: UICollectionViewCell {

  @IBOutlet fileprivate weak var posterImageView: UIImageView!
  @IBOutlet private weak var titleLabel: UILabel!
  private var highlightView: UIView!
  private var workItem: DispatchWorkItem?

  override func awakeFromNib() {
    super.awakeFromNib()
    posterImageView.layer.shadowColor = UIColor.black.cgColor
    posterImageView.layer.shadowRadius = 2
    posterImageView.layer.shadowOpacity = 0.5
    posterImageView.layer.shadowOffset = CGSize(width: 0.0, height: 1.0)
    self.highlightView = UIView(frame: posterImageView.frame)
    self.highlightView.backgroundColor = .black
    self.highlightView.alpha = 0
    self.contentView.addSubview(highlightView)
  }

  func configure(for item: PartialMediaItem, posterProvider: PosterProvider) {
    titleLabel.text = item.title
    posterImageView.image = .genericPosterImage(minWidth: posterImageView.frame.size.width)
    var workItem: DispatchWorkItem?
    workItem = DispatchWorkItem {
      if let poster = posterProvider.poster(for: item.tmdbID, size: PosterSize(minWidth: 130)) {
        DispatchQueue.main.async {
          guard !workItem!.isCancelled else { return }
          self.posterImageView.image = poster
        }
      }
    }
    self.workItem = workItem
    DispatchQueue.global(qos: .userInteractive).async(execute: workItem!)
  }

  override var isHighlighted: Bool {
    didSet {
      if isHighlighted {
        highlightView.alpha = 0.3
      } else {
        highlightView.alpha = 0.0
      }
    }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    self.workItem?.cancel()
    self.workItem = nil
  }
}

class TmdbFooterView: UICollectionReusableView {
  @IBOutlet fileprivate weak var activityIndicator: UIActivityIndicatorView!
  @IBOutlet fileprivate weak var imageView: UIImageView!
}
