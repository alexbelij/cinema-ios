import CinemaKit
import Dispatch
import Foundation
import UIKit

protocol SearchTmdbControllerDelegate: class {
  func searchTmdbController(_ controller: SearchTmdbController,
                            searchResultsFor searchText: String) -> [ExternalMovieViewModel]
  func searchTmdbController(_ controller: SearchTmdbController,
                            didSelectSearchResult model: ExternalMovieViewModel)
}

class SearchTmdbController: UIViewController {
  private let searchQueue = DispatchQueue(label: "de.martinbauer.cinema.tmdb-search", qos: .userInitiated)
  private let throttlingTime: DispatchTimeInterval = .milliseconds(250)
  private var currentSearch: DispatchWorkItem?
  private lazy var searchController: UISearchController = {
    let searchController = UISearchController(searchResultsController: resultsController)
    searchController.searchResultsUpdater = self
    searchController.searchBar.placeholder = NSLocalizedString("addItem.search.placeholder", comment: "")
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
      self.delegate?.searchTmdbController(self, didSelectSearchResult: selectedItem)
    }
    resultsController.deselectImmediately = true
    resultsController.cellConfiguration = { [posterProvider] dequeuing, indexPath, listItem in
      let cell: SearchTmdbSearchResultTableCell = dequeuing.dequeueReusableCell(for: indexPath)
      cell.configure(for: listItem, posterProvider: posterProvider)
      return cell
    }
    return resultsController
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
  @IBOutlet private weak var posterView: UIImageView!
  @IBOutlet private weak var titleLabel: UILabel!
  @IBOutlet private weak var yearLabel: UILabel!
  private lazy var activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
  private var workItem: DispatchWorkItem?

  override func awakeFromNib() {
    super.awakeFromNib()
    posterView.layer.borderColor = UIColor.posterBorder.cgColor
    posterView.layer.borderWidth = 0.5
  }

  func configure(for model: ExternalMovieViewModel, posterProvider: PosterProvider) {
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
    configurePoster(for: model, posterProvider: posterProvider)
  }

  private func configurePoster(for model: ExternalMovieViewModel, posterProvider: PosterProvider) {
    switch model.poster {
      case .unknown:
        posterView.image = #imageLiteral(resourceName: "GenericPoster")
        model.poster = .loading
        let size = PosterSize(minWidth: Int(posterView.frame.size.width))
        var workItem: DispatchWorkItem?
        workItem = DispatchWorkItem {
          let poster = posterProvider.poster(for: model.movie.tmdbID, size: size, purpose: .searchResult)
          DispatchQueue.main.async {
            if let posterImage = poster {
              model.poster = .available(posterImage)
            } else {
              model.poster = .unavailable
            }
            if !workItem!.isCancelled {
              self.configurePoster(for: model, posterProvider: posterProvider)
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
    activityIndicator.stopAnimating()
    self.workItem?.cancel()
    self.workItem = nil
  }
}
