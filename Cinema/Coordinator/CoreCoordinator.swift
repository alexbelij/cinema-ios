import Foundation
import UIKit

class CoreCoordinator: CustomPresentableCoordinator {
  typealias Dependencies = LibraryDependency & MovieDbDependency

  // coordinator stuff
  var rootViewController: UIViewController {
    return tabBarController
  }

  // other properties
  private let tabBarController = UITabBarController()

  // child coordinators
  private let libraryContentCoordinator: LibraryContentCoordinator
  private let searchTmdbCoordinator: SearchTmdbCoordinator

  init(dependencies: Dependencies) {
    let libraryContentNav = UINavigationController()
    libraryContentCoordinator = LibraryContentCoordinator(navigationController: libraryContentNav,
                                                          title: NSLocalizedString("library", comment: ""),
                                                          dependencies: dependencies)
    libraryContentNav.tabBarItem = UITabBarItem(
        title: NSLocalizedString("library", comment: ""),
        image: #imageLiteral(resourceName: "Tab-Library-normal"),
        selectedImage: #imageLiteral(resourceName: "Tab-Library-selected")
    )
    libraryContentCoordinator.presentRootViewController()

    searchTmdbCoordinator = SearchTmdbCoordinator(dependencies: dependencies)
    searchTmdbCoordinator.rootViewController.tabBarItem = UITabBarItem(
        title: NSLocalizedString("addItem.title", comment: ""),
        image: #imageLiteral(resourceName: "Tab-AddItem-normal"),
        selectedImage: #imageLiteral(resourceName: "Tab-AddItem-selected")
    )

    tabBarController.viewControllers = [libraryContentNav,
                                        searchTmdbCoordinator.rootViewController]
  }
}
