import CinemaKit
import Dispatch
import Foundation
import UIKit

protocol SearchTmdbControllerDelegate: class {
  func searchTmdbController(_ controller: SearchTmdbController,
                            searchResultsFor searchText: String) -> [SearchTmdbController.SearchResult]
  func searchTmdbController(_ controller: SearchTmdbController,
                            didSelectSearchResult searchResult: SearchTmdbController.SearchResult)
}

class SearchTmdbController: UIViewController {
  struct SearchResult {
    let item: PartialMediaItem
    let hasBeenAddedToLibrary: Bool

    init(item: PartialMediaItem, hasBeenAddedToLibrary: Bool) {
      self.item = item
      self.hasBeenAddedToLibrary = hasBeenAddedToLibrary
    }
  }

  private let searchQueue = DispatchQueue(label: "de.martinbauer.cinema.tmdb-search", qos: .userInitiated)
  private var currentSearch: DispatchWorkItem?
  private lazy var searchController: UISearchController = {
    let resultsController = UIStoryboard.searchTmdb.instantiate(SearchTmdbSearchResultsController.self)
    resultsController.selectionHandler = { [weak self] searchResult in
      guard let `self` = self else { return }
      self.delegate?.searchTmdbController(self, didSelectSearchResult: searchResult)
    }
    let searchController = UISearchController(searchResultsController: resultsController)
    searchController.delegate = self
    searchController.searchResultsUpdater = self
    searchController.hidesNavigationBarDuringPresentation = false
    searchController.searchBar.placeholder = NSLocalizedString("addItem.search.placeholder", comment: "")
    return searchController
  }()
  weak var delegate: SearchTmdbControllerDelegate?
  var additionalViewController: UIViewController? {
    get {
      return childViewControllers.first
    }
    set {
      loadViewIfNeeded()
      if let child = newValue {
        addChildViewController(child)
        child.view.frame = containerView.bounds
        containerView.addSubview(child.view)
        child.didMove(toParentViewController: self)
      } else if let child = childViewControllers.first {
        child.willMove(toParentViewController: nil)
        child.view.removeFromSuperview()
        child.removeFromParentViewController()
      }
    }
  }
  @IBOutlet private weak var containerView: UIView!

  override func viewDidLoad() {
    super.viewDidLoad()
    definesPresentationContext = true
    navigationItem.searchController = searchController
    navigationItem.hidesSearchBarWhenScrolling = false
    title = NSLocalizedString("addItem.title", comment: "")
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    searchController.isActive = false
  }
}

extension SearchTmdbController: UISearchResultsUpdating, UISearchControllerDelegate {
  func updateSearchResults(for searchController: UISearchController) {
    guard searchController.isActive else { return }
    guard let resultsController = searchController.searchResultsController as? SearchTmdbSearchResultsController else {
      preconditionFailure("unexpected SearchResultsController class")
    }
    let searchText = searchController.searchBar.text!
    if !searchText.isEmpty {
      if let previousSearch = self.currentSearch {
        previousSearch.cancel()
      }
      self.currentSearch = DispatchWorkItem {
        let searchResults = self.delegate?.searchTmdbController(self, searchResultsFor: searchText) ?? []
        DispatchQueue.main.sync {
          resultsController.searchText = searchText
          resultsController.searchResults = searchResults
          self.currentSearch = nil
        }
      }
      self.searchQueue.async(execute: self.currentSearch!)
    }
  }
}
