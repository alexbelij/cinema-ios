import CinemaKit
import Dispatch
import Foundation
import UIKit

protocol SearchTmdbControllerDelegate: class {
  func searchTmdbController(_ controller: SearchTmdbController,
                            searchResultsFor searchText: String) -> [ExternalMovieViewModel]
  func searchTmdbController(_ controller: SearchTmdbController, didSelect model: ExternalMovieViewModel)
}

class SearchTmdbController: UIViewController {
  private let searchQueue = DispatchQueue(label: "de.martinbauer.cinema.tmdb-search", qos: .userInitiated)
  private let throttlingTime: DispatchTimeInterval = .milliseconds(250)
  private var currentSearch: DispatchWorkItem?
  private lazy var searchController: UISearchController = {
    let searchController = UISearchController(searchResultsController: resultsController)
    searchController.searchResultsUpdater = self
    searchController.searchBar.placeholder = NSLocalizedString("addMovie.search.placeholder", comment: "")
    return searchController
  }()
  private lazy var resultsController: GenericSearchResultsController<ExternalMovieViewModel> = {
    let resultsController = GenericSearchResultsController<ExternalMovieViewModel>(
        cell: SearchTmdbSearchResultTableCell.self,
        estimatedRowHeight: SearchTmdbSearchResultTableCell.rowHeight)
    resultsController.canSelect = { item in
      switch item.state {
        case .new: return true
        case .updateInProgress, .addedToLibrary: return false
      }
    }
    resultsController.onSelection = { [weak self] selectedItem in
      guard let `self` = self else { return }
      self.delegate?.searchTmdbController(self, didSelect: selectedItem)
    }
    resultsController.deselectImmediately = true
    resultsController.cellConfiguration = { [weak self, weak resultsController] tableView, indexPath, listItem in
      guard let `self` = self, let resultsController = resultsController else { return UITableViewCell() }
      let cell: SearchTmdbSearchResultTableCell = tableView.dequeueReusableCell(for: indexPath)
      cell.configure(for: listItem, posterProvider: self.posterProvider) {
        guard let rowIndex = resultsController.items.index(where: { $0.movie.tmdbID == listItem.movie.tmdbID })
            else { return }
        tableView.reloadRowWithoutAnimation(at: IndexPath(row: rowIndex, section: 0))
      }
      return cell
    }
    resultsController.prefetchHandler = { [weak self, weak resultsController] tableView, indexPaths in
      guard let `self` = self, let resultsController = resultsController else { return }
      for indexPath in indexPaths {
        let model = resultsController.items[indexPath.row]
        if case .unknown = model.poster {
          model.poster = .loading
          DispatchQueue.global(qos: .background).async {
            fetchPoster(for: model,
                        using: self.posterProvider,
                        size: MovieListListItemTableCell.posterSize,
                        purpose: .searchResult) {
              guard let rowIndex = resultsController.items.index(where: { $0.movie.tmdbID == model.movie.tmdbID })
                  else { return }
              tableView.reloadRowWithoutAnimation(at: IndexPath(row: rowIndex, section: 0))
            }
          }
        }
      }
    }
    return resultsController
  }()
  weak var delegate: SearchTmdbControllerDelegate?
  var additionalViewController: UIViewController? {
    get {
      return children.first
    }
    set {
      loadViewIfNeeded()
      if let child = newValue {
        addChild(child)
        child.view.frame = containerView.bounds
        containerView.addSubview(child.view)
        child.didMove(toParent: self)
      } else if let child = children.first {
        child.willMove(toParent: nil)
        child.view.removeFromSuperview()
        child.removeFromParent()
      }
    }
  }
  @IBOutlet private weak var containerView: UIView!
  var posterProvider: PosterProvider = EmptyPosterProvider()

  override func viewDidLoad() {
    super.viewDidLoad()
    definesPresentationContext = true
    navigationItem.searchController = searchController
    navigationItem.hidesSearchBarWhenScrolling = false
    title = NSLocalizedString("addMovie.title", comment: "")
  }
}

extension SearchTmdbController: UISearchResultsUpdating {
  func updateSearchResults(for searchController: UISearchController) {
    guard searchController.isActive else { return }
    currentSearch?.cancel()
    let searchText = searchController.searchBar.text!
    if searchText.isEmpty {
      searchQueue.async {
        DispatchQueue.main.sync {
          self.resultsController.reload(searchText: nil, searchResults: [])
        }
      }
    } else {
      currentSearch = DispatchWorkItem {
        let searchResults = self.delegate?.searchTmdbController(self, searchResultsFor: searchText) ?? []
        DispatchQueue.main.sync {
          self.resultsController.reload(searchText: searchText, searchResults: searchResults)
          self.currentSearch = nil
        }
      }
      searchQueue.asyncAfter(deadline: .now() + throttlingTime, execute: currentSearch!)
    }
  }
}

extension SearchTmdbController {
  func reloadRow(forMovieWithId id: TmdbIdentifier) {
    resultsController.reloadRow { $0.movie.tmdbID == id }
  }
}

class SearchTmdbSearchResultTableCell: UITableViewCell {
  static let rowHeight: CGFloat = 100
  static let posterSize = PosterSize(minWidth: 60)
  @IBOutlet private weak var posterView: UIImageView!
  @IBOutlet private weak var titleLabel: UILabel!
  @IBOutlet private weak var yearLabel: UILabel!
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
        posterView.image = nil
        posterView.alpha = 0.0
        model.poster = .loading
        DispatchQueue.global(qos: .userInteractive).async {
          fetchPoster(for: model,
                      using: posterProvider,
                      size: SearchTmdbSearchResultTableCell.posterSize,
                      purpose: .searchResult,
                      then: onNeedsReload)
        }
      case .loading:
        posterView.image = nil
        posterView.alpha = 0.0
      case let .available(posterImage):
        posterView.image = posterImage
        posterView.alpha = 1.0
      case .unavailable:
        posterView.image = #imageLiteral(resourceName: "GenericPoster")
        posterView.alpha = 1.0
    }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    activityIndicator.stopAnimating()
  }
}
