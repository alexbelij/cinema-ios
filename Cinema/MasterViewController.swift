//
//  MasterViewController.swift
//  Cinema
//
//  Created by Martin Bauer on 17.04.17.
//  Copyright © 2017 Martin Bauer. All rights reserved.
//

import UIKit
import Dispatch

class MasterViewController: UITableViewController, UISearchResultsUpdating {

  private var library: MediaLibrary!
  private var movieDb: MovieDbClient!

  private var allItems = [MediaItem]()
  private var filteredMediaItems = [MediaItem]()

  private var sectionItems = [String: [MediaItem]]()
  private var sectionTitles = [String]()

  private var detailViewController: DetailViewController? = nil
  private let searchController: UISearchController = UISearchController(searchResultsController: nil)

  private var sortingPolicy: SortingPolicy = TitleSortingPolicy()

  override func viewDidLoad() {
    library = (UIApplication.shared.delegate as! AppDelegate).library
    movieDb = (UIApplication.shared.delegate as! AppDelegate).movieDb
    fetchLibraryData()
    super.viewDidLoad()
    if let split = splitViewController {
      let controllers = split.viewControllers
      detailViewController = (controllers[
          controllers.count - 1
          ] as! UINavigationController).topViewController as? DetailViewController
    }
    title = NSLocalizedString("library", comment: "")
    searchController.searchResultsUpdater = self
    searchController.dimsBackgroundDuringPresentation = false
    definesPresentationContext = true
    searchController.searchBar.placeholder = NSLocalizedString("library.search.placeholder", comment: "")
    tableView.tableHeaderView = searchController.searchBar

    NotificationCenter.default.addObserver(self,
                                           selector: #selector(reloadLibraryData),
                                           name: .mediaLibraryChangedContent,
                                           object: nil)
  }

  override func viewWillAppear(_ animated: Bool) {
    clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
    super.viewWillAppear(animated)
  }

  private func fetchLibraryData() {
    allItems = library.mediaItems(where: { _ in true })
    sectionItems = [String: [MediaItem]]()
    for item in allItems {
      let sectionTitle = sortingPolicy.sectionTitle(for: item)
      if sectionItems[sectionTitle] == nil {
        sectionItems[sectionTitle] = [MediaItem]()
      }
      sectionItems[sectionTitle]!.append(item)
    }
    for key in sectionItems.keys {
      sectionItems[key]!.sort(by: sortingPolicy.itemSorting)
    }
    sectionTitles = Array(sectionItems.keys)
    sectionTitles.sort(by: sortingPolicy.sectionTitleSorting)
  }

  @objc private func reloadLibraryData() {
    fetchLibraryData()
    DispatchQueue.main.async {
      self.tableView.reloadData()
    }
  }

  // MARK: - Segues

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "showDetail" {
      if let indexPath = tableView.indexPathForSelectedRow {
        let selectedItem: MediaItem
        if (searchController.isActive && searchController.searchBar.text != "") {
          selectedItem = filteredMediaItems[indexPath.row]
        } else {
          selectedItem = sectionItems[sectionTitles[indexPath.section]]![indexPath.row]
        }
        let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
        controller.detailItem = selectedItem
        controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
        controller.navigationItem.leftItemsSupplementBackButton = true
        controller.movieDb = movieDb
      }
    }
    if segue.identifier == "addItem" {
      let controller = segue.destination as! SearchTMDBViewController
      controller.library = library
      controller.movieDb = movieDb
    }
  }

  // MARK: - Table View

  override func numberOfSections(in tableView: UITableView) -> Int {
    return searchController.isActive ? 1 : sectionTitles.count
  }

  public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return searchController.isActive ? nil : sectionTitles[section]
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if (searchController.isActive) {
      if searchController.searchBar.text == "" {
        return allItems.count
      } else {
        return filteredMediaItems.count
      }
    } else {
      return sectionItems[sectionTitles[section]]!.count
    }
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! MyTableCell

    let mediaItem: MediaItem
    if (searchController.isActive) {
      if searchController.searchBar.text != "" {
        mediaItem = filteredMediaItems[indexPath.row]
      } else {
        mediaItem = allItems[indexPath.row]
      }
    } else {
      mediaItem = sectionItems[sectionTitles[indexPath.section]]![indexPath.row]
    }
    cell.titleLabel!.text = Utils.fullTitle(of: mediaItem)
    cell.runtimeLabel!.text = mediaItem.runtime == -1
        ? NSLocalizedString("details.missing.runtime", comment: "")
        : Utils.formatDuration(mediaItem.runtime)

    return cell
  }

  public override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 55
  }

  public override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
    return searchController.isActive ? nil : sectionTitles
  }

  func filterContentForSearchText(searchText: String) {
    let lowercasedSearchText = searchText.lowercased()
    filteredMediaItems = allItems.filter({ Utils.fullTitle(of: $0).lowercased().contains(lowercasedSearchText) })

    tableView.reloadData()
  }

  public func updateSearchResults(for searchController: UISearchController) {
    filterContentForSearchText(searchText: searchController.searchBar.text!)
  }

}

