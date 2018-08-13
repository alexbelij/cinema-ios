import CinemaKit
import Foundation
import UIKit

class CoreCoordinator: CustomPresentableCoordinator {
  // coordinator stuff
  var rootViewController: UIViewController {
    return tabBarController
  }

  // other properties
  private let dependencies: AppDependencies
  private let libraryManager: MovieLibraryManager
  private var library: MovieLibrary
  private let tabBarController = UITabBarController()

  // child coordinators
  private let libraryContentCoordinator: LibraryContentCoordinator
  private let genreListCoordinator: GenreListCoordinator
  private let searchTmdbCoordinator: SearchTmdbCoordinator
  private var librarySettingsCoordinator: LibraryListCoordinator?

  init(for library: MovieLibrary, dependencies: AppDependencies) {
    self.dependencies = dependencies
    self.libraryManager = dependencies.libraryManager
    self.library = library
    let libraryContentNav = UINavigationController()
    libraryContentCoordinator = LibraryContentCoordinator(for: library,
                                                          displaying: .all,
                                                          navigationController: libraryContentNav,
                                                          dependencies: dependencies)
    libraryContentCoordinator.showsLibrarySwitch = true
    libraryContentNav.tabBarItem = UITabBarItem(
        title: NSLocalizedString("library", comment: ""),
        image: #imageLiteral(resourceName: "Tab-Library-normal"),
        selectedImage: #imageLiteral(resourceName: "Tab-Library-selected")
    )
    libraryContentCoordinator.presentRootViewController()

    genreListCoordinator = GenreListCoordinator(for: library, dependencies: dependencies)
    genreListCoordinator.rootViewController.tabBarItem = UITabBarItem(
        title: NSLocalizedString("genres", comment: ""),
        image: #imageLiteral(resourceName: "Tab-Genre-normal"),
        selectedImage: #imageLiteral(resourceName: "Tab-Genre-selected")
    )

    searchTmdbCoordinator = SearchTmdbCoordinator(for: library, using: dependencies.movieDb)
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
    DispatchQueue.global(qos: .userInitiated).async {
      self.libraryManager.fetchLibraries { result in
        switch result {
          case let .failure(error):
            fatalError("unable to fetch libraries: \(error)")
          case let .success(libraries):
            DispatchQueue.main.async {
              self.showLibrarySheet(for: libraries)
            }
        }
      }
    }
  }

  private func showLibrarySheet(for libraries: [MovieLibrary]) {
    let controller = TabularSheetController<SelectableLabelSheetItem>(cellConfig: SelectableLabelCellConfig())
    libraries.sorted(by: StandardSortDescriptors.byLibraryName)
             .forEach { library in
               let isCurrentLibrary = self.library.metadata.id == library.metadata.id
               controller.addSheetItem(SelectableLabelSheetItem(title: library.metadata.name,
                                                                showCheckmark: isCurrentLibrary) { _ in
                 self.switchLibrary(to: library)
               })
             }
    controller.addSheetItem(SelectableLabelSheetItem(title: NSLocalizedString("core.librarySettings", comment: ""),
                                                     showCheckmark: false) { _ in
      self.librarySettingsCoordinator = LibraryListCoordinator(dependencies: self.dependencies)
      self.tabBarController.present(self.librarySettingsCoordinator!.rootViewController, animated: true)
    })
    self.tabBarController.present(controller, animated: true)
  }

  private func switchLibrary(to newLibrary: MovieLibrary) {
    if library.metadata.id == newLibrary.metadata.id { return }
    DispatchQueue.main.async {
      self.library = newLibrary
      self.libraryContentCoordinator.library = newLibrary
      self.genreListCoordinator.library = newLibrary
      self.searchTmdbCoordinator.library = newLibrary
    }
  }

  func libraryContentCoordinatorDidDismiss(_ coordinator: LibraryContentCoordinator) {
    fatalError("root should not be dismissed")
  }
}
