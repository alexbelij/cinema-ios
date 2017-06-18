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

  var library: MediaLibrary!
  var mediaItems = [MediaItem]()
  var filteredMediaItems = [MediaItem]()

  var detailViewController: DetailViewController? = nil
  let searchController: UISearchController = UISearchController(searchResultsController: nil)

  private var movieDb: MovieDbClient!

  override func viewDidLoad() {
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

    library = FileBasedMediaLibrary(directory: Utils.applicationSupportDirectory(),
                                    fileName: "cinema.data",
                                    dataFormat: KeyedArchivalFormat())
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(reloadLibraryData),
                                           name: .mediaLibraryChangedContent,
                                           object: nil)
    reloadLibraryData()
    movieDb = TMDBSwiftWrapper(storeFront: .germany)
    movieDb.language = MovieDbLanguage(rawValue: Locale.current.languageCode ?? "en")
    movieDb.tryConnect()
  }

  override func viewWillAppear(_ animated: Bool) {
    clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
    super.viewWillAppear(animated)
  }

  @objc private func reloadLibraryData() {
    mediaItems = library.mediaItems(where: { _ in true })
    mediaItems.sort { (left, right) in
      if left.title != right.title {
        return left.title < right.title
      } else {
        return left.year < right.year
      }
    }
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
          selectedItem = mediaItems[indexPath.row]
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
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if (searchController.isActive && searchController.searchBar.text != "") {
      return filteredMediaItems.count
    } else {
      return mediaItems.count
    }
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! MyTableCell

    let mediaItem: MediaItem
    if (searchController.isActive && searchController.searchBar.text != "") {
      mediaItem = filteredMediaItems[indexPath.row]
    } else {
      mediaItem = mediaItems[indexPath.row]
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

  func filterContentForSearchText(searchText: String) {
    let lowercasedSearchText = searchText.lowercased()
    filteredMediaItems = mediaItems.filter({ Utils.fullTitle(of: $0).lowercased().contains(lowercasedSearchText) })

    tableView.reloadData()
  }

  public func updateSearchResults(for searchController: UISearchController) {
    filterContentForSearchText(searchText: searchController.searchBar.text!)
  }

}

