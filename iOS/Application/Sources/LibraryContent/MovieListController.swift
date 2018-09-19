import CinemaKit
import Dispatch
import UIKit

protocol MovieListControllerDelegate: class {
  func movieListController(_ controller: MovieListController, didSelect movie: Movie)
  func movieListControllerDidDismiss(_ controller: MovieListController)
}

class MovieListController: UITableViewController {
  enum ListData {
    case loading
    case available([Movie])
    case unavailable
  }

  final class ListItem: PosterHaving {
    let movie: Movie
    var poster: ImageState

    init(_ movie: Movie) {
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
      guard self.isViewLoaded else { return }
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
    resultsController.onSelection = { [weak self] selectedItem in
      guard let `self` = self else { return }
      self.delegate?.movieListController(self, didSelect: selectedItem.movie)
    }
    resultsController.cellConfiguration = { [weak self] tableView, indexPath, listItem in
      guard let `self` = self else { return UITableViewCell() }
      let cell: MovieListListItemTableCell = tableView.dequeueReusableCell(for: indexPath)
      tableView.configure(cell,
                          for: listItem,
                          isSectionIndexVisible: false,
                          at: { [weak resultsController] in
                            resultsController?.items.index { $0.movie.tmdbID == listItem.movie.tmdbID }
                                                    .map { IndexPath(row: $0, section: 0) }
                          },
                          using: self.posterProvider)
      return cell
    }
    resultsController.prefetchHandler = { [weak self, weak resultsController] tableView, indexPaths in
      guard let `self` = self, let resultsController = resultsController else { return }
      for indexPath in indexPaths {
        let listItem = resultsController.items[indexPath.row]
        guard case .unknown = listItem.poster else { return }
        listItem.poster = .loading
        DispatchQueue.global(qos: .background).async {
          fetchPoster(for: listItem,
                      using: self.posterProvider,
                      size: MovieListListItemTableCell.posterSize,
                      purpose: .list) { [weak self] in
            guard let `self` = self else { return }
            tableView.reloadRow(for: listItem,
                                isSectionIndexVisible: false,
                                at: { [weak resultsController] in
                                  resultsController?.items.index { $0.movie.tmdbID == listItem.movie.tmdbID }
                                                          .map { IndexPath(row: $0, section: 0) }
                                },
                                using: self.posterProvider)
          }
        }
      }
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
    if isMovingFromParent {
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
      case .loading, .unavailable:
        viewModel = nil
      case let .available(movies):
        viewModel = ViewModel(movies, sortingStrategy: sortDescriptor.makeTableViewStrategy())
    }
  }

  private func configureBackgroundView() {
    let backgroundView: GenericEmptyView?
    let separatorStyle: UITableViewCell.SeparatorStyle
    switch listData {
      case .loading:
        backgroundView = nil
        separatorStyle = .none
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
          guard case .loading = self.listData else { return }
          self.tableView.backgroundView = GenericEmptyView(
              accessory: .activityIndicator,
              description: .detailed(title: NSLocalizedString("loading", comment: ""),
                                     message: NSLocalizedString("thisMayTakeSomeTime", comment: ""))
          )
          self.tableView.separatorStyle = .none
        }
      case let .available(movies):
        if movies.isEmpty {
          backgroundView = GenericEmptyView(
              accessory: .image(#imageLiteral(resourceName: "EmptyLibrary")),
              description: .basic(NSLocalizedString("library.empty", comment: ""))
          )
          separatorStyle = .none
        } else {
          backgroundView = nil
          separatorStyle = .singleLine
        }
      case .unavailable:
        backgroundView = GenericEmptyView(
            description: .basic(NSLocalizedString("error.genericError", comment: ""))
        )
        separatorStyle = .none
    }
    self.tableView.backgroundView = backgroundView
    self.tableView.separatorStyle = separatorStyle
  }

  private func configureFooterView() {
    if case let .available(movies) = listData, !movies.isEmpty {
      let format = NSLocalizedString("movieList.summary.movieCount", comment: "")
      movieCountLabel.text = .localizedStringWithFormat(format, movies.count)
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

extension UITableView {
  fileprivate func reloadRow(for listItem: MovieListController.ListItem,
                             isSectionIndexVisible: Bool,
                             at indexPathProvider: @escaping () -> IndexPath?,
                             using posterProvider: PosterProvider) {
    guard let indexPath = indexPathProvider() else { return }
    if let cell = cellForRow(at: indexPath) as? MovieListListItemTableCell {
      configure(cell,
                for: listItem,
                isSectionIndexVisible: isSectionIndexVisible,
                at: indexPathProvider,
                using: posterProvider)
    }
  }

  fileprivate func configure(_ cell: MovieListListItemTableCell,
                             for listItem: MovieListController.ListItem,
                             isSectionIndexVisible: Bool,
                             at indexPathProvider: @escaping () -> IndexPath?,
                             using posterProvider: PosterProvider) {
    cell.configure(for: listItem, posterProvider: posterProvider, isSectionIndexVisible: false) {
      guard let indexPath = indexPathProvider() else { return }
      if let cell = self.cellForRow(at: indexPath) as? MovieListListItemTableCell {
        self.configure(cell,
                       for: listItem,
                       isSectionIndexVisible: isSectionIndexVisible,
                       at: indexPathProvider,
                       using: posterProvider)
      }
    }
  }
}

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
    tableView.configure(cell,
                        for: item,
                        isSectionIndexVisible: true,
                        at: { [weak viewModel] in viewModel?.indexPath(for: item) },
                        using: posterProvider)
    return cell
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return viewModel.titleForHeaderInSection(section)
  }

  override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
    guard let viewModel = self.viewModel, !viewModel.isEmpty else { return nil }
    guard let titles = viewModel.sectionIndexTitles else { return nil }
    return [UITableView.indexSearch] + titles
  }

  override func tableView(_ tableView: UITableView,
                          sectionForSectionIndexTitle title: String,
                          at index: Int) -> Int {
    guard title != UITableView.indexSearch else { return -1 }
    return viewModel.sectionForSectionIndexTitle(title, at: index - 1)
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    self.delegate?.movieListController(self, didSelect: viewModel.item(at: indexPath).movie)
  }

  func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
    for indexPath in indexPaths {
      let listItem = viewModel.item(at: indexPath)
      guard case .unknown = listItem.poster else { return }
      listItem.poster = .loading
      DispatchQueue.global(qos: .background).async {
        fetchPoster(for: listItem,
                    using: self.posterProvider,
                    size: MovieListListItemTableCell.posterSize,
                    purpose: .list) { [weak self] in
          guard let `self` = self else { return }
          tableView.reloadRow(for: listItem,
                              isSectionIndexVisible: true,
                              at: { [weak viewModel = self.viewModel] in
                                viewModel?.indexPath(for: listItem)
                              },
                              using: self.posterProvider)
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
                                      .sorted { titleSortingStrategy.movieSorting(left: $0.movie, right: $1.movie) }
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

  init(_ movies: [Movie], sortingStrategy: SectionSortingStrategy) {
    var indexPaths = [TmdbIdentifier: IndexPath]()
    var sections = [Section]()
    let sectionData: [String: [Movie]] = Dictionary(grouping: movies) { sortingStrategy.sectionIndexTitle(for: $0) }
    let existingSectionIndexTitles = Array(sectionData.keys).sorted(by: sortingStrategy.sectionIndexTitleSorting)
    let refinedSectionIndexTitles = sortingStrategy.refineSectionIndexTitles(existingSectionIndexTitles)
    for sectionIndex in refinedSectionIndexTitles.startIndex..<refinedSectionIndexTitles.endIndex {
      let indexTitle = refinedSectionIndexTitles[sectionIndex]
      if existingSectionIndexTitles.contains(indexTitle) {
        let rows: [MovieListController.ListItem] = sectionData[indexTitle]!.sorted(by: sortingStrategy.movieSorting)
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
      let rows = sectionData[indexTitle]!.sorted(by: sortingStrategy.movieSorting)
                                         .map(MovieListController.ListItem.init)
      let sectionIndex = sections.count
      for rowIndex in rows.startIndex..<rows.endIndex {
        indexPaths[rows[rowIndex].movie.tmdbID] = IndexPath(row: rowIndex, section: sectionIndex)
      }
      sections.append(Section(title: sortingStrategy.sectionTitle(for: indexTitle), rows: rows))
    }
    self.sections = sections
    self.indexPaths = indexPaths
    isEmpty = movies.isEmpty
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

  func filtered(by filter: (Movie) -> Bool) -> [MovieListController.ListItem] {
    let allItems: [MovieListController.ListItem] = sections.flatMap { $0.rows ?? [] }
    return allItems.filter { filter($0.movie) }
  }
}

class MovieListListItemTableCell: UITableViewCell {
  static let rowHeight: CGFloat = 100
  static let posterSize = PosterSize(minWidth: 60)
  private static let separatorInsetsWithSectionIndex = UIEdgeInsets(top: 0, left: 80, bottom: 0, right: 16)
  private static let separatorInsetsWithoutSectionIndex = UIEdgeInsets(top: 0, left: 80, bottom: 0, right: 0)
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
                 isSectionIndexVisible: Bool,
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
        item.poster = .loading
        configurePoster(nil)
        DispatchQueue.global(qos: .userInteractive).async {
          fetchPoster(for: item,
                      using: posterProvider,
                      size: MovieListListItemTableCell.posterSize,
                      purpose: .list,
                      then: onNeedsReload)
        }
      case .loading:
        configurePoster(nil)
      case let .available(posterImage):
        configurePoster(posterImage)
      case .unavailable:
        configurePoster(#imageLiteral(resourceName: "GenericPoster"))
    }
    separatorInset = isSectionIndexVisible
        ? MovieListListItemTableCell.separatorInsetsWithSectionIndex
        : MovieListListItemTableCell.separatorInsetsWithoutSectionIndex
  }

  private func configurePoster(_ image: UIImage?) {
    posterView.image = image
    if image == nil {
      posterView.alpha = 0.0
    } else if posterView.alpha < 1.0 {
      UIView.animate(withDuration: 0.2) {
        self.posterView.alpha = 1.0
      }
    }
  }
}
