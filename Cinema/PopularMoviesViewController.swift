import UIKit
import Dispatch

class PopularMoviesViewController: UICollectionViewController {

  var library: MediaLibrary!
  var movieDb: MovieDbClient!
  var items = [PartialMediaItem]()
  weak var selectionDelegate: SearchResultsSelectionDelegate?

  private let cellPosterSize = PosterSize.init(minWidth: 130)
  private var movieIterator: AnyIterator<PartialMediaItem>!
  private var isFetchingItems = false

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

    self.movieIterator = AnyIterator(self.movieDb.popularMovies().lazy.filter(isNotInLibrary).makeIterator())
    fetchItems(count: 10)
  }

  private func isNotInLibrary(_ item: PartialMediaItem) -> Bool {
    return library.mediaItems { $0.id == item.id }.isEmpty
  }

  private func fetchItems(count: Int) {
    isFetchingItems = true
    if let footerView = self.collectionView!.supplementaryView(forElementKind: UICollectionElementKindSectionFooter,
                                                               at: IndexPath(row: 0,
                                                                             section: 0)) as? TmdbFooterView {
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
        }
      }
    }
  }

  func removeItem(_ item: PartialMediaItem) {
    guard let index = items.index(of: item) else { fatalError("can not remove unknown item \(item)") }
    self.items.remove(at: index)
    collectionView!.deleteItems(at: [IndexPath(row: index, section: 0)])
    fetchItems(count: 1)
  }

  // MARK: UICollectionViewDataSource

  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return items.count
  }

  override func collectionView(_ collectionView: UICollectionView,
                               cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    // swiftlint:disable:next force_cast
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PosterCell", for: indexPath) as! PosterCell

    let item = items[indexPath.row]
    cell.titleLabel.text = item.title
    cell.posterImageView.image = .genericPosterImage(minWidth: cell.posterImageView.frame.size.width)

    DispatchQueue.global(qos: .userInteractive).async {
      let poster = self.movieDb.poster(for: item.id, size: self.cellPosterSize)
      DispatchQueue.main.sync {
        cell.posterImageView.image = poster
      }
    }

    return cell
  }

  // MARK: UICollectionViewDelegate

  override func collectionView(_ collectionView: UICollectionView,
                               viewForSupplementaryElementOfKind kind: String,
                               at indexPath: IndexPath) -> UICollectionReusableView {
    switch kind {
      case UICollectionElementKindSectionHeader:
        let reusableView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                           withReuseIdentifier: "TitleHeaderView",
                                                                           // swiftlint:disable:next force_cast
                                                                           for: indexPath) as! TitleHeaderView
        reusableView.label.text = NSLocalizedString("popularMovies", comment: "")
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

  override func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
    guard let cell = collectionView.cellForItem(at: indexPath) as? PosterCell else { return }
    cell.highlightView.alpha = 0.3
  }

  override func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
    guard let cell = collectionView.cellForItem(at: indexPath) as? PosterCell else { return }
    cell.highlightView.alpha = 0
  }

  override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    self.selectionDelegate?.didSelectSearchResult(items[indexPath.row])
  }

}

// MARK: - Header Views, Footer Views & Cells

class TitleHeaderView: UICollectionReusableView {
  @IBOutlet weak var label: UILabel!
}

class PosterCell: UICollectionViewCell {

  @IBOutlet weak var posterImageView: UIImageView!
  @IBOutlet weak var titleLabel: UILabel!
  var highlightView: UIView!

  override func awakeFromNib() {
    super.awakeFromNib()
    posterImageView.layer.borderColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.2).cgColor
    posterImageView.layer.borderWidth = 0.5
    let posterFrame = posterImageView.frame
    self.highlightView = UIView(frame: CGRect(x: 0,
                                              y: 0,
                                              width: posterFrame.size.width,
                                              height: posterFrame.size.height))
    self.highlightView.backgroundColor = .black
    self.highlightView.alpha = 0
    self.contentView.addSubview(highlightView)
  }
}

class TmdbFooterView: UICollectionReusableView {
  @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
}
