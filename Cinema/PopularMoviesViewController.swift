import UIKit
import Dispatch

class PopularMoviesViewController: UICollectionViewController {

  var library: MediaLibrary!
  var movieDb: MovieDbClient!
  var items = [PartialMediaItem]()

  private let cellPosterSize = PosterSize.init(minWidth: 130)
  private var movieIterator: AnyIterator<PartialMediaItem>!

  override func viewDidLoad() {
    super.viewDidLoad()
    self.movieIterator = AnyIterator(self.movieDb.popularMovies().lazy.filter(isNotInLibrary).makeIterator())
    fetchItems(count: 10)
  }

  private func isNotInLibrary(_ item: PartialMediaItem) -> Bool {
    return library.mediaItems { $0.id == item.id }.isEmpty
  }

  private func fetchItems(count: Int) {
    DispatchQueue.global(qos: .userInitiated).async {
      for _ in 0..<count {
        guard let item = self.movieIterator.next() else { break }
        DispatchQueue.main.sync {
          self.items.append(item)
          self.collectionView?.insertItems(at: [IndexPath(row: self.items.count - 1, section: 0)])
        }
      }
    }
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

}

// MARK: - Header Views & Cells

class TitleHeaderView: UICollectionReusableView {
  @IBOutlet weak var label: UILabel!
}

class PosterCell: UICollectionViewCell {

  @IBOutlet weak var posterImageView: UIImageView!
  @IBOutlet weak var titleLabel: UILabel!

  override func awakeFromNib() {
    super.awakeFromNib()
    posterImageView.layer.borderColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.2).cgColor
    posterImageView.layer.borderWidth = 0.5
  }
}
