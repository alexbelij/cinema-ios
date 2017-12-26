import UIKit

class SearchTmdbSearchResultsController: UITableViewController {
  private lazy var emptyView = GenericEmptyView()
  var searchText: String = "" {
    didSet {
      self.emptyView.configure(
          accessory: .image(#imageLiteral(resourceName: "EmptySearchResults")),
          description: .basic(.localizedStringWithFormat(NSLocalizedString("search.results.empty", comment: ""),
                                                         self.searchText))
      )
    }
  }
  var searchResults = [SearchTmdbController.SearchResult]() {
    didSet {
      if self.searchResults.isEmpty {
        self.tableView.backgroundView = self.emptyView
        self.tableView.separatorStyle = .none
      } else {
        self.tableView.backgroundView = nil
        self.tableView.separatorStyle = .singleLine
      }
      self.tableView.reloadData()
    }
  }
  var selectionHandler: ((SearchTmdbController.SearchResult) -> Void)?
}

// MARK: - Table View

extension SearchTmdbSearchResultsController {
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return searchResults.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let searchResult = searchResults[indexPath.row]
    if searchResult.hasBeenAddedToLibrary {
      let cell = tableView.dequeueReusableCell(withIdentifier: "SearchItemAddedCell",
                                               // swiftlint:disable:next force_cast
                                               for: indexPath) as! SearchItemAddedCell
      cell.configure(for: searchResult.item)
      return cell
    } else {
      // swiftlint:disable:next force_cast
      let cell = tableView.dequeueReusableCell(withIdentifier: "SearchItemCell", for: indexPath) as! SearchItemCell
      cell.configure(for: searchResult.item)
      return cell
    }
  }

  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 44
  }

  override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
    return searchResults[indexPath.row].hasBeenAddedToLibrary ? nil : indexPath
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    selectionHandler?(searchResults[indexPath.row])
    tableView.deselectRow(at: indexPath, animated: true)
  }
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
