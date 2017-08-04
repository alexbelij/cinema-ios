import UIKit
import Dispatch

class MasterViewController: UITableViewController, UISearchResultsUpdating, SortDescriptorViewControllerDelegate {

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

  override func viewDidLoad() {
    fetchLibraryData()
    super.viewDidLoad()
    title = NSLocalizedString("library", comment: "")
    searchController.searchResultsUpdater = self
    searchController.dimsBackgroundDuringPresentation = false
    definesPresentationContext = true
    searchController.searchBar.placeholder = NSLocalizedString("library.search.placeholder", comment: "")
    tableView.tableHeaderView = searchController.searchBar
    tableView.sectionIndexBackgroundColor = UIColor.clear
    tableView.setContentOffset(CGPoint(x: 0, y: searchController.searchBar.frame.height), animated: false)

    NotificationCenter.default.addObserver(self,
                                           selector: #selector(reloadLibraryData),
                                           name: .didChangeMediaLibraryContent,
                                           object: nil)
  }

  override func viewWillAppear(_ animated: Bool) {
    clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
    super.viewWillAppear(animated)
  }

  private func fetchLibraryData() {
    let strategy = sortDescriptor.tableViewStrategy
    allItems = library.mediaItems(where: { _ in true })
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
    visibleSectionIndexTitles = [UITableViewIndexSearch] + strategy.refineSectionIndexTitles(
        sectionIndexTitles)
    sectionTitles = sectionIndexTitles.map { strategy.sectionTitle(for: $0) }
  }

  @objc private func reloadLibraryData() {
    fetchLibraryData()
    DispatchQueue.main.async {
      self.tableView.reloadData()
    }
  }

  // MARK: - Segues

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    // swiftlint:disable force_cast
    if segue.identifier == "showDetail" {
      if let indexPath = tableView.indexPathForSelectedRow {
        let selectedItem: MediaItem
        if searchController.isActive && searchController.searchBar.text != "" {
          selectedItem = filteredMediaItems[indexPath.row]
        } else {
          selectedItem = sectionItems[sectionIndexTitles[indexPath.section]]![indexPath.row]
        }
        let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
        controller.detailItem = selectedItem
        controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
        controller.navigationItem.leftItemsSupplementBackButton = true
        controller.movieDb = movieDb
        controller.library = library
      }
    }
    if segue.identifier == "addItem" {
      let controller = segue.destination as! SearchTMDBViewController
      controller.library = library
      controller.movieDb = movieDb
    }
    if segue.identifier == "selectSortDescriptor" {
      let navigationController = segue.destination as! UINavigationController
      let controller = (navigationController).childViewControllers.last! as! SortDescriptorViewController
      controller.selectedDescriptor = self.sortDescriptor
      controller.delegate = self
    }
    // swiftlint:enable force_cast
  }

  func sortDescriptorDidChange(to descriptor: SortDescriptor) {
    self.sortDescriptor = descriptor
    DispatchQueue.global(qos: .userInitiated).async { self.reloadLibraryData() }
  }

  // MARK: - Table View

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

    let mediaItem: MediaItem
    if searchController.isActive {
      if searchController.searchBar.text != "" {
        mediaItem = filteredMediaItems[indexPath.row]
      } else {
        mediaItem = allItems[indexPath.row]
      }
    } else {
      mediaItem = sectionItems[sectionIndexTitles[indexPath.section]]![indexPath.row]
    }
    cell.titleLabel!.text = mediaItem.fullTitle
    cell.runtimeLabel!.text = mediaItem.runtime == -1
        ? NSLocalizedString("details.missing.runtime", comment: "")
        : Utils.formatDuration(mediaItem.runtime)
    cell.posterView.image = #imageLiteral(resourceName:"GenericPoster-w92")
    cell.posterView.layer.borderColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.2).cgColor
    cell.posterView.layer.borderWidth = 0.5
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
    filteredMediaItems = allItems.filter({ $0.fullTitle.lowercased().contains(lowercasedSearchText) })

    tableView.reloadData()
  }

}
