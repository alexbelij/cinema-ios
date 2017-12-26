import Dispatch
import Foundation
import UIKit

class SearchTMDBViewController: UIViewController {

  private let searchQueue = DispatchQueue(label: "de.martinbauer.cinema.tmdb-search", qos: .userInitiated)
  private var currentSearch: DispatchWorkItem?
  private var searchController: UISearchController!
  @IBOutlet private weak var containerView: UIView!
  private var popularMoviesController: PopularMoviesController!

  private var searchResultsController: SearchResultsController!

  var library: MediaLibrary!
  var movieDb: MovieDbClient!

  private var removedItem: PartialMediaItem?

  override func viewDidLoad() {
    super.viewDidLoad()
    searchResultsController = storyboard!.instantiate(SearchResultsController.self)
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

extension SearchTMDBViewController: UISearchResultsUpdating, UISearchControllerDelegate {
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
            SearchResultsController.SearchResult(item: movie,
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

extension SearchTMDBViewController: SearchResultsSelectionDelegate {
  func didSelectSearchResult(_ searchResult: PartialMediaItem) {
    showAddAlert(for: searchResult)
  }

  private func showAddAlert(for searchResult: PartialMediaItem) {
    let alert = UIAlertController(title: NSLocalizedString("addItem.alert.howToAdd.title", comment: ""),
                                  message: nil,
                                  preferredStyle: .alert)
    for diskType in [DiskType.dvd, .bluRay] {
      alert.addAction(UIAlertAction(title: diskType.localizedName, style: .default) { _ in
        self.removedItem = searchResult
        self.add(searchResult, withDiskType: diskType)
      })
    }
    alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel))
    present(alert, animated: true)
  }

  private func add(_ searchResult: PartialMediaItem, withDiskType diskType: DiskType) {
    let controller = UIStoryboard.addItem.instantiate(LibraryUpdateController.self)
    controller.add(item: searchResult, as: diskType, to: self.library, movieDb: self.movieDb)
    self.present(controller, animated: true)
  }
}

extension SearchTMDBViewController: PopularMoviesControllerDelegate {
  func popularMoviesController(_ controller: PopularMoviesController, didSelect movie: PartialMediaItem) {
    self.showAddAlert(for: movie)
  }
}
