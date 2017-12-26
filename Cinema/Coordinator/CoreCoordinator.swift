import Foundation
import UIKit

class CoreCoordinator: CustomPresentableCoordinator {
  // coordinator stuff
  var rootViewController: UIViewController {
    return tabBarController
  }

  // other properties
  private let library: MediaLibrary
  private let movieDb: MovieDbClient
  private let tabBarController = UITabBarController()

  // child coordinators
  private let libraryContentCoordinator: LibraryContentCoordinator

  init(library: MediaLibrary, movieDb: MovieDbClient) {
    self.library = library
    self.movieDb = movieDb

    libraryContentCoordinator = LibraryContentCoordinator(library: library, movieDb: movieDb)
    libraryContentCoordinator.rootViewController.tabBarItem = UITabBarItem(
        title: NSLocalizedString("library", comment: ""),
        image: #imageLiteral(resourceName: "Tab-Library-normal"),
        selectedImage: #imageLiteral(resourceName: "Tab-Library-selected")
    )

    // swiftlint:disable force_cast
    let addItemNavController = UIStoryboard.addItem.instantiateInitialViewController() as! UINavigationController
    let searchController = addItemNavController.topViewController as! SearchTmdbController
    // swiftlint:enable force_cast
    searchController.library = library
    searchController.movieDb = movieDb
    addItemNavController.tabBarItem = UITabBarItem(title: NSLocalizedString("addItem.title", comment: ""),
                                                   image: #imageLiteral(resourceName: "Tab-AddItem-normal"),
                                                   selectedImage: #imageLiteral(resourceName: "Tab-AddItem-selected"))

    tabBarController.viewControllers = [libraryContentCoordinator.rootViewController,
                                        addItemNavController]
  }
}
