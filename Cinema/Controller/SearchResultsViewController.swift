import Dispatch
import UIKit

class SearchResultsController: UIViewController, UITableViewDelegate, UITableViewDataSource {

  @IBOutlet private weak var tableView: UITableView!
  @IBOutlet private var emptyView: UIView!
  @IBOutlet private weak var emptyViewLabel: UILabel!

  var searchText: String?
  var searchResults = [PartialMediaItem]() {
    didSet {
      DispatchQueue.main.async {
        if self.searchResults.isEmpty {
          guard let searchText = self.searchText else {
            preconditionFailure("no search text set")
          }
          self.emptyViewLabel.text = String.localizedStringWithFormat(NSLocalizedString("search.results.empty",
                                                                                        comment: ""), searchText)
          self.tableView.backgroundView = self.emptyView
          self.tableView.separatorStyle = .none
          self.resultsInLibrary = nil
        } else {
          self.tableView.backgroundView = nil
          self.tableView.separatorStyle = .singleLine
          self.resultsInLibrary = self.searchResults.map { movie in
            !self.library.mediaItems { $0.id == movie.id }.isEmpty
          }
        }
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
      if let releaseDate = searchItem.releaseDate {
        let calendar = Calendar.current
        cell.yearLabel.text = String(calendar.component(.year, from: releaseDate))
      }
      return cell
    }
  }

  func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
    return resultsInLibrary[indexPath.row] ? nil : indexPath
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    delegate?.didSelectSearchResult(searchResults[indexPath.row])
    tableView.deselectRow(at: indexPath, animated: true)
  }

}

protocol SearchResultsSelectionDelegate: class {
  func didSelectSearchResult(_ searchResult: PartialMediaItem)
}

class SearchItemCell: UITableViewCell {
  @IBOutlet fileprivate weak var titleLabel: UILabel!
  @IBOutlet fileprivate weak var yearLabel: UILabel!
}

class SearchItemAddedCell: UITableViewCell {

  @IBOutlet fileprivate weak var titleLabel: UILabel!

  override func awakeFromNib() {
    super.awakeFromNib()
    self.tintColor = .disabledControlText
  }
}
