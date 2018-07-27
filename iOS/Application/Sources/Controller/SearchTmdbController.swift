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
    let movie: PartialMediaItem
    let hasBeenAddedToLibrary: Bool

    init(_ movie: PartialMediaItem, hasBeenAddedToLibrary: Bool) {
      self.movie = movie
      self.hasBeenAddedToLibrary = hasBeenAddedToLibrary
    }
  }

  private let searchQueue = DispatchQueue(label: "de.martinbauer.cinema.tmdb-search", qos: .userInitiated)
  private var currentSearch: DispatchWorkItem?
  private lazy var searchController: UISearchController = {
    let resultsController = GenericSearchResultsController<SearchTmdbController.SearchResult>()
    resultsController.cellRegistration = {
      $0.register(SearchTmdbSearchResultTableCell.self)
      $0.register(SearchTmdbSearchResultAddedTableCell.self)
    }
    resultsController.canSelect = { !$0.hasBeenAddedToLibrary }
    resultsController.onSelection = { [weak self] selectedItem in
      guard let `self` = self else { return }
      self.delegate?.searchTmdbController(self, didSelectSearchResult: selectedItem)
    }
    resultsController.deselectImmediately = true
    resultsController.cellConfiguration = { tableView, indexPath, searchResult in
      if searchResult.hasBeenAddedToLibrary {
        let cell: SearchTmdbSearchResultAddedTableCell = tableView.dequeueReusableCell(for: indexPath)
        cell.configure(for: searchResult)
        return cell
      } else {
        let cell: SearchTmdbSearchResultTableCell = tableView.dequeueReusableCell(for: indexPath)
        cell.configure(for: searchResult)
        return cell
      }
    }
    let searchController = UISearchController(searchResultsController: resultsController)
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

extension SearchTmdbController: UISearchResultsUpdating {
  func updateSearchResults(for searchController: UISearchController) {
    guard searchController.isActive else { return }
    guard let resultsController = searchController.searchResultsController
        as? GenericSearchResultsController<SearchTmdbController.SearchResult> else {
      preconditionFailure("unexpected SearchResultsController class")
    }
    currentSearch?.cancel()
    let searchText = searchController.searchBar.text!
    if !searchText.isEmpty {
      currentSearch = DispatchWorkItem {
        let searchResults = self.delegate?.searchTmdbController(self, searchResultsFor: searchText) ?? []
        DispatchQueue.main.sync {
          resultsController.reload(searchText: searchText, searchResults: searchResults)
          self.currentSearch = nil
        }
      }
      searchQueue.async(execute: currentSearch!)
    }
  }
}

class SearchTmdbSearchResultTableCell: UITableViewCell {
  @IBOutlet private weak var titleLabel: UILabel!
  @IBOutlet private weak var yearLabel: UILabel!

  func configure(for searchResult: SearchTmdbController.SearchResult) {
    titleLabel.text = searchResult.movie.title
    if let releaseYear = searchResult.movie.releaseYear {
      yearLabel.text = String(releaseYear)
    }
  }
}

class SearchTmdbSearchResultAddedTableCell: UITableViewCell {
  @IBOutlet private weak var titleLabel: UILabel!
  @IBOutlet private weak var yearLabel: UILabel!

  override func awakeFromNib() {
    super.awakeFromNib()
    self.tintColor = .disabledControlText
  }

  func configure(for searchResult: SearchTmdbController.SearchResult) {
    titleLabel.text = searchResult.movie.title
  }
}
