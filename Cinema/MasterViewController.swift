import Dispatch
import UIKit

class MasterViewController: UITableViewController, UISearchResultsUpdating, UISearchControllerDelegate,
    ListOptionsViewControllerDelegate {

  var library: MediaLibrary!
  var movieDb: MovieDbClient!

  private var allItems = [MediaItem]()
  private var filteredMediaItems = [MediaItem]()

  private var sectionItems = [String: [MediaItem]]()
  private var sectionIndexTitles = [String]()
  private var visibleSectionIndexTitles = [String]()
  private var sectionTitles = [String]()

  private let searchController: UISearchController = UISearchController(searchResultsController: nil)

  private var sortDescriptor = SortDescriptor.title

  @IBOutlet private weak var sortButton: UIBarButtonItem!
  @IBOutlet private var emptyView: UIView!
  @IBOutlet private weak var emptyViewLabel: UILabel!

  private var state: State = .initializing

  private var addSearchBarOnViewDidAppear = false

  override func viewDidLoad() {
    fetchLibraryData()
    super.viewDidLoad()
    title = NSLocalizedString("library", comment: "")
    emptyViewLabel.text = NSLocalizedString("library.empty", comment: "")
    searchController.searchResultsUpdater = self
    searchController.dimsBackgroundDuringPresentation = false
    searchController.delegate = self
    definesPresentationContext = true
    searchController.searchBar.placeholder = NSLocalizedString("library.search.placeholder", comment: "")
    tableView.sectionIndexBackgroundColor = UIColor.clear
    if #available(iOS 11.0, *) {
    } else {
      tableView.setContentOffset(CGPoint(x: 0, y: searchController.searchBar.frame.height), animated: false)
    }
    clearsSelectionOnViewWillAppear = true

    NotificationCenter.default.addObserver(self,
                                           selector: #selector(reloadLibraryData),
                                           name: .didChangeMediaLibraryContent,
                                           object: nil)
    showEmptyViewIfNecessary()
  }

  private func fetchLibraryData() {
    let strategy = sortDescriptor.tableViewStrategy
    allItems = library.mediaItems { _ in true }
    allItems.sort(by: SortDescriptor.title.tableViewStrategy.itemSorting)
    sectionItems = [String: [MediaItem]]()
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
    if #available(iOS 11.0, *) {
      visibleSectionIndexTitles = strategy.refineSectionIndexTitles(sectionIndexTitles)
    } else {
      visibleSectionIndexTitles = [UITableViewIndexSearch] + strategy.refineSectionIndexTitles(sectionIndexTitles)
    }
    sectionTitles = sectionIndexTitles.map { strategy.sectionTitle(for: $0) }
  }

  private func showEmptyViewIfNecessary() {
    if self.allItems.isEmpty {
      switch state {
        case .initializing, .data, .searching:
          self.tableView.backgroundView = emptyView
          self.tableView.separatorStyle = .none
          self.searchController.isActive = false
          if #available(iOS 11.0, *) {
            self.navigationItem.searchController = nil
          } else {
            self.tableView.tableHeaderView = nil
          }
          self.sortButton.isEnabled = false
          self.state = .noData
        case .noData: break
      }
    } else {
      switch state {
        case .initializing, .noData:
          self.tableView.backgroundView = nil
          self.tableView.separatorStyle = .singleLine
          if #available(iOS 11.0, *) {
            self.addSearchBarOnViewDidAppear = true
          } else {
            self.tableView.tableHeaderView = self.searchController.searchBar
          }
          self.sortButton.isEnabled = true
          self.state = .data
        case .data: fallthrough
        case .searching: break
      }
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if #available(iOS 11.0, *) {
      if addSearchBarOnViewDidAppear {
        self.navigationItem.searchController = searchController
        self.navigationItem.hidesSearchBarWhenScrolling = false
        addSearchBarOnViewDidAppear = false
      }
    }
  }

  @objc
  private func reloadLibraryData() {
    fetchLibraryData()
    DispatchQueue.main.async {
      self.showEmptyViewIfNecessary()
      self.tableView.reloadData()
    }
  }

  // MARK: - Segues

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    switch segue.unwrappedDestination {
      case let detailVC as DetailViewController:
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
          detailVC.detailItem = item(for: selectedIndexPath)
          detailVC.movieDb = movieDb
          detailVC.library = library
        }
      case let listOptionsVC as ListOptionsViewController:
        listOptionsVC.selectedDescriptor = self.sortDescriptor
        listOptionsVC.delegate = self
      default: fatalError("Unexpected segue: '\(self)' -> '\(segue.destination)'")
    }
  }

  func sortDescriptorDidChange(to descriptor: SortDescriptor) {
    self.sortDescriptor = descriptor
    DispatchQueue.global(qos: .userInitiated).async {
      self.reloadLibraryData()
      DispatchQueue.main.async {
        self.scrollToTop(animated: false)
      }
    }
  }

  private func scrollToTop(animated: Bool) {
    let topHeight = UIApplication.shared.statusBarFrame.height + navigationController!.navigationBar.frame.height
    let offset = searchController.searchBar.frame.height - topHeight
    self.tableView.setContentOffset(CGPoint(x: 0, y: offset), animated: animated)
  }

  // MARK: - Table View

  private func item(for indexPath: IndexPath) -> MediaItem {
    if searchController.isActive {
      if searchController.searchBar.text == "" {
        return allItems[indexPath.row]
      } else {
        return filteredMediaItems[indexPath.row]
      }
    } else {
      return sectionItems[sectionIndexTitles[indexPath.section]]![indexPath.row]
    }
  }

  override func numberOfSections(in tableView: UITableView) -> Int {
    return searchController.isActive ? 1 : sectionIndexTitles.count
  }

  public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return searchController.isActive ? nil : sectionTitles[section]
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if searchController.isActive {
      if searchController.searchBar.text == "" {
        return allItems.count
      } else {
        return filteredMediaItems.count
      }
    } else {
      return sectionItems[sectionIndexTitles[section]]!.count
    }
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    // swiftlint:disable:next force_cast
    let cell = tableView.dequeueReusableCell(withIdentifier: "MovieTableCell", for: indexPath) as! MovieTableCell

    let mediaItem = item(for: indexPath)
    cell.titleLabel!.text = mediaItem.fullTitle
    cell.runtimeLabel!.text = mediaItem.runtime == nil
        ? NSLocalizedString("details.missing.runtime", comment: "")
        : Utils.formatDuration(mediaItem.runtime!)
    cell.posterView.image = .genericPosterImage(minWidth: cell.posterView.frame.size.width)
    DispatchQueue.global(qos: .userInteractive).async {
      if let poster = self.movieDb.poster(for: mediaItem.id, size: PosterSize(minWidth: 46)) {
        DispatchQueue.main.async {
          (tableView.cellForRow(at: indexPath) as? MovieTableCell)?.posterView.image = poster
        }
      }
    }

    return cell
  }

  public override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 75
  }

  public override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
    guard !self.allItems.isEmpty else { return nil }
    guard visibleSectionIndexTitles.count > 2 else {
      return nil
    }
    return searchController.isActive ? nil : visibleSectionIndexTitles
  }

  public override func tableView(_ tableView: UITableView,
                                 sectionForSectionIndexTitle title: String,
                                 at index: Int) -> Int {
    if title == UITableViewIndexSearch {
      let frame = searchController.searchBar.frame
      tableView.scrollRectToVisible(frame, animated: false)
      return -1
    } else {
      return sectionIndexTitles.index(of: title) ?? -1
    }
  }

  public func updateSearchResults(for searchController: UISearchController) {
    let lowercasedSearchText = searchController.searchBar.text!.lowercased()
    filteredMediaItems = allItems.filter { $0.fullTitle.lowercased().contains(lowercasedSearchText) }

    tableView.reloadData()
  }

  func willPresentSearchController(_ searchController: UISearchController) {
    state = .searching
  }

  func willDismissSearchController(_ searchController: UISearchController) {
    state = allItems.isEmpty ? .noData : .data
  }

  private enum State {
    case initializing
    case noData
    case data
    case searching
  }
}

class MovieTableCell: UITableViewCell {
  @IBOutlet fileprivate weak var posterView: UIImageView!
  @IBOutlet fileprivate weak var titleLabel: UILabel!
  @IBOutlet fileprivate weak var runtimeLabel: UILabel!

  override func awakeFromNib() {
    super.awakeFromNib()
    posterView.layer.borderColor = #colorLiteral(red:0.0, green:0.0, blue:0.0, alpha:0.2).cgColor
    posterView.layer.borderWidth = 0.5
  }
}
