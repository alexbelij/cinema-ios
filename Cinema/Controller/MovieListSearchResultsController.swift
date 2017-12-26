import UIKit

class MovieListSearchResultsController: UITableViewController {
  var searchText: String? {
    didSet {
      reload()
    }
  }
  var items = [MovieListItem]() {
    didSet {
      reload()
    }
  }
  var onSelection: ((MediaItem) -> Void)?
  var cellConfiguration: MediaItemCellConfig? {
    didSet {
      loadViewIfNeeded()
      cellConfiguration?.registerCells(in: self.tableView)
    }
  }
  private lazy var emptyView = GenericEmptyView()

  convenience init() {
    self.init(nibName: nil, bundle: nil)
  }

  private func reload() {
    tableView.reloadData()
    if items.isEmpty {
      showEmptyView()
    } else {
      hideEmptyView()
      tableView.setContentOffset(CGPoint(x: 0, y: -tableView.safeAreaInsets.top), animated: false)
    }
  }
}

// MARK: - Empty View

extension MovieListSearchResultsController {
  private func showEmptyView() {
    if let searchText = self.searchText {
      emptyView.configure(
          accessory: .image(#imageLiteral(resourceName: "EmptySearchResults")),
          description: .basic(.localizedStringWithFormat(NSLocalizedString("search.results.empty", comment: ""),
                                                         searchText))
      )
    }
    self.tableView.backgroundView = emptyView
    self.tableView.separatorStyle = .none
  }

  private func hideEmptyView() {
    self.tableView.backgroundView = nil
    self.tableView.separatorStyle = .singleLine
  }
}

// MARK: - Table View

extension MovieListSearchResultsController {
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return items.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let config = self.cellConfiguration else {
      fatalError("cell configuration has not been specified")
    }
    return config.cell(for: items[indexPath.row], cellDequeuing: tableView)
  }

  public override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 75
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    self.onSelection?(items[indexPath.row].movie)
  }
}
