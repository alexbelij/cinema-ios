import Dispatch
import Foundation
import UIKit

class SearchTMDBViewController: UIViewController, UISearchResultsUpdating, UISearchControllerDelegate,
    SearchResultsSelectionDelegate {

  private let searchQueue = DispatchQueue(label: "de.martinbauer.cinema.tmdb-search", qos: .userInitiated)
  private var currentSearch: DispatchWorkItem?
  private var searchController: UISearchController!
  @IBOutlet private weak var searchBarPlaceholder: UIView!
  @IBOutlet private weak var placeholderHeightConstraint: NSLayoutConstraint!
  private var popularMoviesVC: PopularMoviesViewController!

  private var searchResultsController: SearchResultsController!
  private var selectedSearchResult: PartialMediaItem?
  private var selectedDiskType: DiskType?

  var library: MediaLibrary!
  var movieDb: MovieDbClient!

  private var removedItem: PartialMediaItem?

  override func viewDidLoad() {
    super.viewDidLoad()
    searchResultsController = storyboard!
    // swiftlint:disable:next force_cast
        .instantiateViewController(withIdentifier: "ResultsViewController") as! SearchResultsController
    searchResultsController.library = library
    searchResultsController.delegate = self
    searchController = UISearchController(searchResultsController: searchResultsController)
    searchController.delegate = self
    searchController.searchResultsUpdater = self
    searchController.hidesNavigationBarDuringPresentation = false
    searchController.dimsBackgroundDuringPresentation = false
    definesPresentationContext = true
    searchController.searchBar.placeholder = NSLocalizedString("addItem.search.placeholder", comment: "")
    if #available(iOS 11.0, *) {
      self.navigationItem.searchController = searchController
      self.navigationItem.hidesSearchBarWhenScrolling = false
      self.placeholderHeightConstraint.constant = 0
    } else {
      searchController.searchBar.sizeToFit()
      searchBarPlaceholder.addSubview(searchController.searchBar)
    }
    title = NSLocalizedString("addItem.title", comment: "")
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if let removedItem = self.removedItem {
      DispatchQueue.main.async {
        self.popularMoviesVC.removeItem(removedItem)
      }
      self.removedItem = nil
    }
  }

  func didPresentSearchController(_ searchController: UISearchController) {
    searchController.searchBar.becomeFirstResponder()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    searchController.isActive = false
  }

  public func updateSearchResults(for searchController: UISearchController) {
    let searchText = searchController.searchBar.text!
    if !searchText.isEmpty {
      DispatchQueue.main.async {
        if let previousSearch = self.currentSearch {
          previousSearch.cancel()
        }
        self.currentSearch = DispatchWorkItem {
          let searchResults = self.movieDb.searchMovies(searchText: searchText)
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

  func didSelectSearchResult(_ searchResult: PartialMediaItem) {
    let alert = UIAlertController(title: NSLocalizedString("addItem.alert.howToAdd.title", comment: ""),
                                  message: nil,
                                  preferredStyle: .alert)
    self.selectedSearchResult = searchResult
    alert.addAction(UIAlertAction(title: NSLocalizedString("mediaItem.disk.dvd", comment: ""), style: .default) { _ in
      self.removedItem = searchResult
      self.selectedDiskType = .dvd
      self.performSegue(withIdentifier: "addItem", sender: self)
    })
    alert.addAction(UIAlertAction(title: NSLocalizedString("mediaItem.disk.bluRay", comment: ""),
                                  style: .default) { _ in
      self.removedItem = searchResult
      self.selectedDiskType = .bluRay
      self.performSegue(withIdentifier: "addItem", sender: self)
    })
    alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel))
    present(alert, animated: true)
  }

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    switch segue.unwrappedDestination {
      case let addItemVC as AddItemViewController:
        guard let item = selectedSearchResult,
              let diskType = selectedDiskType else {
          fatalError("item and disk type should have been set")
        }
        addItemVC.add(item: item, as: diskType, to: self.library, movieDb: self.movieDb)
      case let popularMoviesVC as PopularMoviesViewController:
        self.popularMoviesVC = popularMoviesVC
        popularMoviesVC.library = library
        popularMoviesVC.movieDb = movieDb
        popularMoviesVC.selectionDelegate = self
      default: fatalError("Unexpected segue: '\(self)' -> '\(segue.destination)'")
    }
  }
}
