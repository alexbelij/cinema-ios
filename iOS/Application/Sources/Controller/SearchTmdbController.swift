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
  class SearchResult {
    let movie: PartialMediaItem
    var poster: Image
    let hasBeenAddedToLibrary: Bool

    init(_ movie: PartialMediaItem, hasBeenAddedToLibrary: Bool) {
      self.movie = movie
      self.hasBeenAddedToLibrary = hasBeenAddedToLibrary
      self.poster = .unknown
    }

    enum Image {
      case unknown
      case loading
      case available(UIImage)
      case unavailable
    }
  }

  private let searchQueue = DispatchQueue(label: "de.martinbauer.cinema.tmdb-search", qos: .userInitiated)
  private var currentSearch: DispatchWorkItem?
  private lazy var searchController: UISearchController = {
    let resultsController = GenericSearchResultsController<SearchTmdbController.SearchResult>()
    resultsController.cellRegistration = { $0.register(SearchTmdbSearchResultTableCell.self) }
    resultsController.canSelect = { !$0.hasBeenAddedToLibrary }
    resultsController.onSelection = { [weak self] selectedItem in
      guard let `self` = self else { return }
      self.delegate?.searchTmdbController(self, didSelectSearchResult: selectedItem)
    }
    resultsController.deselectImmediately = true
    resultsController.cellConfiguration = { [posterProvider] tableView, indexPath, listItem in
      let cell: SearchTmdbSearchResultTableCell = tableView.dequeueReusableCell(for: indexPath)
      cell.configure(for: listItem, posterProvider: posterProvider)
      return cell
    }
    let searchController = UISearchController(searchResultsController: resultsController)
    searchController.searchResultsUpdater = self
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
  var posterProvider: PosterProvider = EmptyPosterProvider()

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
  @IBOutlet private weak var posterView: UIImageView!
  @IBOutlet private weak var titleLabel: UILabel!
  @IBOutlet private weak var yearLabel: UILabel!
  private var workItem: DispatchWorkItem?

  override func awakeFromNib() {
    super.awakeFromNib()
    posterView.layer.borderColor = UIColor.posterBorder.cgColor
    posterView.layer.borderWidth = 0.5
  }

  func configure(for searchResult: SearchTmdbController.SearchResult, posterProvider: PosterProvider) {
    titleLabel.text = searchResult.movie.title
    if let year = searchResult.movie.releaseYear {
      yearLabel.text = String(year)
    }
    accessoryType = searchResult.hasBeenAddedToLibrary ? .checkmark : .none
    selectionStyle = searchResult.hasBeenAddedToLibrary ? .none : .default
    configurePoster(for: searchResult, posterProvider: posterProvider)
  }

  private func configurePoster(for searchResult: SearchTmdbController.SearchResult, posterProvider: PosterProvider) {
    switch searchResult.poster {
      case .unknown:
        posterView.image = #imageLiteral(resourceName: "GenericPoster")
        searchResult.poster = .loading
        let size = PosterSize(minWidth: Int(posterView.frame.size.width))
        var workItem: DispatchWorkItem?
        workItem = DispatchWorkItem {
          let poster = posterProvider.poster(for: searchResult.movie.tmdbID, size: size, purpose: .searchResult)
          DispatchQueue.main.async {
            if let posterImage = poster {
              searchResult.poster = .available(posterImage)
            } else {
              searchResult.poster = .unavailable
            }
            if !workItem!.isCancelled {
              self.configurePoster(for: searchResult, posterProvider: posterProvider)
            }
          }
        }
        self.workItem = workItem
        DispatchQueue.global(qos: .userInteractive).async(execute: workItem!)
      case let .available(posterImage):
        posterView.image = posterImage
      case .loading, .unavailable:
        posterView.image = #imageLiteral(resourceName: "GenericPoster")
    }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    self.workItem?.cancel()
    self.workItem = nil
  }
}
