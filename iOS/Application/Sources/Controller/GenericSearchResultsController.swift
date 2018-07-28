import CinemaKit
import UIKit

class GenericSearchResultsController<Item>: UITableViewController {
  var cellConfiguration: ((TableViewDequeuing, IndexPath, Item) -> UITableViewCell)?
  var canSelect: ((Item) -> Bool)?
  var onSelection: ((Item) -> Void)?
  var deselectImmediately: Bool = false
  private let tableViewInitialization: ((UITableView) -> Void)
  private(set) var searchText: String?
  private(set) var items = [Item]()
  private lazy var emptyView = GenericEmptyView()

  init<CellType: UITableViewCell>(cell cellType: CellType.Type, bundle: Bundle? = nil) {
    self.tableViewInitialization = { tableView in
      tableView.register(cellType, bundle: bundle)
    }
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("use GenericSearchResultsController.init() instead")
  }

  func reload(searchText: String?, searchResults: [Item]) {
    self.searchText = searchText
    self.items = searchResults
    super.tableView.reloadData()
    if let searchText = searchText {
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
    } else {
      super.tableView.backgroundView = GenericEmptyView(accessory: .activityIndicator,
                                                        description: .basic(NSLocalizedString("loading", comment: "")))
      super.tableView.separatorStyle = .none
    }
  }

// MARK: - View Controller Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    super.tableView.tableFooterView = UIView()
    tableViewInitialization(super.tableView)
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
