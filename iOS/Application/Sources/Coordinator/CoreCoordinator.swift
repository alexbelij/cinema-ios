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
  private let genreListCoordinator: GenreListCoordinator
  private let searchTmdbCoordinator: SearchTmdbCoordinator

  init(dependencies: Dependencies) {
    let libraryContentNav = UINavigationController()
    libraryContentCoordinator = LibraryContentCoordinator(navigationController: libraryContentNav,
                                                          content: .all,
                                                          dependencies: dependencies)
    libraryContentNav.tabBarItem = UITabBarItem(
        title: NSLocalizedString("library", comment: ""),
        image: #imageLiteral(resourceName: "Tab-Library-normal"),
        selectedImage: #imageLiteral(resourceName: "Tab-Library-selected")
    )
    libraryContentCoordinator.presentRootViewController()

    genreListCoordinator = GenreListCoordinator(dependencies: dependencies)
    genreListCoordinator.rootViewController.tabBarItem = UITabBarItem(
        title: NSLocalizedString("genres", comment: ""),
        image: #imageLiteral(resourceName: "Tab-Genre-normal"),
        selectedImage: #imageLiteral(resourceName: "Tab-Genre-selected")
    )

    searchTmdbCoordinator = SearchTmdbCoordinator(dependencies: dependencies)
    searchTmdbCoordinator.rootViewController.tabBarItem = UITabBarItem(
        title: NSLocalizedString("addMovie.title", comment: ""),
        image: #imageLiteral(resourceName: "Tab-AddMovie-normal"),
        selectedImage: #imageLiteral(resourceName: "Tab-AddMovie-selected")
    )

    tabBarController.viewControllers = [libraryContentNav,
                                        genreListCoordinator.rootViewController,
                                        searchTmdbCoordinator.rootViewController]
  }
}
