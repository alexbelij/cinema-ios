import Foundation

import UIKit
import Dispatch

class SearchTMDBViewController: UIViewController, UISearchResultsUpdating, UISearchControllerDelegate,
    SearchResultsSelectionDelegate {

  private var searchController: UISearchController!
  @IBOutlet weak var searchBarPlaceholder: UIView!
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
    searchController.searchBar.sizeToFit()
    searchController.searchBar.placeholder = NSLocalizedString("addItem.search.placeholder", comment: "")
    searchBarPlaceholder.addSubview(searchController.searchBar)
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
    searchController.isActive = false
  }

  public func updateSearchResults(for searchController: UISearchController) {
    let searchText = searchController.searchBar.text!
    if !searchText.isEmpty {
      DispatchQueue.global(qos: .userInteractive).async {
        let searchResults = self.movieDb.searchMovies(searchText: searchText)
        self.searchResultsController.searchText = searchText
        self.searchResultsController.searchResults = searchResults
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
