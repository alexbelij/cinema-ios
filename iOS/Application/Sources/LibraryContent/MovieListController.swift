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
    case available(SectionedMovieListDataSource)
    case unavailable

    var dataSource: SectionedMovieListDataSource? {
      guard case let ListData.available(dataSource) = self else {
        return nil
      }
      return dataSource
    }
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

  private let titleSorting = TitleSorting()
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
                            resultsController?.items.firstIndex { $0.movie.tmdbID == listItem.movie.tmdbID }
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
                                  resultsController?.items.firstIndex { $0.movie.tmdbID == listItem.movie.tmdbID }
                                                          .map { IndexPath(row: $0, section: 0) }
                                },
                                using: self.posterProvider)
          }
        }
      }
    }
    return resultsController
  }()

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
    configureBackgroundView()
    configureFooterView()
    tableView.reloadData()
    if let dataSource = listData.dataSource, !dataSource.isEmpty {
      navigationItem.searchController = searchController
      if searchController.isActive {
        updateSearchResults(for: searchController)
      }
    } else {
      searchController.isActive = false
      navigationItem.searchController = nil
    }
    scrollToTop()
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
      case let .available(dataSource):
        if dataSource.isEmpty {
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
    if let dataSource = listData.dataSource, !dataSource.isEmpty {
      let format = NSLocalizedString("movieList.summary.movieCount", comment: "")
      movieCountLabel.text = .localizedStringWithFormat(format, dataSource.numberOfMovies)
      tableView.tableFooterView = summaryView
    } else {
      tableView.tableFooterView = nil
    }
  }

  private func scrollToTop() {
    tableView.layoutIfNeeded()
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
    cell.configure(for: listItem,
                   posterProvider: posterProvider,
                   isSectionIndexVisible: isSectionIndexVisible) {
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
    return listData.dataSource?.numberOfSections ?? 0
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return listData.dataSource!.numberOfMovies(in: section)
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell: MovieListListItemTableCell = tableView.dequeueReusableCell(for: indexPath)
    let item = listData.dataSource!.item(at: indexPath)
    tableView.configure(cell,
                        for: item,
                        isSectionIndexVisible: true,
                        at: { [weak self] in self?.listData.dataSource?.indexPath(for: item) },
                        using: posterProvider)
    return cell
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return listData.dataSource!.titleForHeader(in: section)
  }

  override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
    guard let dataSource = listData.dataSource, !dataSource.isEmpty else { return nil }
    guard let titles = dataSource.sectionIndexTitles else { return nil }
    return [UITableView.indexSearch] + titles
  }

  override func tableView(_ tableView: UITableView,
                          sectionForSectionIndexTitle title: String,
                          at index: Int) -> Int {
    guard title != UITableView.indexSearch else { return -1 }
    return listData.dataSource!.sectionForSectionIndexTitle(title, at: index - 1)
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    self.delegate?.movieListController(self, didSelect: listData.dataSource!.item(at: indexPath).movie)
  }

  func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
    for indexPath in indexPaths {
      let listItem = listData.dataSource!.item(at: indexPath)
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
                              at: { [weak self] in self?.listData.dataSource?.indexPath(for: listItem) },
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
    let searchResults = listData.dataSource!
                                .filtered { $0.movie.fullTitle.lowercased().contains(lowercasedSearchText) }
                                .sorted(by: titleSorting.areInIncreasingOrder)
    resultsController.reload(searchText: searchText, searchResults: searchResults)
  }
}
