import Dispatch
import Foundation
import UIKit

class LibraryContentCoordinator: CustomPresentableCoordinator {
  var rootViewController: UIViewController {
    return navigationController
  }
  // other properties
  private let library: MediaLibrary
  private let movieDb: MovieDbClient

  // managed controllers
  private let navigationController: UINavigationController
  private let movieListController: MovieListController

  // child coordinators
  private var itemDetailsCoordinator: ItemDetailsCoordinator?

  init(library: MediaLibrary, movieDb: MovieDbClient) {
    self.library = library
    self.movieDb = movieDb
    // swiftlint:disable force_cast
    self.navigationController = UIStoryboard.movieList.instantiateInitialViewController() as! UINavigationController
    self.movieListController = navigationController.topViewController! as! MovieListController
    // swiftlint:enable force_cast
    movieListController.delegate = self
    let posterProvider = MovieDbPosterProvider(movieDb)
    movieListController.cellConfiguration = StandardMediaItemCellConfig(posterProvider: posterProvider)
    movieListController.items = library.mediaItems { _ in true }
    library.delegates.add(self)
  }
}

// MARK: - MovieListControllerDelegate

extension LibraryContentCoordinator: MovieListControllerDelegate {
  func movieListController(_ controller: MovieListController, didSelect item: MediaItem) {
    itemDetailsCoordinator = ItemDetailsCoordinator(navigationController: navigationController,
                                                    library: library,
                                                    movieDb: movieDb,
                                                    detailItem: item)
    itemDetailsCoordinator!.delegate = self
    itemDetailsCoordinator!.presentRootViewController()
  }
}

// MARK: - ItemDetailsCoordinatorDelegate

extension LibraryContentCoordinator: ItemDetailsCoordinatorDelegate {
  func itemDetailsCoordinatorDidDismiss(_ coordinator: ItemDetailsCoordinator) {
    self.itemDetailsCoordinator = nil
  }
}

// MARK: - Library Events

extension LibraryContentCoordinator: MediaLibraryDelegate {
  func library(_ library: MediaLibrary, didUpdateContent contentUpdate: MediaLibraryContentUpdate) {
    DispatchQueue.global(qos: .background).async {
      let items = library.mediaItems { _ in true }
      DispatchQueue.main.async {
        self.movieListController.items = items
      }
    }
  }
}

class StandardMediaItemCellConfig: MediaItemCellConfig {
  private let posterProvider: PosterProvider

  init(posterProvider: PosterProvider) {
    self.posterProvider = posterProvider
  }

  func registerCells(in cellRegistering: CellRegistering) {
    cellRegistering.registerNibCell(MovieListTableCell.self, bundle: nil)
  }

  func cell(for item: MovieListItem, cellDequeuing: CellDequeuing) -> UITableViewCell {
    let cell = cellDequeuing.dequeueReusableCell(MovieListTableCell.self)
    cell.configure(for: item, posterProvider: posterProvider)
    return cell
  }
}
