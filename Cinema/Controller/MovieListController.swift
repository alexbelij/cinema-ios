import Dispatch
import UIKit

protocol MovieListControllerDelegate: class {
  func movieListController(_ controller: MovieListController, didSelect item: MediaItem)
}

protocol MediaItemCellConfig {
  func registerCells(in cellRegistering: CellRegistering)
  func cell(for item: MediaItem, cellDequeuing: CellDequeuing) -> UITableViewCell
}

class MovieListController: UITableViewController {
  weak var delegate: MovieListControllerDelegate?
  var library: MediaLibrary!

  var cellConfiguration: MediaItemCellConfig? {
    didSet {
      loadViewIfNeeded()
      cellConfiguration?.registerCells(in: tableView)
    }
  }

  private var allItems = [MediaItem]()
  private var sectionItems = [String: [MediaItem]]()
  private var sectionIndexTitles = [String]()
  private var visibleSectionIndexTitles = [String]()
  private var sectionTitles = [String]()

  private lazy var searchController: UISearchController = {
    let resultsController = MovieListSearchResultsController()
    resultsController.onSelection = { [weak self] selectedItem in
      guard let `self` = self else { return }
      self.delegate?.movieListController(self, didSelect: selectedItem)
    }
    resultsController.cellConfiguration = cellConfiguration
    let searchController = UISearchController(searchResultsController: resultsController)
    searchController.searchResultsUpdater = self
    searchController.dimsBackgroundDuringPresentation = false
    searchController.searchBar.placeholder = NSLocalizedString("library.search.placeholder", comment: "")
    return searchController
  }()

  private var sortDescriptor = SortDescriptor.title
  @IBOutlet private weak var sortButton: UIBarButtonItem!

  private lazy var emptyLibraryView: GenericEmptyView = {
    let view = GenericEmptyView()
    view.configure(
        accessory: .image(#imageLiteral(resourceName: "EmptyLibrary")),
        description: .basic(NSLocalizedString("library.empty", comment: ""))
    )
    return view
  }()
}

// MARK: View Controller Lifecycle

extension MovieListController {
  override func viewDidLoad() {
    super.viewDidLoad()
    title = NSLocalizedString("library", comment: "")
    tableView.sectionIndexBackgroundColor = UIColor.clear
    definesPresentationContext = true
    navigationItem.hidesSearchBarWhenScrolling = false

    library.delegates.add(self)
    reloadListData()
  }
}

// MARK: - Data Management

extension MovieListController {
  private func reloadListData() {
    fetchLibraryData()
    tableView.reloadData()
    if allItems.isEmpty {
      showEmptyView()
    } else {
      hideEmptyView()
      tableView.setContentOffset(CGPoint(x: 0, y: -tableView.safeAreaInsets.top), animated: false)
    }
  }

  private func fetchLibraryData() {
    allItems = library.mediaItems { _ in true }
    allItems.sort(by: SortDescriptor.title.makeTableViewStrategy().itemSorting)
    sectionItems = [String: [MediaItem]]()
    let strategy = sortDescriptor.makeTableViewStrategy()
    for item in allItems {
      let sectionIndexTitle = strategy.sectionIndexTitle(for: item)
      if sectionItems[sectionIndexTitle] == nil {
        sectionItems[sectionIndexTitle] = [MediaItem]()
      }
      sectionItems[sectionIndexTitle]!.append(item)
    }
    for key in sectionItems.keys {
      sectionItems[key]!.sort(by: strategy.itemSorting)
    }
    sectionIndexTitles = Array(sectionItems.keys)
    sectionIndexTitles.sort(by: strategy.sectionIndexTitleSorting)
    visibleSectionIndexTitles = strategy.refineSectionIndexTitles(sectionIndexTitles)
    sectionTitles = sectionIndexTitles.map { strategy.sectionTitle(for: $0) }
  }
}

// MARK: - Empty View

extension MovieListController {
  private func showEmptyView() {
    tableView.backgroundView = emptyLibraryView
    tableView.separatorStyle = .none
    sortButton.isEnabled = false
    searchController.isActive = false
    navigationItem.searchController = nil
  }

  private func hideEmptyView() {
    tableView.backgroundView = nil
    tableView.separatorStyle = .singleLine
    sortButton.isEnabled = true
    navigationItem.searchController = searchController
  }
}

// MARK: - Table View

extension MovieListController {
  override func numberOfSections(in tableView: UITableView) -> Int {
    return sectionIndexTitles.count
  }

  private func item(for indexPath: IndexPath) -> MediaItem {
    return sectionItems[sectionIndexTitles[indexPath.section]]![indexPath.row]
  }

  public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return sectionTitles[section]
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return sectionItems[sectionIndexTitles[section]]!.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let config = self.cellConfiguration else {
      fatalError("cell configuration has not been specified")
    }
    return config.cell(for: item(for: indexPath), cellDequeuing: tableView)
  }

  public override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 75
  }

  public override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
    guard !self.allItems.isEmpty else { return nil }
    guard visibleSectionIndexTitles.count > 2 else {
      return nil
    }
    return visibleSectionIndexTitles
  }

  public override func tableView(_ tableView: UITableView,
                                 sectionForSectionIndexTitle title: String,
                                 at index: Int) -> Int {
    return sectionIndexTitles.index(of: title) ?? -1
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if let selectedIndexPath = tableView.indexPathForSelectedRow {
      self.delegate?.movieListController(self, didSelect: item(for: selectedIndexPath))
    }
  }
}

// MARK: - Search

extension MovieListController: UISearchResultsUpdating {
  func updateSearchResults(for searchController: UISearchController) {
    guard searchController.isActive else { return }
    guard let resultsController = searchController.searchResultsController as? MovieListSearchResultsController else {
      preconditionFailure("unexpected SearchResultsController class")
    }
    let searchText = searchController.searchBar.text ?? ""
    let lowercasedSearchText = searchText.lowercased()
    resultsController.searchText = searchText
    resultsController.items = allItems.filter { $0.fullTitle.lowercased().contains(lowercasedSearchText) }
  }
}

// MARK: - Library Events

extension MovieListController: MediaLibraryDelegate {
  func library(_ library: MediaLibrary, didUpdateContent contentUpdate: MediaLibraryContentUpdate) {
    DispatchQueue.main.async {
      self.reloadListData()
    }
  }
}

// MARK: - User Actions

extension MovieListController {
  @IBAction func showSortDescriptorSheet() {
    let controller = TabularSheetController<SelectableLabelSheetItem>(cellConfig: SelectableLabelCellConfig())
    for descriptor in [SortDescriptor.title, .runtime, .year] {
      controller.addSheetItem(SelectableLabelSheetItem(title: descriptor.localizedName,
                                                       showCheckmark: descriptor == self.sortDescriptor) { _ in
        guard self.sortDescriptor != descriptor else { return }
        self.sortDescriptor = descriptor
        DispatchQueue.main.async {
          self.reloadListData()
        }
      })
    }
    self.present(controller, animated: true)
  }
}
