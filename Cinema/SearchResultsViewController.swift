import UIKit
import Dispatch

class SearchResultsController: UIViewController, UITableViewDelegate, UITableViewDataSource {

  @IBOutlet weak var tableView: UITableView!
  var searchResults = [PartialMediaItem]() {
    didSet {
      resultsInLibrary = searchResults.map { movie in
        return !self.library.mediaItems(where: { $0.id == movie.id }).isEmpty
      }
      DispatchQueue.main.async {
        self.tableView.reloadData()
      }
    }
  }
  var library: MediaLibrary!
  private var resultsInLibrary: [Bool]!
  weak var delegate: SearchResultsSelectionDelegate?

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.delegate = self
    tableView.dataSource = self
  }

  // MARK: - Table view data source

  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return searchResults.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let searchItem = searchResults[indexPath.row]
    if resultsInLibrary[indexPath.row] {
      let cell = tableView.dequeueReusableCell(withIdentifier: "SearchItemAddedCell",
                                               // swiftlint:disable:next force_cast
                                               for: indexPath) as! SearchItemAddedCell
      cell.titleLabel.text = searchItem.title
      return cell
    } else {
      // swiftlint:disable:next force_cast
      let cell = tableView.dequeueReusableCell(withIdentifier: "SearchItemCell", for: indexPath) as! SearchItemCell
      cell.titleLabel.text = searchItem.title
      if let year = searchItem.year, year != -1 {
        cell.yearLabel.text = String(year)
      }
      return cell
    }
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    delegate?.didSelectSearchResult(searchResults[indexPath.row])
    tableView.deselectRow(at: indexPath, animated: true)
  }

}

protocol SearchResultsSelectionDelegate: class {
  func didSelectSearchResult(_ searchResult: PartialMediaItem)
}
