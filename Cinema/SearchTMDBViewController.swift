import Foundation

import UIKit
import Dispatch

class SearchTMDBViewController: UIViewController, UISearchResultsUpdating, UISearchControllerDelegate,
    SearchResultsSelectionDelegate {

  private var searchController: UISearchController!
  @IBOutlet weak var searchBarPlaceholder: UIView!

  private var searchResultsController: SearchResultsController!

  var library: MediaLibrary!
  var movieDb: MovieDbClient!

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
    searchController.isActive = true
  }

  func didPresentSearchController(_ searchController: UISearchController) {
    searchController.searchBar.becomeFirstResponder()
  }

  public func updateSearchResults(for searchController: UISearchController) {
    let searchText = searchController.searchBar.text!
    if !searchText.isEmpty {
      DispatchQueue.global(qos: .userInteractive).async {
        let searchResults = self.movieDb.searchMovies(searchText: searchText)
        DispatchQueue.main.async {
          self.searchResultsController.searchResults = searchResults
        }
      }
    }
  }

  func didSelectSearchResult(_ searchResult: PartialMediaItem) {
    let alert = UIAlertController(title: NSLocalizedString("addItem.alert.howToAdd.title", comment: ""),
                                  message: nil,
                                  preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: NSLocalizedString("mediaItem.disk.dvd", comment: ""), style: .default) { _ in
      let controller = self.storyboard!
      // swiftlint:disable:next force_cast
          .instantiateViewController(withIdentifier: "AddItemViewController") as! AddItemViewController
      controller.add(item: searchResult, as: .dvd, to: self.library, movieDb: self.movieDb)
      self.present(controller, animated: true)
    })
    alert.addAction(UIAlertAction(title: NSLocalizedString("mediaItem.disk.bluRay", comment: ""),
                                  style: .default) { _ in
      let controller = self.storyboard!
      // swiftlint:disable:next force_cast
          .instantiateViewController(withIdentifier: "AddItemViewController") as! AddItemViewController
      controller.add(item: searchResult, as: .bluRay, to: self.library, movieDb: self.movieDb)
      self.present(controller, animated: true)
    })
    alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel))
    present(alert, animated: true)
  }

}
