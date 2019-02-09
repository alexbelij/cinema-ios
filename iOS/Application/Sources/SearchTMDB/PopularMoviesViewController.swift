import CinemaKit
import Dispatch
import UIKit

protocol PopularMoviesControllerDelegate: class {
  func popularMoviesController(_ controller: PopularMoviesController, didSelect model: ExternalMovieViewModel)
}

class PopularMoviesController: UICollectionViewController {
  weak var delegate: PopularMoviesControllerDelegate?
  var movieIterator: AnyIterator<PartialMovie> = AnyIterator(EmptyIterator()) {
    didSet {
      guard isViewLoaded else { return }
      if !movies.isEmpty {
        movies = []
        collectionView!.reloadData()
        fetchMovies(count: maxMovieCount)
      }
    }
  }
  var maxMovieCount: Int = 10
  var posterProvider: PosterProvider = EmptyPosterProvider()
  private var movies = [ExternalMovieViewModel]()
  private let cellPosterSize = PosterSize(minWidth: 130)
  private var isFetchingMovies = false
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
    collectionView!.prefetchDataSource = self
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if movies.count < maxMovieCount {
      fetchMovies(count: maxMovieCount - movies.count)
    }
  }
}

// MARK: - UICollectionViewDataSource

extension PopularMoviesController: UICollectionViewDataSourcePrefetching {
  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return movies.count
  }

  override func collectionView(_ collectionView: UICollectionView,
                               cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell: PosterCell = collectionView.dequeueReusableCell(for: indexPath)
    let model = movies[indexPath.row]
    cell.configure(for: model, posterProvider: posterProvider) { [weak self] in
      guard let `self` = self else { return }
      guard let rowIndex = self.movies.firstIndex(where: { $0.movie.tmdbID == model.movie.tmdbID }) else { return }
      collectionView.reloadItems(at: [IndexPath(row: rowIndex, section: 0)])
    }
    return cell
  }

  func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
    for indexPath in indexPaths {
      let item = movies[indexPath.row]
      if case .unknown = item.poster {
        item.poster = .loading
        DispatchQueue.global(qos: .background).async {
          fetchPoster(for: item,
                      using: self.posterProvider,
                      size: PosterCell.posterSize,
                      purpose: .popularMovies) { [weak self] in
            guard let `self` = self else { return }
            guard let rowIndex = self.movies.firstIndex(where: { $0.movie.tmdbID == item.movie.tmdbID }) else { return }
            collectionView.reloadItems(at: [IndexPath(row: rowIndex, section: 0)])
          }
        }
      }
    }
  }
}

// MARK: - UICollectionViewDelegate

extension PopularMoviesController {
  override func collectionView(_ collectionView: UICollectionView,
                               viewForSupplementaryElementOfKind kind: String,
                               at indexPath: IndexPath) -> UICollectionReusableView {
    switch kind {
      case UICollectionView.elementKindSectionHeader:
        let reusableView: TitleHeaderView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                                            for: indexPath)
        reusableView.configure(title: NSLocalizedString("popularMovies", comment: ""))
        return reusableView
      case UICollectionView.elementKindSectionFooter:
        return collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                               for: indexPath) as TmdbFooterView
      default:
        fatalError("Unexpected kind \(kind)")
    }
  }

  override func collectionView(_ collectionView: UICollectionView,
                               willDisplaySupplementaryView view: UICollectionReusableView,
                               forElementKind elementKind: String,
                               at indexPath: IndexPath) {
    guard elementKind == UICollectionView.elementKindSectionFooter,
          let footerView = view as? TmdbFooterView else { return }
    if isFetchingMovies {
      footerView.activityIndicator.startAnimating()
    }
  }

  override func collectionView(_ collectionView: UICollectionView,
                               didEndDisplayingSupplementaryView view: UICollectionReusableView,
                               forElementOfKind elementKind: String,
                               at indexPath: IndexPath) {
    guard elementKind == UICollectionView.elementKindSectionFooter,
          let footerView = view as? TmdbFooterView else { return }
    footerView.activityIndicator.stopAnimating()
  }

  override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
    return movies[indexPath.row].state == .new
  }

  override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    self.delegate?.popularMoviesController(self, didSelect: movies[indexPath.row])
  }

  func reloadRow(forMovieWithId id: TmdbIdentifier) {
    if let index = movies.firstIndex(where: { $0.movie.tmdbID == id }) {
      super.collectionView!.reloadItems(at: [IndexPath(row: index, section: 0)])
    }
  }
}

// MARK: - Data Management

extension PopularMoviesController {
  private func fetchMovies(count: Int) {
    guard !isFetchingMovies else { return }
    isFetchingMovies = true
    self.collectionView!.backgroundView = nil
    if let footerView = self.collectionView!.supplementaryView(forElementKind: UICollectionView.elementKindSectionFooter,
                                                               at: IndexPath(row: 0, section: 0)) as? TmdbFooterView {
      footerView.activityIndicator.startAnimating()
    }
    DispatchQueue.global(qos: .userInitiated).async {
      let newMovies = self.movieIterator.prefix(count).map { ExternalMovieViewModel($0, state: .new) }
      DispatchQueue.main.sync {
        let index = self.movies.count
        self.movies.append(contentsOf: newMovies)
        self.collectionView!.insertItems(at: (index..<(index + newMovies.count)).map { IndexPath(row: $0, section: 0) })
        if let footerView = self.collectionView!.supplementaryView(
            forElementKind: UICollectionView.elementKindSectionFooter,
            at: IndexPath(row: 0, section: 0)) as? TmdbFooterView {
          footerView.activityIndicator.stopAnimating()
          DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
            if self.movies.isEmpty {
              self.collectionView!.backgroundView = self.emptyView
              footerView.imageView.isHidden = true
            } else {
              footerView.imageView.isHidden = false
            }
          }
        }
        self.isFetchingMovies = false
      }
    }
  }
}

// MARK: - Actions

extension PopularMoviesController {
  func removeMovie(withId id: TmdbIdentifier) {
    guard let index = movies.firstIndex(where: { $0.movie.tmdbID == id }) else { return }
    self.movies.remove(at: index)
    collectionView!.deleteItems(at: [IndexPath(row: index, section: 0)])
    fetchMovies(count: 1)
  }
}

// MARK: - Header Views, Footer Views & Cells

class TitleHeaderView: UICollectionReusableView {
  @IBOutlet private var label: UILabel!

  func configure(title: String) {
    label.text = title
  }
}

class PosterCell: UICollectionViewCell {
  static let posterSize = PosterSize(minWidth: 130)
  @IBOutlet private var posterView: UIImageView!
  @IBOutlet private var titleLabel: UILabel!
  @IBOutlet private var blurView: UIVisualEffectView!
  @IBOutlet private var activityIndicator: UIActivityIndicatorView!
  @IBOutlet private var checkmarkView: UIVisualEffectView!
  private var highlightView: UIView!

  override func awakeFromNib() {
    super.awakeFromNib()
    posterView.layer.shadowColor = UIColor.black.cgColor
    posterView.layer.shadowRadius = 2
    posterView.layer.shadowOpacity = 0.5
    posterView.layer.shadowOffset = CGSize(width: 0.0, height: 1.0)
    self.highlightView = UIView(frame: posterView.frame)
    self.highlightView.backgroundColor = .black
    self.highlightView.alpha = 0
    self.contentView.addSubview(highlightView)
  }

  func configure(for model: ExternalMovieViewModel,
                 posterProvider: PosterProvider,
                 onNeedsReload: @escaping () -> Void) {
    titleLabel.text = model.movie.title
    switch model.state {
      case .new:
        blurView.isHidden = true
        checkmarkView.isHidden = true
      case .updateInProgress:
        blurView.isHidden = false
        checkmarkView.isHidden = true
        activityIndicator.startAnimating()
      case .addedToLibrary:
        blurView.isHidden = false
        checkmarkView.isHidden = false
    }
    switch model.poster {
      case .unknown:
        posterView.image = #imageLiteral(resourceName: "GenericPoster")
        model.poster = .loading
        DispatchQueue.global(qos: .userInteractive).async {
          fetchPoster(for: model,
                      using: posterProvider,
                      size: PosterCell.posterSize,
                      purpose: .popularMovies,
                      then: onNeedsReload)
        }
      case let .available(posterImage):
        posterView.image = posterImage
      case .loading, .unavailable:
        posterView.image = #imageLiteral(resourceName: "GenericPoster")
    }
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
    activityIndicator.stopAnimating()
  }
}

class TmdbFooterView: UICollectionReusableView {
  @IBOutlet fileprivate var activityIndicator: UIActivityIndicatorView!
  @IBOutlet fileprivate var imageView: UIImageView!
}
