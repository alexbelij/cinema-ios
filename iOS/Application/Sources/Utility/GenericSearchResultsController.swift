import CinemaKit
import UIKit

class GenericSearchResultsController<Item>: UITableViewController, UITableViewDataSourcePrefetching {
  var cellConfiguration: ((UITableView, IndexPath, Item) -> UITableViewCell)?
  var prefetchHandler: ((UITableView, [IndexPath]) -> Void)?
  var canSelect: ((Item) -> Bool)?
  var onSelection: ((Item) -> Void)?
  var deselectImmediately: Bool = false
  private let tableViewInitialization: ((UITableView) -> Void)
  private(set) var searchText: String?
  private(set) var items = [Item]()
  private lazy var emptyView = GenericEmptyView()

  init<CellType: UITableViewCell>(cell cellType: CellType.Type, bundle: Bundle? = nil, estimatedRowHeight: CGFloat) {
    self.tableViewInitialization = { tableView in
      tableView.register(cellType, bundle: bundle)
      tableView.estimatedRowHeight = estimatedRowHeight
    }
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("use GenericSearchResultsController.init() instead")
  }

  func reload(searchText: String?, searchResults: [Item]) {
    self.searchText = searchText
    self.items = searchResults
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
        let offset = -super.tableView.safeAreaInsets.top
        super.tableView.contentOffset = CGPoint(x: 0, y: offset)
      }
    } else {
      super.tableView.backgroundView = GenericEmptyView(accessory: .activityIndicator,
                                                        description: .basic(NSLocalizedString("loading", comment: "")))
      super.tableView.separatorStyle = .none
    }
    super.tableView.reloadData()
  }

  func reloadRow(where predicate: (Item) -> Bool) {
    if let index = items.index(where: predicate) {
      super.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
    }
  }

// MARK: - View Controller Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    super.tableView.tableFooterView = UIView()
    super.tableView.prefetchDataSource = self
    tableViewInitialization(super.tableView)
  }

// MARK: - Table View

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return items.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    return cellConfiguration?(tableView, indexPath, items[indexPath.row]) ?? UITableViewCell()
  }

  func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
    prefetchHandler?(tableView, indexPaths)
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
