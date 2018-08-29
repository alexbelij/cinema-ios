import CinemaKit
import CloudKit
import Foundation
import os.log
import UIKit

class AppCoordinator: AutoPresentableCoordinator {
  enum State {
    case launched
    case initializing
    case upAndRunning(AppDependencies, CoreCoordinator)
  }

  private static let logger = Logging.createLogger(category: "AppCoordinator")
  private let application: UIApplication
  private let window = UIWindow(frame: UIScreen.main.bounds)
  private var state = State.launched
  private var initializationRound = 0
  private var importCoordinator: ImportCoordinator?

  init(application: UIApplication) {
    self.application = application
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(applicationWideEventDidOccur),
                                           name: .applicationWideEventDidOccur,
                                           object: nil)
  }

  func presentRootViewController() {
    startUp()
    window.makeKeyAndVisible()
  }

  private func startUp() {
    dispatchPrecondition(condition: DispatchPredicate.onQueue(.main))
    guard initializationRound < 2 else { fatalError("already tried to initialize \(initializationRound) times") }
    state = .initializing
    initializationRound += 1
    os_log("initializing (round %d)", log: AppCoordinator.logger, type: .default, initializationRound)
    window.rootViewController = UIStoryboard(name: "LaunchScreen", bundle: nil).instantiateInitialViewController()
    DispatchQueue.global(qos: .userInitiated).async {
      CKContainer.default().accountStatus { status, error in
        switch status {
          case .available:
            CinemaKitStartupManager(using: self.application).initialize { dependencies in
              self.loadData(using: dependencies)
            }
          case .couldNotDetermine, .restricted, .noAccount:
            fatalError("not implemented")
        }
      }
    }
  }

  private func loadData(using dependencies: AppDependencies) {
    DispatchQueue.main.async {
      os_log("loading data", log: AppCoordinator.logger, type: .default)
      DispatchQueue.global(qos: .userInitiated).async {
        self.fetchLibraries(using: dependencies)
      }
    }
  }

  private func fetchLibraries(using dependencies: AppDependencies) {
    dependencies.libraryManager.fetchLibraries { result in
      switch result {
        case let .failure(error):
          switch error {
            case let .globalError(event):
              switch event {
                case .notAuthenticated:
                  fatalError("not implemented")
                case .userDeletedZone:
                  os_log("user has deleted zone -> reinitialize (local data will be removed)",
                         log: AppCoordinator.logger,
                         type: .default)
                  DispatchQueue.main.async {
                    self.startUp()
                  }
              }
            case .nonRecoverableError:
              fatalError("non-recoverable error during initial libraries fetch")
            case .libraryDoesNotExist:
              fatalError("should not occur: \(error)")
          }
        case let .success(libraries):
          self.handleFetchedLibraries(libraries, dependencies: dependencies)
      }
    }
  }

  private func handleFetchedLibraries(_ libraries: [MovieLibrary], dependencies: AppDependencies) {
    if libraries.isEmpty {
      os_log("no libraries found -> creating default one", log: AppCoordinator.logger, type: .default)
      let metadata = MovieLibraryMetadata(name: NSLocalizedString("library.defaultName", comment: ""))
      dependencies.libraryManager.addLibrary(with: metadata) { result in
        switch result {
          case let .failure(error):
            switch error {
              case let .globalError(event):
                switch event {
                  case .notAuthenticated:
                    fatalError("not implemented")
                  case .userDeletedZone:
                    os_log("user has deleted zone -> reinitialize (local data will be removed)",
                           log: AppCoordinator.logger,
                           type: .default)
                    DispatchQueue.main.async {
                      self.startUp()
                    }
                }
              case .nonRecoverableError:
                fatalError("non-recoverable error during creation of initial library")
              case .libraryDoesNotExist:
                fatalError("should not occur: \(error)")
            }
          case let .success(library):
            self.finishStartup(with: library, dependencies: dependencies)
        }
      }
    } else {
      self.finishStartup(with: libraries.first!, dependencies: dependencies)
    }
  }

  private func finishStartup(with library: MovieLibrary, dependencies: AppDependencies) {
    DispatchQueue.main.async {
      let coreCoordinator = CoreCoordinator(for: library, dependencies: dependencies)
      self.state = .upAndRunning(dependencies, coreCoordinator)
      os_log("up and running", log: AppCoordinator.logger, type: .default)
      self.window.rootViewController = coreCoordinator.rootViewController
      if self.application.applicationState == .active {
        dependencies.libraryManager.fetchChanges { _ in }
      }
    }
  }
}

// MARK: - Importing from URL

extension AppCoordinator: ImportCoordinatorDelegate {
  func handleImport(from url: URL) -> Bool {
    dispatchPrecondition(condition: DispatchPredicate.onQueue(.main))
    guard case let State.upAndRunning(dependencies, coreCoordinator) = state else { return false }
    importCoordinator = ImportCoordinator(importUrl: url, dependencies: dependencies)
    importCoordinator!.delegate = self
    coreCoordinator.rootViewController.present(importCoordinator!.rootViewController, animated: true)
    return true
  }

  func importCoordinatorDidFinish(_ coordinator: ImportCoordinator) {
    coordinator.rootViewController.dismiss(animated: true)
    self.importCoordinator = nil
  }
}

extension AppCoordinator {
  func handleRemoteNotification(_ userInfo: [AnyHashable: Any],
                                fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    dispatchPrecondition(condition: DispatchPredicate.onQueue(.main))
    guard case let State.upAndRunning(dependencies, _) = state else { return completionHandler(.noData) }
    dependencies.libraryManager.fetchChanges(then: completionHandler)
  }

  func applicationDidBecomeActive() {
    dispatchPrecondition(condition: DispatchPredicate.onQueue(.main))
    guard case let State.upAndRunning(dependencies, _) = state else { return }
    dependencies.libraryManager.fetchChanges { _ in }
  }

  @objc
  private func applicationWideEventDidOccur(_ notification: Notification) {
    // swiftlint:disable:next force_cast
    let event = notification.userInfo![ApplicationWideEvent.userInfoKey] as! ApplicationWideEvent
    switch event {
      case .notAuthenticated:
        // TODO show custom ui
        fatalError("not implemented")
      case .userDeletedZone:
        // TODO show custom ui
        fatalError("not implemented")
    }
  }
}

extension AppCoordinator {
  private func replaceRootViewController(of window: UIWindow, with newController: UIViewController) {
    dispatchPrecondition(condition: DispatchPredicate.onQueue(.main))
    if let snapShot = window.snapshotView(afterScreenUpdates: true) {
      newController.view.addSubview(snapShot)
      window.rootViewController = newController
      UIView.animate(withDuration: 0.3,
                     animations: {
                       snapShot.layer.opacity = 0
                       snapShot.layer.transform = CATransform3DMakeScale(1.5, 1.5, 1.5)
                     },
                     completion: { _ in
                       snapShot.removeFromSuperview()
                     })
    } else {
      window.rootViewController = newController
    }
  }
}
