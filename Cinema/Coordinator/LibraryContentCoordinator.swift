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
    movieListController.movieDb = movieDb
    movieListController.library = library
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
