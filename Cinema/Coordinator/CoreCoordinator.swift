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

  init(library: MediaLibrary, movieDb: MovieDbClient) {
    self.library = library
    self.movieDb = movieDb

    // swiftlint:disable force_cast
    let mainNavController = UIStoryboard.main.instantiateInitialViewController() as! UINavigationController

    let masterViewController = mainNavController.topViewController! as! MovieListController
    masterViewController.library = library
    masterViewController.movieDb = movieDb

    let addItemNavController = UIStoryboard.addItem.instantiateInitialViewController() as! UINavigationController
    let searchController = addItemNavController.topViewController as! SearchTMDBViewController
    searchController.library = library
    searchController.movieDb = movieDb
    // swiftlint:enable force_cast

    mainNavController.tabBarItem = UITabBarItem(title: NSLocalizedString("library", comment: ""),
                                                image: #imageLiteral(resourceName: "Tab-Library-normal"),
                                                selectedImage: #imageLiteral(resourceName: "Tab-Library-selected"))
    addItemNavController.tabBarItem = UITabBarItem(title: NSLocalizedString("addItem.title", comment: ""),
                                                   image: #imageLiteral(resourceName: "Tab-AddItem-normal"),
                                                   selectedImage: #imageLiteral(resourceName: "Tab-AddItem-selected"))
    tabBarController.viewControllers = [mainNavController, addItemNavController]
  }
}
