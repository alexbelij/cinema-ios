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
    libraryContentCoordinator = LibraryContentCoordinator(dependencies: dependencies)
    libraryContentCoordinator.rootViewController.tabBarItem = UITabBarItem(
        title: NSLocalizedString("library", comment: ""),
        image: #imageLiteral(resourceName: "Tab-Library-normal"),
        selectedImage: #imageLiteral(resourceName: "Tab-Library-selected")
    )

    searchTmdbCoordinator = SearchTmdbCoordinator(dependencies: dependencies)
    searchTmdbCoordinator.rootViewController.tabBarItem = UITabBarItem(
        title: NSLocalizedString("addItem.title", comment: ""),
        image: #imageLiteral(resourceName: "Tab-AddItem-normal"),
        selectedImage: #imageLiteral(resourceName: "Tab-AddItem-selected")
    )

    tabBarController.viewControllers = [libraryContentCoordinator.rootViewController,
                                        searchTmdbCoordinator.rootViewController]
  }
}
