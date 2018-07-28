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

  class ListItem {
    let movie: MediaItem
    var image: Image

    init(_ movie: MediaItem) {
      self.movie = movie
      self.image = .unknown
    }

    enum Image {
      case unknown
      case loading
      case available(UIImage)
      case unavailable
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
    let resultsController = GenericSearchResultsController<MovieListController.ListItem>(
        cell: MovieListListItemTableCell.self)
    resultsController.onSelection = { [delegate] selectedItem in
      delegate?.movieListController(self, didSelect: selectedItem.movie)
    }
    resultsController.cellConfiguration = { [posterProvider] dequeuing, indexPath, listItem in
      let cell: MovieListListItemTableCell = dequeuing.dequeueReusableCell(for: indexPath)
      cell.configure(for: listItem, posterProvider: posterProvider)
      return cell
    }
    let searchController = UISearchController(searchResultsController: resultsController)
    searchController.searchResultsUpdater = self
    searchController.dimsBackgroundDuringPresentation = false
    searchController.searchBar.placeholder = NSLocalizedString("library.search.placeholder", comment: "")
    return searchController
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
    cell.configure(for: viewModel.item(at: indexPath), posterProvider: posterProvider)
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
      let movieListItem = viewModel.item(at: indexPath)
      if case .unknown = movieListItem.image {
        movieListItem.image = .loading
        DispatchQueue.global(qos: .background).async {
          let poster = self.posterProvider.poster(for: movieListItem.movie.tmdbID,
                                                  size: PosterSize(minWidth: 60),
                                                  purpose: .list)
          DispatchQueue.main.async {
            if let posterImage = poster {
              movieListItem.image = .available(posterImage)
              if let cell = tableView.cellForRow(at: indexPath) as? MovieListListItemTableCell {
                cell.configure(for: movieListItem, posterProvider: self.posterProvider)
              }
            } else {
              movieListItem.image = .unavailable
            }
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
    guard let resultsController = searchController.searchResultsController
        as? GenericSearchResultsController<MovieListController.ListItem> else {
      preconditionFailure("unexpected SearchResultsController class")
    }
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
  let isEmpty: Bool

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
                                                              .map(MovieListController.ListItem.init)))
      } else {
        sections.append(Section(indexTitle: indexTitle))
      }
    }
    let additionalIndexTitles = Set(existingSectionIndexTitles).subtracting(Set(refinedSectionIndexTitles))
    for indexTitle in additionalIndexTitles {
      sections.append(Section(title: sortingStrategy.sectionTitle(for: indexTitle),
                              rows: sectionData[indexTitle]!.sorted(by: sortingStrategy.itemSorting)
                                                            .map(MovieListController.ListItem.init)))
    }
    self.sections = sections
    isEmpty = items.isEmpty
  }

  func item(at indexPath: IndexPath) -> MovieListController.ListItem {
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
  private var workItem: DispatchWorkItem?

  override func awakeFromNib() {
    super.awakeFromNib()
    posterView.layer.borderColor = UIColor.posterBorder.cgColor
    posterView.layer.borderWidth = 0.5
  }

  func configure(for item: MovieListController.ListItem, posterProvider: PosterProvider) {
    titleLabel.text = item.movie.fullTitle
    if let seconds = item.movie.runtime?.converted(to: UnitDuration.seconds).value {
      secondaryLabel.text = MovieListListItemTableCell.runtimeFormatter.string(from: seconds)!
    } else {
      secondaryLabel.text = NSLocalizedString("details.missing.runtime", comment: "")
    }
    tertiaryLabel.text = item.movie.diskType.localizedName
    configurePoster(for: item, posterProvider: posterProvider)
  }

  private func configurePoster(for item: MovieListController.ListItem, posterProvider: PosterProvider) {
    switch item.image {
      case .unknown:
        posterView.image = #imageLiteral(resourceName: "GenericPoster")
        item.image = .loading
        let size = PosterSize(minWidth: Int(posterView.frame.size.width))
        var workItem: DispatchWorkItem?
        workItem = DispatchWorkItem {
          let poster = posterProvider.poster(for: item.movie.tmdbID, size: size, purpose: .list)
          DispatchQueue.main.async {
            if let posterImage = poster {
              item.image = .available(posterImage)
            } else {
              item.image = .unavailable
            }
            if !workItem!.isCancelled {
              self.configurePoster(for: item, posterProvider: posterProvider)
            }
          }
        }
        self.workItem = workItem
        DispatchQueue.global(qos: .userInteractive).async(execute: workItem!)
      case let .available(posterImage):
        posterView.image = posterImage
      case .loading, .unavailable:
        posterView.image = #imageLiteral(resourceName: "GenericPoster")
    }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    self.workItem?.cancel()
    self.workItem = nil
  }
}
