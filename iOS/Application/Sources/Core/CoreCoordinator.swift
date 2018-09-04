import CinemaKit
import CloudKit
import Foundation
import os.log
import UIKit

class CoreCoordinator: CustomPresentableCoordinator {
  private static let logger = Logging.createLogger(category: "CoreCoordinator")

  // coordinator stuff
  var rootViewController: UIViewController {
    return tabBarController
  }

  // other properties
  private let dependencies: AppDependencies
  private let libraryManager: MovieLibraryManager
  private let notificationCenter: NotificationCenter
  private var primaryLibrary: MovieLibrary
  private let tabBarController = UITabBarController()

  // child coordinators
  private let libraryContentCoordinator: LibraryContentCoordinator
  private let genreListCoordinator: GenreListCoordinator
  private let searchTmdbCoordinator: SearchTmdbCoordinator
  private var librarySettingsCoordinator: LibraryListCoordinator?

  init(for library: MovieLibrary, dependencies: AppDependencies) {
    self.dependencies = dependencies
    self.libraryManager = dependencies.libraryManager
    self.notificationCenter = dependencies.notificationCenter
    self.primaryLibrary = library
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

    searchTmdbCoordinator = SearchTmdbCoordinator(for: primaryLibrary, dependencies: dependencies)
    searchTmdbCoordinator.rootViewController.tabBarItem = UITabBarItem(
        title: NSLocalizedString("addMovie.title", comment: ""),
        image: #imageLiteral(resourceName: "Tab-AddMovie-normal"),
        selectedImage: #imageLiteral(resourceName: "Tab-AddMovie-selected")
    )

    tabBarController.viewControllers = [libraryContentNav,
                                        genreListCoordinator.rootViewController,
                                        searchTmdbCoordinator.rootViewController]

    libraryManager.delegates.add(self)
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
            switch error {
              case let .globalError(event):
                self.notificationCenter.post(event.notification)
              case .nonRecoverableError:
                fatalError("unable to fetch libraries: \(error)")
              case .libraryDoesNotExist:
                fatalError("should not occur: \(error)")
            }
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
               let isCurrentLibrary = self.primaryLibrary.metadata.id == library.metadata.id
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
    if primaryLibrary.metadata.id == newLibrary.metadata.id { return }
    DispatchQueue.main.async {
      self.primaryLibrary = newLibrary
      self.libraryContentCoordinator.library = newLibrary
      self.genreListCoordinator.library = newLibrary
      self.searchTmdbCoordinator.library = newLibrary
    }
  }

  func libraryContentCoordinatorDidDismiss(_ coordinator: LibraryContentCoordinator) {
    fatalError("root should not be dismissed")
  }
}

extension CoreCoordinator: MovieLibraryManagerDelegate {
  func libraryManager(_ libraryManager: MovieLibraryManager,
                      didUpdateLibraries changeSet: ChangeSet<CKRecordID, MovieLibrary>) {
    DispatchQueue.main.async {
      if changeSet.deletions[self.primaryLibrary.metadata.id] != nil {
        libraryManager.fetchLibraries { result in
          switch result {
            case let .failure(error):
              os_log("unable to switch library since fetchLibraries failed: %{public}@",
                     log: CoreCoordinator.logger,
                     type: .default,
                     String(describing: error))
              fatalError("unable to switch library")
            case let .success(libraries):
              self.switchLibrary(to: libraries.first!)
          }
        }
      }
    }
  }
}
