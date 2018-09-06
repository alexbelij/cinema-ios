import CinemaKit
import CloudKit
import Foundation
import os.log
import UIKit

class CoreCoordinator: CustomPresentableCoordinator {
  static let primaryLibraryKey = UserDefaultsKey<String>("primaryLibrary")
  private static let logger = Logging.createLogger(category: "CoreCoordinator")

  // coordinator stuff
  var rootViewController: UIViewController {
    return tabBarController
  }

  // other properties
  private let dependencies: AppDependencies
  private let libraryManager: MovieLibraryManager
  private let notificationCenter: NotificationCenter
  private let userDefaults: UserDefaultsProtocol
  private var primaryLibrary: MovieLibrary {
    didSet {
      dependencies.userDefaults.set(primaryLibrary.metadata.id.recordName, for: CoreCoordinator.primaryLibraryKey)
    }
  }
  private let tabBarController = UITabBarController()

  // child coordinators
  private let libraryContentNavigationController: UINavigationController
  private let libraryContentCoordinator: LibraryContentCoordinator
  private let genreListCoordinator: GenreListCoordinator
  private var searchTmdbCoordinator: SearchTmdbCoordinator?
  private var libraryListCoordinator: LibraryListCoordinator?

  init(for library: MovieLibrary, dependencies: AppDependencies) {
    self.dependencies = dependencies
    self.libraryManager = dependencies.libraryManager
    self.notificationCenter = dependencies.notificationCenter
    self.userDefaults = dependencies.userDefaults
    self.primaryLibrary = library
    libraryContentNavigationController = UINavigationController()
    libraryContentCoordinator = LibraryContentCoordinator(for: library,
                                                          displaying: .all,
                                                          navigationController: libraryContentNavigationController,
                                                          dependencies: dependencies)
    libraryContentCoordinator.showsLibrarySwitch = true
    libraryContentNavigationController.tabBarItem = UITabBarItem(
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

    libraryManager.delegates.add(self)
    libraryContentCoordinator.delegate = self
    setTabs(includeSearchTab: library.metadata.currentUserCanModify)
  }

  private func setTabs(includeSearchTab: Bool) {
    if includeSearchTab {
      searchTmdbCoordinator = SearchTmdbCoordinator(for: primaryLibrary, dependencies: dependencies)
      searchTmdbCoordinator!.rootViewController.tabBarItem = UITabBarItem(
          title: NSLocalizedString("addMovie.title", comment: ""),
          image: #imageLiteral(resourceName: "Tab-AddMovie-normal"),
          selectedImage: #imageLiteral(resourceName: "Tab-AddMovie-selected")
      )
      tabBarController.viewControllers = [libraryContentNavigationController,
                                          genreListCoordinator.rootViewController,
                                          searchTmdbCoordinator!.rootViewController]
    } else {
      searchTmdbCoordinator = nil
      tabBarController.viewControllers = [libraryContentNavigationController,
                                          genreListCoordinator.rootViewController]
    }
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
              case .libraryDoesNotExist, .permissionFailure:
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
    let config = LibrarySheetCellConfig(sharedLibraryExists: libraries.contains { $0.metadata.isShared })
    let controller = TabularSheetController<LibrarySheetItem>(cellConfig: config)
    libraries.sorted(by: StandardSortDescriptors.byLibraryName)
             .forEach { library in
               let metadata = library.metadata
               controller.addSheetItem(.library(name: metadata.name,
                                                shared: metadata.isShared,
                                                selected: self.primaryLibrary.metadata.id == metadata.id) { _ in
                 self.switchLibrary(to: library)
               })
             }
    controller.addSheetItem(.settings { _ in
      self.libraryListCoordinator = LibraryListCoordinator(dependencies: self.dependencies)
      self.libraryListCoordinator!.delegate = self
      self.tabBarController.present(self.libraryListCoordinator!.rootViewController, animated: true)
    })
    self.tabBarController.present(controller, animated: true)
  }

  private func switchLibrary(to newLibrary: MovieLibrary) {
    if primaryLibrary.metadata.id == newLibrary.metadata.id { return }
    DispatchQueue.main.async {
      self.primaryLibrary = newLibrary
      self.libraryContentCoordinator.library = newLibrary
      self.genreListCoordinator.library = newLibrary
      self.setTabs(includeSearchTab: newLibrary.metadata.currentUserCanModify)
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
      if changeSet.modifications[self.primaryLibrary.metadata.id] != nil {
        self.updateTabs()
      } else if changeSet.deletions[self.primaryLibrary.metadata.id] != nil {
        self.switchToDifferentLibrary()
      }
    }
  }

  private func updateTabs() {
    if self.primaryLibrary.metadata.currentUserCanModify && self.searchTmdbCoordinator == nil {
      self.setTabs(includeSearchTab: true)
    } else if !self.primaryLibrary.metadata.currentUserCanModify && self.searchTmdbCoordinator != nil {
      self.setTabs(includeSearchTab: false)
    }
  }

  private func switchToDifferentLibrary() {
    libraryManager.fetchLibraries { result in
      switch result {
        case let .failure(error):
          os_log("unable to switch library since fetchLibraries failed: %{public}@",
                 log: CoreCoordinator.logger,
                 type: .default,
                 String(describing: error))
          fatalError("unable to switch library")
        case let .success(libraries):
          if libraries.isEmpty {
            os_log("all libraries have been deleted -> creating default one",
                   log: CoreCoordinator.logger,
                   type: .default)
            self.makeDefaultLibrary { library in
              self.switchLibrary(to: library)
            }
          } else {
            self.switchLibrary(to: libraries.first!)
          }
      }
    }
  }

  private func makeDefaultLibrary(then completion: @escaping (MovieLibrary) -> Void) {
    let metadata = MovieLibraryMetadata(name: NSLocalizedString("library.defaultName", comment: ""))
    dependencies.libraryManager.addLibrary(with: metadata) { result in
      switch result {
        case let .failure(error):
          switch error {
            case let .globalError(event):
              self.notificationCenter.post(event.notification)
            case .nonRecoverableError:
              fatalError("non-recoverable error during creation of default library")
            case .libraryDoesNotExist, .permissionFailure:
              fatalError("should not occur: \(error)")
          }
        case let .success(library):
          completion(library)
      }
    }
  }

  func libraryManager(_ libraryManager: MovieLibraryManager,
                      willAcceptSharedLibraryWith title: String,
                      continuation: @escaping () -> Void) {
    DispatchQueue.main.async {
      if self.libraryListCoordinator == nil {
        self.libraryListCoordinator = LibraryListCoordinator(dependencies: self.dependencies)
        self.libraryListCoordinator!.delegate = self
        self.tabBarController.present(self.libraryListCoordinator!.rootViewController, animated: true) {
          self.libraryListCoordinator!.libraryManager(libraryManager,
                                                      willAcceptSharedLibraryWith: title,
                                                      continuation: continuation)
        }
      }
    }
  }

  func libraryManager(_ libraryManager: MovieLibraryManager,
                      didAcceptSharedLibrary library: MovieLibrary,
                      with title: String) {
    switchLibrary(to: library)
  }
}

extension CoreCoordinator: LibraryListCoordinatorDelegate {
  func libraryListCoordinatorDidFinish(_ coordinator: LibraryListCoordinator) {
    DispatchQueue.main.async {
      coordinator.rootViewController.dismiss(animated: true)
      self.libraryListCoordinator = nil
    }
  }
}
