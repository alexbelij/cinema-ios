import Dispatch
import UIKit

protocol MovieListControllerDelegate: class {
  func movieListController(_ controller: MovieListController, didSelect item: MediaItem)
}

class MovieListItem {
  let movie: MediaItem
  var image: Image

  init(movie: MediaItem) {
    self.movie = movie
    self.image = .unknown
  }

  enum Image {
    case unknown
    case available(UIImage)
    case unavailable
  }
}

protocol MediaItemCellConfig {
  func registerCells(in cellRegistering: CellRegistering)
  func cell(for item: MovieListItem, cellDequeuing: CellDequeuing) -> UITableViewCell
}

class MovieListController: UITableViewController {
  weak var delegate: MovieListControllerDelegate?
  var items = [MediaItem]() {
    didSet {
      loadViewIfNeeded()
      reloadListData()
    }
  }

  var cellConfiguration: MediaItemCellConfig? {
    didSet {
      loadViewIfNeeded()
      cellConfiguration?.registerCells(in: tableView)
    }
  }
  private var sectioningWrapper: SectioningWrapper!

  private let titleSortingStrategy = SortDescriptor.title.makeTableViewStrategy()
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

  private let emptyLibraryView = GenericEmptyView(accessory: .image(#imageLiteral(resourceName: "EmptyLibrary")),
                                                  description: .basic(NSLocalizedString("library.empty", comment: "")))
}

// MARK: View Controller Lifecycle

extension MovieListController {
  override func viewDidLoad() {
    super.viewDidLoad()
    title = NSLocalizedString("library", comment: "")
    tableView.sectionIndexBackgroundColor = UIColor.clear
    definesPresentationContext = true
    navigationItem.hidesSearchBarWhenScrolling = false
    reloadListData()
  }
}

// MARK: - Data Management

extension MovieListController {
  private func reloadListData() {
    sectioningWrapper = SectioningWrapper(items, sortingStrategy: sortDescriptor.makeTableViewStrategy())
    tableView.reloadData()
    if items.isEmpty {
      showEmptyView()
    } else {
      hideEmptyView()
      tableView.setContentOffset(CGPoint(x: 0, y: -tableView.safeAreaInsets.top), animated: false)
      if searchController.isActive {
        updateSearchResults(for: searchController)
      }
    }
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
    return sectioningWrapper.numberOfSections
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return sectioningWrapper.numberOfRowsInSection(section)
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let config = self.cellConfiguration else {
      fatalError("cell configuration has not been specified")
    }
    return config.cell(for: sectioningWrapper.item(at: indexPath), cellDequeuing: tableView)
  }

  public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return sectioningWrapper.titleForHeaderInSection(section)
  }

  public override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
    return sectioningWrapper.sectionIndexTitles
  }

  public override func tableView(_ tableView: UITableView,
                                 sectionForSectionIndexTitle title: String,
                                 at index: Int) -> Int {
    return sectioningWrapper.sectionForSectionIndexTitle(title, at: index)
  }

  public override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 75
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    self.delegate?.movieListController(self, didSelect: sectioningWrapper.item(at: indexPath).movie)
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
    resultsController.items = sectioningWrapper.filtered { $0.fullTitle.lowercased().contains(lowercasedSearchText) }
                                               .sorted {
                                                 titleSortingStrategy.itemSorting(left: $0.movie, right: $1.movie)
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

private class SectioningWrapper {
  private struct Section {
    let indexTitle: String?
    let title: String?
    let rows: [MovieListItem]?

    // standard section
    init(indexTitle: String, title: String, rows: [MovieListItem]) {
      self.indexTitle = indexTitle
      self.title = title
      self.rows = rows
    }

    // section index is shown, but no corresponding data
    init(indexTitle: String) {
      self.indexTitle = indexTitle
      self.title = nil
      self.rows = nil
    }

    // appended at the end
    init(title: String, rows: [MovieListItem]) {
      self.indexTitle = nil
      self.title = title
      self.rows = rows
    }
  }

  private let sections: [Section]

  init(_ items: [MediaItem], sortingStrategy: SectionSortingStrategy) {
    var sections = [Section]()
    let sectionData: [String: [MediaItem]] = Dictionary(grouping: items) { sortingStrategy.sectionIndexTitle(for: $0) }
    let existingSectionIndexTitles = Array(sectionData.keys).sorted(by: sortingStrategy.sectionIndexTitleSorting)
    let refinedSectionIndexTitles = sortingStrategy.refineSectionIndexTitles(existingSectionIndexTitles)
    for index in refinedSectionIndexTitles.startIndex..<refinedSectionIndexTitles.endIndex {
      let indexTitle = refinedSectionIndexTitles[index]
      if existingSectionIndexTitles.contains(indexTitle) {
        sections.append(Section(indexTitle: indexTitle,
                                title: sortingStrategy.sectionTitle(for: indexTitle),
                                rows: sectionData[indexTitle]!.sorted(by: sortingStrategy.itemSorting)
                                                              .map { MovieListItem(movie: $0) }))
      } else {
        sections.append(Section(indexTitle: indexTitle))
      }
    }
    let additionalIndexTitles = Set(existingSectionIndexTitles).subtracting(Set(refinedSectionIndexTitles))
    for indexTitle in additionalIndexTitles {
      sections.append(Section(title: sortingStrategy.sectionTitle(for: indexTitle),
                              rows: sectionData[indexTitle]!.sorted(by: sortingStrategy.itemSorting)
                                                            .map { MovieListItem(movie: $0) }))
    }
    self.sections = sections
  }

  func item(at indexPath: IndexPath) -> MovieListItem {
    guard let item = sections[indexPath.section].rows?[indexPath.row] else {
      fatalError("accessing invalid row \(indexPath.row) in section \(indexPath)")
    }
    return item
  }

  var numberOfSections: Int {
    return sections.count
  }

  func numberOfRowsInSection(_ section: Int) -> Int {
    guard let rows = sections[section].rows else { return 0 }
    return rows.count
  }

  func titleForHeaderInSection(_ section: Int) -> String? {
    guard let title = sections[section].title else { return nil }
    return title
  }

  lazy var sectionIndexTitles: [String]? = {
    let titles = sections.flatMap { $0.indexTitle }
    return titles.isEmpty ? nil : titles
  }()

  func sectionForSectionIndexTitle(_ title: String, at index: Int) -> Int {
    return sections[index].rows == nil ? -1 : index
  }

  func filtered(by filter: (MediaItem) -> Bool) -> [MovieListItem] {
    let allItems: [MovieListItem] = sections.flatMap { $0.rows ?? [] }
    return allItems.filter { filter($0.movie) }
  }
}
