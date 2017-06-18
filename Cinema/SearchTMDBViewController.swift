import Foundation

import UIKit
import Dispatch

class SearchTMDBViewController: UIViewController, UISearchResultsUpdating, SearchResultsSelectionDelegate {

  private var searchController: UISearchController!
  @IBOutlet weak var searchBarPlaceholder: UIView!

  private var searchResultsController: SearchResultsController!

  var library: MediaLibrary!
  var movieDb: MovieDbClient!

  override func viewDidLoad() {
    super.viewDidLoad()
    searchResultsController = storyboard!.instantiateViewController(withIdentifier: "ResultsViewController") as! SearchResultsController
    searchResultsController.delegate = self
    searchController = UISearchController(searchResultsController: searchResultsController)
    searchController.searchResultsUpdater = self
    searchController.hidesNavigationBarDuringPresentation = false
    searchController.dimsBackgroundDuringPresentation = false
    definesPresentationContext = true
    searchController.searchBar.sizeToFit()
    searchBarPlaceholder.addSubview(searchController.searchBar)
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
    let alert = UIAlertController(title: "How do you want to add the movie?",
                                  message: nil,
                                  preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "DVD", style: .default) { _ in
      self.add(searchItem: searchResult, diskType: .dvd)
    })
    alert.addAction(UIAlertAction(title: "Blu-ray", style: .default) { _ in
      self.add(searchItem: searchResult, diskType: .bluRay)
    })
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    present(alert, animated: true)
  }

  private func add(searchItem: PartialMediaItem, diskType: DiskType) {
    DispatchQueue.global(qos: .userInitiated).async {
      let runtime = self.movieDb.runtime(for: searchItem.id)
      let item = MediaItem(id: searchItem.id,
                           title: searchItem.title,
                           runtime: runtime ?? -1,
                           year: searchItem.year ?? -1,
                           diskType: diskType)
      let success = self.library.add(item)
      DispatchQueue.main.async {
        let title = success ? "Library successfully updated." : "Library could not be updated."
        let message = success ? "\(item.title) was added." : nil
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .default))
        self.present(alert, animated: true)
      }
    }
  }

}
