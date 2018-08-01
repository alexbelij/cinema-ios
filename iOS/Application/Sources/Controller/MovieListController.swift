import CinemaKit
import Dispatch
import UIKit

protocol MovieListControllerDelegate: class {
  func movieListController(_ controller: MovieListController, didSelect item: MediaItem)
  func movieListControllerDidDismiss(_ controller: MovieListController)
}

class MovieListController: UITableViewController {
  enum ListData {
    case loading
    case available([MediaItem])
  }

  final class ListItem: PosterHaving {
    let movie: MediaItem
    var poster: ImageState

    init(_ movie: MediaItem) {
      self.movie = movie
      self.poster = .unknown
    }

    var tmdbID: TmdbIdentifier {
      return movie.tmdbID
    }
  }

  weak var delegate: MovieListControllerDelegate?
  var listData: ListData = .loading {
    didSet {
      loadViewIfNeeded()
      setup()
    }
  }
  var posterProvider: PosterProvider = EmptyPosterProvider()
  private var viewModel: ViewModel!

  private let titleSortingStrategy = SortDescriptor.title.makeTableViewStrategy()
  private lazy var searchController: UISearchController = {
    let searchController = UISearchController(searchResultsController: resultsController)
    searchController.searchResultsUpdater = self
    searchController.dimsBackgroundDuringPresentation = false
    searchController.searchBar.placeholder = NSLocalizedString("library.search.placeholder", comment: "")
    return searchController
  }()
  private lazy var resultsController: GenericSearchResultsController<MovieListController.ListItem> = {
    let resultsController = GenericSearchResultsController<MovieListController.ListItem>(
        cell: MovieListListItemTableCell.self,
        estimatedRowHeight: MovieListListItemTableCell.rowHeight)
    resultsController.onSelection = { [delegate] selectedItem in
      delegate?.movieListController(self, didSelect: selectedItem.movie)
    }
    resultsController.cellConfiguration = { [posterProvider] tableView, indexPath, listItem in
      let cell: MovieListListItemTableCell = tableView.dequeueReusableCell(for: indexPath)
      cell.configure(for: listItem, posterProvider: posterProvider) {
        guard let rowIndex = resultsController.items.index(where: { $0.movie.tmdbID == listItem.movie.tmdbID })
            else { return }
        tableView.reloadRowWithoutAnimation(at: IndexPath(row: rowIndex, section: 0))
      }
      return cell
    }
    return resultsController
  }()

  private var sortDescriptor = SortDescriptor.title
  @IBOutlet private weak var sortButton: UIBarButtonItem!

  @IBOutlet private var summaryView: UIView!
  @IBOutlet private var movieCountLabel: UILabel!

  var onViewDidAppear: (() -> Void)?
}

// MARK: View Controller Lifecycle

extension MovieListController {
  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.register(MovieListListItemTableCell.self)
    tableView.estimatedRowHeight = MovieListListItemTableCell.rowHeight
    tableView.prefetchDataSource = self
    tableView.sectionIndexBackgroundColor = UIColor.clear
    definesPresentationContext = true
    setup()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    self.onViewDidAppear?()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    if isMovingFromParentViewController {
      self.delegate?.movieListControllerDidDismiss(self)
    }
  }
}

// MARK: - Data Management

extension MovieListController {
  private func setup() {
    setupViewModel()
    configureBackgroundView()
    configureFooterView()
    tableView.reloadData()
    if viewModel == nil || viewModel.isEmpty {
      sortButton.isEnabled = false
      searchController.isActive = false
      navigationItem.searchController = nil
    } else {
      sortButton.isEnabled = true
      navigationItem.searchController = searchController
      if searchController.isActive {
        updateSearchResults(for: searchController)
      }
    }
    scrollToTop()
  }

  private func setupViewModel() {
    switch listData {
      case .loading:
        viewModel = nil
      case let .available(items):
        viewModel = ViewModel(items, sortingStrategy: sortDescriptor.makeTableViewStrategy())
    }
  }

  private func configureBackgroundView() {
    let backgroundView: GenericEmptyView?
    let separatorStyle: UITableViewCellSeparatorStyle
    switch listData {
      case .loading:
        backgroundView = GenericEmptyView(
            accessory: .activityIndicator,
            description: .basic(NSLocalizedString("loading", comment: ""))
        )
        separatorStyle = .none
      case let .available(items):
        if items.isEmpty {
          backgroundView = GenericEmptyView(
              accessory: .image(#imageLiteral(resourceName: "EmptyLibrary")),
              description: .basic(NSLocalizedString("library.empty", comment: ""))
          )
          separatorStyle = .none
        } else {
          backgroundView = nil
          separatorStyle = .singleLine
        }
    }
    self.tableView.backgroundView = backgroundView
    self.tableView.separatorStyle = separatorStyle
  }

  private func configureFooterView() {
    if case let .available(items) = listData, !items.isEmpty {
      let format = NSLocalizedString("movieList.summary.movieCount", comment: "")
      movieCountLabel.text = .localizedStringWithFormat(format, items.count)
      tableView.tableFooterView = summaryView
    } else {
      tableView.tableFooterView = nil
    }
  }

  private func scrollToTop() {
    tableView.setContentOffset(CGPoint(x: 0, y: -tableView.safeAreaInsets.top), animated: false)
  }
}

// MARK: - Table View

extension MovieListController: UITableViewDataSourcePrefetching {
  override func numberOfSections(in tableView: UITableView) -> Int {
    guard let viewModel = self.viewModel else { return 0 }
    return viewModel.numberOfSections
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return viewModel.numberOfRowsInSection(section)
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell: MovieListListItemTableCell = tableView.dequeueReusableCell(for: indexPath)
    let item = viewModel.item(at: indexPath)
    cell.configure(for: item, posterProvider: posterProvider) { [weak self] in
      guard let `self` = self else { return }
      guard let newIndexPath = self.viewModel.indexPath(for: item) else { return }
      tableView.reloadRowWithoutAnimation(at: newIndexPath)
    }
    return cell
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return viewModel.titleForHeaderInSection(section)
  }

  override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
    guard let viewModel = self.viewModel, !viewModel.isEmpty else { return nil }
    guard let titles = viewModel.sectionIndexTitles else { return nil }
    return [UITableViewIndexSearch] + titles
  }

  override func tableView(_ tableView: UITableView,
                          sectionForSectionIndexTitle title: String,
                          at index: Int) -> Int {
    guard title != UITableViewIndexSearch else { return -1 }
    return viewModel.sectionForSectionIndexTitle(title, at: index - 1)
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    self.delegate?.movieListController(self, didSelect: viewModel.item(at: indexPath).movie)
  }

  func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
    for indexPath in indexPaths {
      let listItem = viewModel.item(at: indexPath)
      if case .unknown = listItem.poster {
        listItem.poster = .loading
        DispatchQueue.global(qos: .background).async {
          fetchPoster(for: listItem,
                      using: self.posterProvider,
                      size: MovieListListItemTableCell.posterSize,
                      purpose: .list) { [weak self] in
            guard let `self` = self else { return }
            guard let newIndexPath = self.viewModel.indexPath(for: listItem) else { return }
            tableView.reloadRowWithoutAnimation(at: newIndexPath)
          }
        }
      }
    }
  }
}

// MARK: - Search

extension MovieListController: UISearchResultsUpdating {
  func updateSearchResults(for searchController: UISearchController) {
    guard searchController.isActive else { return }
    let searchText = searchController.searchBar.text ?? ""
    let lowercasedSearchText = searchText.lowercased()
    let searchResults = self.viewModel.filtered { $0.fullTitle.lowercased().contains(lowercasedSearchText) }
                                      .sorted { titleSortingStrategy.itemSorting(left: $0.movie, right: $1.movie) }
    resultsController.reload(searchText: searchText, searchResults: searchResults)
  }
}

// MARK: - User Actions

extension MovieListController {
  @IBAction private func showSortDescriptorSheet() {
    let controller = TabularSheetController<SelectableLabelSheetItem>(cellConfig: SelectableLabelCellConfig())
    for descriptor in [SortDescriptor.title, .runtime, .year] {
      controller.addSheetItem(SelectableLabelSheetItem(title: descriptor.localizedName,
                                                       showCheckmark: descriptor == self.sortDescriptor) { _ in
        guard self.sortDescriptor != descriptor else { return }
        self.sortDescriptor = descriptor
        DispatchQueue.main.async {
          self.setupViewModel()
          self.tableView.reloadData()
          self.scrollToTop()
        }
      })
    }
    self.present(controller, animated: true)
  }
}

private class ViewModel {
  private struct Section {
    let indexTitle: String?
    let title: String?
    let rows: [MovieListController.ListItem]?

    // standard section
    init(indexTitle: String, title: String, rows: [MovieListController.ListItem]) {
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
    init(title: String, rows: [MovieListController.ListItem]) {
      self.indexTitle = nil
      self.title = title
      self.rows = rows
    }
  }

  private let sections: [Section]
  private let indexPaths: [TmdbIdentifier: IndexPath]
  let isEmpty: Bool

  init(_ items: [MediaItem], sortingStrategy: SectionSortingStrategy) {
    var indexPaths = [TmdbIdentifier: IndexPath]()
    var sections = [Section]()
    let sectionData: [String: [MediaItem]] = Dictionary(grouping: items) { sortingStrategy.sectionIndexTitle(for: $0) }
    let existingSectionIndexTitles = Array(sectionData.keys).sorted(by: sortingStrategy.sectionIndexTitleSorting)
    let refinedSectionIndexTitles = sortingStrategy.refineSectionIndexTitles(existingSectionIndexTitles)
    for sectionIndex in refinedSectionIndexTitles.startIndex..<refinedSectionIndexTitles.endIndex {
      let indexTitle = refinedSectionIndexTitles[sectionIndex]
      if existingSectionIndexTitles.contains(indexTitle) {
        let rows: [MovieListController.ListItem] = sectionData[indexTitle]!.sorted(by: sortingStrategy.itemSorting)
                                                                           .map(MovieListController.ListItem.init)
        for rowIndex in rows.startIndex..<rows.endIndex {
          indexPaths[rows[rowIndex].movie.tmdbID] = IndexPath(row: rowIndex, section: sectionIndex)
        }
        sections.append(Section(indexTitle: indexTitle,
                                title: sortingStrategy.sectionTitle(for: indexTitle),
                                rows: rows))
      } else {
        sections.append(Section(indexTitle: indexTitle))
      }
    }
    let additionalIndexTitles = Set(existingSectionIndexTitles).subtracting(Set(refinedSectionIndexTitles))
    for indexTitle in additionalIndexTitles {
      let rows = sectionData[indexTitle]!.sorted(by: sortingStrategy.itemSorting)
                                         .map(MovieListController.ListItem.init)
      let sectionIndex = sections.count
      for rowIndex in rows.startIndex..<rows.endIndex {
        indexPaths[rows[rowIndex].movie.tmdbID] = IndexPath(row: rowIndex, section: sectionIndex)
      }
      sections.append(Section(title: sortingStrategy.sectionTitle(for: indexTitle), rows: rows))
    }
    self.sections = sections
    self.indexPaths = indexPaths
    isEmpty = items.isEmpty
  }

  func item(at indexPath: IndexPath) -> MovieListController.ListItem {
    guard let item = sections[indexPath.section].rows?[indexPath.row] else {
      fatalError("accessing invalid row \(indexPath.row) in section \(indexPath)")
    }
    return item
  }

  func indexPath(for item: MovieListController.ListItem) -> IndexPath? {
    return indexPaths[item.movie.tmdbID]
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
    let titles = sections.compactMap { $0.indexTitle }
    return titles.isEmpty ? nil : titles
  }()

  func sectionForSectionIndexTitle(_ title: String, at index: Int) -> Int {
    return sections[index].rows == nil ? -1 : index
  }

  func filtered(by filter: (MediaItem) -> Bool) -> [MovieListController.ListItem] {
    let allItems: [MovieListController.ListItem] = sections.flatMap { $0.rows ?? [] }
    return allItems.filter { filter($0.movie) }
  }
}

class MovieListListItemTableCell: UITableViewCell {
  static let rowHeight: CGFloat = 100
  static let posterSize = PosterSize(minWidth: 60)
  private static let runtimeFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .full
    formatter.allowedUnits = [.hour, .minute]
    formatter.zeroFormattingBehavior = [.dropAll]
    return formatter
  }()

  @IBOutlet private weak var posterView: UIImageView!
  @IBOutlet private weak var titleLabel: UILabel!
  @IBOutlet private weak var secondaryLabel: UILabel!
  @IBOutlet private weak var tertiaryLabel: UILabel!

  override func awakeFromNib() {
    super.awakeFromNib()
    posterView.layer.borderColor = UIColor.posterBorder.cgColor
    posterView.layer.borderWidth = 0.5
  }

  func configure(for item: MovieListController.ListItem,
                 posterProvider: PosterProvider,
                 onNeedsReload: @escaping () -> Void) {
    titleLabel.text = item.movie.fullTitle
    if let seconds = item.movie.runtime?.converted(to: UnitDuration.seconds).value {
      secondaryLabel.text = MovieListListItemTableCell.runtimeFormatter.string(from: seconds)!
    } else {
      secondaryLabel.text = NSLocalizedString("details.missing.runtime", comment: "")
    }
    tertiaryLabel.text = item.movie.diskType.localizedName
    switch item.poster {
      case .unknown:
        posterView.image = #imageLiteral(resourceName: "GenericPoster")
        item.poster = .loading
        DispatchQueue.global(qos: .userInteractive).async {
          fetchPoster(for: item,
                      using: posterProvider,
                      size: MovieListListItemTableCell.posterSize,
                      purpose: .list,
                      then: onNeedsReload)
        }
      case let .available(posterImage):
        posterView.image = posterImage
      case .loading, .unavailable:
        posterView.image = #imageLiteral(resourceName: "GenericPoster")
    }
  }
}
