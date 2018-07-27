import CinemaKit
import UIKit

class GenericSearchResultsController<Item>: UITableViewController {
  var cellRegistration: ((UITableView) -> Void)?
  var cellConfiguration: ((UITableView, IndexPath, Item) -> UITableViewCell)?
  var canSelect: ((Item) -> Bool)?
  var onSelection: ((Item) -> Void)?
  var deselectImmediately: Bool = false
  private(set) var searchText: String?
  private(set) var items = [Item]()
  private lazy var emptyView = GenericEmptyView()

  init() {
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("use GenericSearchResultsController.init() instead")
  }

  func reload(searchText: String, searchResults: [Item]) {
    self.searchText = searchText
    self.items = searchResults
    super.tableView.reloadData()
    if self.items.isEmpty {
      emptyView.configure(
          accessory: .image(#imageLiteral(resourceName: "EmptySearchResults")),
          description: .basic(.localizedStringWithFormat(NSLocalizedString("search.results.empty", comment: ""),
                                                         searchText))
      )
      super.tableView.backgroundView = emptyView
      super.tableView.separatorStyle = .none
    } else {
      super.tableView.backgroundView = nil
      super.tableView.separatorStyle = .singleLine
    }
  }

// MARK: - View Controller Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    super.tableView.tableFooterView = UIView()
    cellRegistration?(super.tableView)
  }

// MARK: - Table View

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return items.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    return cellConfiguration?(tableView, indexPath, items[indexPath.row]) ?? UITableViewCell()
  }

  override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
    return (canSelect?(items[indexPath.row]) ?? true) ? indexPath : nil
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if deselectImmediately {
      tableView.deselectRow(at: indexPath, animated: true)
    }
    self.onSelection?(items[indexPath.row])
  }
}
