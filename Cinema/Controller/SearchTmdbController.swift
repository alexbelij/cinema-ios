import Dispatch
import Foundation
import UIKit

class SearchTmdbController: UIViewController {

  private let searchQueue = DispatchQueue(label: "de.martinbauer.cinema.tmdb-search", qos: .userInitiated)
  private var currentSearch: DispatchWorkItem?
  private var searchController: UISearchController!
  @IBOutlet private weak var containerView: UIView!
  private var popularMoviesController: PopularMoviesController!

  private var searchResultsController: SearchTmdbSearchResultsController!

  var library: MediaLibrary!
  var movieDb: MovieDbClient!

  private var removedItem: PartialMediaItem?

  override func viewDidLoad() {
    super.viewDidLoad()
    searchResultsController = storyboard!.instantiate(SearchTmdbSearchResultsController.self)
    searchResultsController.delegate = self
    searchController = UISearchController(searchResultsController: searchResultsController)
    searchController.delegate = self
    searchController.searchResultsUpdater = self
    searchController.hidesNavigationBarDuringPresentation = false
    searchController.dimsBackgroundDuringPresentation = false
    definesPresentationContext = true
    searchController.searchBar.placeholder = NSLocalizedString("addItem.search.placeholder", comment: "")
    self.navigationItem.searchController = searchController
    self.navigationItem.hidesSearchBarWhenScrolling = false
    title = NSLocalizedString("addItem.title", comment: "")
    popularMoviesController = UIStoryboard.popularMovies.instantiate(PopularMoviesController.self)
    let movies = movieDb.popularMovies().lazy.filter { !self.library.contains(id: $0.id) }
    popularMoviesController.movieIterator = AnyIterator(movies.makeIterator())
    popularMoviesController.posterProvider = MovieDbPosterProvider(movieDb)
    popularMoviesController.delegate = self
    addChildViewController(popularMoviesController)
    popularMoviesController.view.frame = containerView.bounds
    containerView.addSubview(popularMoviesController.view)
    popularMoviesController.didMove(toParentViewController: self)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if let removedItem = self.removedItem {
      DispatchQueue.main.async {
        self.popularMoviesController.removeItem(removedItem)
      }
      self.removedItem = nil
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    searchController.isActive = false
  }
}

extension SearchTmdbController: UISearchResultsUpdating, UISearchControllerDelegate {
  func didPresentSearchController(_ searchController: UISearchController) {
    searchController.searchBar.becomeFirstResponder()
  }

  public func updateSearchResults(for searchController: UISearchController) {
    let searchText = searchController.searchBar.text!
    if !searchText.isEmpty {
      DispatchQueue.main.async {
        if let previousSearch = self.currentSearch {
          previousSearch.cancel()
        }
        self.currentSearch = DispatchWorkItem {
          let searchResults = self.movieDb.searchMovies(searchText: searchText).map { movie in
            SearchTmdbSearchResultsController.SearchResult(item: movie,
                                                           hasBeenAddedToLibrary: self.library.contains(id: movie.id))
          }
          self.searchResultsController.searchText = searchText
          self.searchResultsController.searchResults = searchResults
          DispatchQueue.main.sync {
            self.currentSearch = nil
          }
        }
        self.searchQueue.async(execute: self.currentSearch!)
      }
    }
  }
}

extension SearchTmdbController: SearchResultsSelectionDelegate {
  func didSelectSearchResult(_ searchResult: PartialMediaItem) {
    showAddAlert(for: searchResult)
  }

  private func showAddAlert(for item: PartialMediaItem) {
    let alert = UIAlertController(title: NSLocalizedString("addItem.alert.howToAdd.title", comment: ""),
                                  message: nil,
                                  preferredStyle: .alert)
    for diskType in [DiskType.dvd, .bluRay] {
      alert.addAction(UIAlertAction(title: diskType.localizedName, style: .default) { _ in
        self.showLibraryUpdateController(for: item, diskType: diskType)
      })
    }
    alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel))
    present(alert, animated: true)
  }

  private func showLibraryUpdateController(for item: PartialMediaItem,
                                           diskType: DiskType) {
    let libraryUpdateController = UIStoryboard.addItem.instantiate(LibraryUpdateController.self)
    DispatchQueue.global(qos: .userInitiated).async {
      if let poster = self.movieDb.poster(for: item.id, size: PosterSize(minWidth: 185)) {
        DispatchQueue.main.async {
          libraryUpdateController.poster = poster
        }
      }
    }
    present(libraryUpdateController, animated: true)
    DispatchQueue.global(qos: .userInitiated).async {
      let fullItem = MediaItem(id: item.id,
                               title: item.title,
                               runtime: self.movieDb.runtime(for: item.id),
                               releaseDate: item.releaseDate,
                               diskType: diskType,
                               genreIds: self.movieDb.genreIds(for: item.id))
      do {
        try self.library.add(fullItem)
        DispatchQueue.main.async {
          libraryUpdateController.endUpdate(result: .success(addedItemTitle: item.title))
          DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            libraryUpdateController.dismiss(animated: true) {
              self.popularMoviesController.removeItem(item)
            }
          }
        }
      } catch let error {
        DispatchQueue.main.async {
          libraryUpdateController.endUpdate(result: .failure(error))
          DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            libraryUpdateController.dismiss(animated: true)
          }
        }
      }
    }
  }
}

extension SearchTmdbController: PopularMoviesControllerDelegate {
  func popularMoviesController(_ controller: PopularMoviesController, didSelect movie: PartialMediaItem) {
    self.showAddAlert(for: movie)
  }
}
