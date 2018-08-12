import CinemaKit
import Foundation
import UIKit

class CoreCoordinator: CustomPresentableCoordinator {
  // coordinator stuff
  var rootViewController: UIViewController {
    return tabBarController
  }

  // other properties
  private let library: MovieLibrary
  private let tabBarController = UITabBarController()

  // child coordinators
  private let libraryContentCoordinator: LibraryContentCoordinator
  private let genreListCoordinator: GenreListCoordinator
  private let searchTmdbCoordinator: SearchTmdbCoordinator

  init(dependencies: AppDependencies) {
    self.library = dependencies.library
    let libraryContentNav = UINavigationController()
    libraryContentCoordinator = LibraryContentCoordinator(navigationController: libraryContentNav,
                                                          content: .all,
                                                          dependencies: dependencies)
    libraryContentCoordinator.showsLibrarySwitch = true
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

    libraryContentCoordinator.delegate = self
  }
}

// MARK: - Switching Libraries

extension CoreCoordinator: LibraryContentCoordinatorDelegate {
  func libraryContentCoordinatorShowLibraryList(_ coordinator: LibraryContentCoordinator) {
    let controller = TabularSheetController<SelectableLabelSheetItem>(cellConfig: SelectableLabelCellConfig())
    controller.addSheetItem(SelectableLabelSheetItem(title: library.metadata.name,
                                                     showCheckmark: true))
    self.tabBarController.present(controller, animated: true)
  }

  func libraryContentCoordinatorDidDismiss(_ coordinator: LibraryContentCoordinator) {
    fatalError("root should not be dismissed")
  }
}
