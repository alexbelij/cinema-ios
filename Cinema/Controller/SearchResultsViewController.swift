import Dispatch
import UIKit

class SearchResultsController: UIViewController {

  @IBOutlet private weak var tableView: UITableView!
  private lazy var emptyView = GenericEmptyView()

  var searchText: String?
  var searchResults = [PartialMediaItem]() {
    didSet {
      DispatchQueue.main.async {
        if self.searchResults.isEmpty {
          guard let searchText = self.searchText else {
            preconditionFailure("no search text set")
          }
          self.emptyView.configure(
              accessory: .image(#imageLiteral(resourceName: "EmptySearchResults")),
              description: .basic(.localizedStringWithFormat(NSLocalizedString("search.results.empty", comment: ""),
                                                             searchText))
          )
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
}

// MARK: - Table View

extension SearchResultsController: UITableViewDataSource, UITableViewDelegate {
  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return searchResults.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let searchItem = searchResults[indexPath.row]
    if resultsInLibrary[indexPath.row] {
      let cell = tableView.dequeueReusableCell(withIdentifier: "SearchItemAddedCell",
                                               // swiftlint:disable:next force_cast
                                               for: indexPath) as! SearchItemAddedCell
      cell.configure(for: searchItem)
      return cell
    } else {
      // swiftlint:disable:next force_cast
      let cell = tableView.dequeueReusableCell(withIdentifier: "SearchItemCell", for: indexPath) as! SearchItemCell
      cell.configure(for: searchItem)
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
  @IBOutlet private weak var titleLabel: UILabel!
  @IBOutlet private weak var yearLabel: UILabel!

  func configure(for searchItem: PartialMediaItem) {
    titleLabel.text = searchItem.title
    if let releaseDate = searchItem.releaseDate {
      let calendar = Calendar.current
      yearLabel.text = String(calendar.component(.year, from: releaseDate))
    }
  }
}

class SearchItemAddedCell: UITableViewCell {

  @IBOutlet private weak var titleLabel: UILabel!

  func configure(for searchItem: PartialMediaItem) {
    titleLabel.text = searchItem.title
  }

  override func awakeFromNib() {
    super.awakeFromNib()
    self.tintColor = .disabledControlText
  }
}
