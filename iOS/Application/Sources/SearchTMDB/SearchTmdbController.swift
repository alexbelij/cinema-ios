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
    resultsController.cellConfiguration = { [weak self] tableView, indexPath, listItem in
      guard let `self` = self else { return UITableViewCell() }
      let cell: SearchTmdbSearchResultTableCell = tableView.dequeueReusableCell(for: indexPath)
      tableView.configure(cell,
                          for: listItem,
                          at: { [weak resultsController] in
                            resultsController?.items.firstIndex { $0.movie.tmdbID == listItem.movie.tmdbID }
                                                    .map { IndexPath(row: $0, section: 0) }
                          },
                          using: self.posterProvider)
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
              tableView.reloadRow(for: model,
                                  at: { [weak resultsController] in
                                    resultsController?.items.firstIndex { $0.movie.tmdbID == model.movie.tmdbID }
                                                            .map { IndexPath(row: $0, section: 0) }
                                  },
                                  using: self.posterProvider)
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
  @IBOutlet private var containerView: UIView!
  var posterProvider: PosterProvider = EmptyPosterProvider()

  override func viewDidLoad() {
    super.viewDidLoad()
    definesPresentationContext = true
    navigationItem.searchController = searchController
    navigationItem.hidesSearchBarWhenScrolling = false
    title = NSLocalizedString("addMovie.title", comment: "")
  }
}

extension UITableView {
  fileprivate func reloadRow(for movie: ExternalMovieViewModel,
                             at indexPathProvider: @escaping () -> IndexPath?,
                             using posterProvider: PosterProvider) {
    guard let indexPath = indexPathProvider() else { return }
    if let cell = cellForRow(at: indexPath) as? SearchTmdbSearchResultTableCell {
      configure(cell,
                for: movie,
                at: indexPathProvider,
                using: posterProvider)
    }
  }

  fileprivate func configure(_ cell: SearchTmdbSearchResultTableCell,
                             for movie: ExternalMovieViewModel,
                             at indexPathProvider: @escaping () -> IndexPath?,
                             using posterProvider: PosterProvider) {
    cell.configure(for: movie, posterProvider: posterProvider) {
      guard let indexPath = indexPathProvider() else { return }
      if let cell = self.cellForRow(at: indexPath) as? SearchTmdbSearchResultTableCell {
        self.configure(cell,
                       for: movie,
                       at: indexPathProvider,
                       using: posterProvider)
      }
    }
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
