import CinemaKit
import CloudKit
import Foundation
import os.log
import UIKit

class AppCoordinator: AutoPresentableCoordinator {
  enum State {
    case launched
    case initializing
    case settingUp(StartupCoordinator)
    case notAuthenticated(UIViewController)
    case upAndRunning(AppDependencies, CoreCoordinator)
    case readyForRestart(UIViewController)
  }

  private static let logger = Logging.createLogger(category: "AppCoordinator")
  private let application: UIApplication
  private let window = UIWindow(frame: UIScreen.main.bounds)
  private var state = State.launched
  private var initializationRound = 0

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
            self.initializeCinemaKit()
          case .couldNotDetermine, .restricted, .noAccount:
            os_log("account status is not .accepted, error=%{public}@",
                   log: AppCoordinator.logger,
                   type: .default,
                   String(describing: error))
            DispatchQueue.main.async {
              self.showNotAuthenticatedPage()
            }
        }
      }
    }
  }

  private func initializeCinemaKit() {
    let migratedLibraryNameFormat = NSLocalizedString("library.migratedNameFormat", comment: "")
    let migratedLibraryName = String.localizedStringWithFormat(migratedLibraryNameFormat, UIDevice.current.name)
    CinemaKitStartupManager(using: self.application, migratedLibraryName: migratedLibraryName).initialize { progress in
      switch progress {
        case .settingUpCloudEnvironment:
          DispatchQueue.main.async {
            let coordinator = StartupCoordinator()
            coordinator.change(to: .initializingCloud)
            self.state = .settingUp(coordinator)
            self.window.rootViewController = coordinator.rootViewController
          }
        case let .foundLegacyData(shouldMigrateDecision):
          DispatchQueue.main.async {
            guard case let .settingUp(coordinator) = self.state else {
              os_log("found legacy data but not in setup mode -> aborting migration",
                     log: AppCoordinator.logger,
                     type: .error)
              shouldMigrateDecision(false)
              return
            }
            coordinator.change(to: .foundLegacyData(shouldMigrateDecision))
          }
        case .migrationFailed:
          DispatchQueue.main.async {
            guard case let .settingUp(coordinator) = self.state else { fatalError("illegal state") }
            coordinator.change(to: .migratingFailed)
          }
        case let .ready(dependencies):
          self.loadData(using: dependencies)
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
                  DispatchQueue.main.async {
                    self.showNotAuthenticatedPage()
                  }
                case .userDeletedZone:
                  os_log("user has deleted zone -> reinitialize (local data will be removed)",
                         log: AppCoordinator.logger,
                         type: .default)
                  DispatchQueue.main.async {
                    self.startUp()
                  }
                case .shouldFetchChanges:
                  fatalError("should not occur: \(error)")
              }
            case .nonRecoverableError:
              fatalError("non-recoverable error during initial libraries fetch")
            case .libraryDoesNotExist, .permissionFailure:
              fatalError("should not occur: \(error)")
          }
        case let .success(libraries):
          self.handleFetchedLibraries(libraries, using: dependencies)
      }
    }
  }

  private func handleFetchedLibraries(_ libraries: [MovieLibrary], using dependencies: AppDependencies) {
    if libraries.isEmpty {
      os_log("no libraries found -> creating default one", log: AppCoordinator.logger, type: .default)
      makeDefaultLibrary(using: dependencies) { library in
        dependencies.userDefaults.set(library.metadata.id.recordName, forKey: CoreCoordinator.primaryLibraryKey)
        self.handleFetchedLibraries([library], using: dependencies)
      }
    } else {
      let primaryLibrary: MovieLibrary
      if let libraryID = dependencies.userDefaults.string(forKey: CoreCoordinator.primaryLibraryKey),
         let library = libraries.first(where: { $0.metadata.id.recordName == libraryID }) {
        primaryLibrary = library
      } else {
        primaryLibrary = libraries.first!
        dependencies.userDefaults.set(primaryLibrary.metadata.id.recordName, forKey: CoreCoordinator.primaryLibraryKey)
      }
      let finishCall = {
        DispatchQueue.main.async {
          self.finishStartup(with: primaryLibrary, dependencies: dependencies)
        }
      }
      if case let .settingUp(coordinator) = self.state {
        coordinator.change(to: .finished(finishCall))
      } else {
        finishCall()
      }
    }
  }

  private func makeDefaultLibrary(using dependencies: AppDependencies,
                                  then completion: @escaping (MovieLibrary) -> Void) {
    let metadata = MovieLibraryMetadata(name: NSLocalizedString("library.defaultName", comment: ""))
    dependencies.libraryManager.addLibrary(with: metadata) { result in
      switch result {
        case let .failure(error):
          switch error {
            case let .globalError(event):
              switch event {
                case .notAuthenticated:
                  DispatchQueue.main.async {
                    self.showNotAuthenticatedPage()
                  }
                case .userDeletedZone:
                  os_log("user has deleted zone -> reinitialize (local data will be removed)",
                         log: AppCoordinator.logger,
                         type: .default)
                  DispatchQueue.main.async {
                    self.startUp()
                  }
                case .shouldFetchChanges:
                  fatalError("should not occur: \(error)")
              }
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

  private func finishStartup(with library: MovieLibrary, dependencies: AppDependencies) {
    let coreCoordinator = CoreCoordinator(for: library, dependencies: dependencies)
    self.state = .upAndRunning(dependencies, coreCoordinator)
    os_log("up and running", log: AppCoordinator.logger, type: .default)
    self.window.rootViewController = coreCoordinator.rootViewController
    if self.application.applicationState == .active {
      dependencies.libraryManager.fetchChanges { _ in }
    }
  }
}

extension AppCoordinator {
  func handleRemoteNotification(_ userInfo: [AnyHashable: Any],
                                fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    dispatchPrecondition(condition: DispatchPredicate.onQueue(.main))
    guard case let State.upAndRunning(dependencies, _) = state else { return completionHandler(.noData) }
    dependencies.libraryManager.fetchChanges(then: completionHandler)
  }

  func acceptCloudKitShare(with shareMetadata: CKShareMetadata) {
    dispatchPrecondition(condition: DispatchPredicate.onQueue(.main))
    guard case let State.upAndRunning(dependencies, coreCoordinator) = state else { return }
    dependencies.libraryManager.acceptCloudKitShare(with: shareMetadata)
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
      coreCoordinator.showLibrarySettings()
    }
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
        DispatchQueue.main.async {
          self.showNotAuthenticatedPage()
        }
      case .userDeletedZone:
        DispatchQueue.main.async {
          self.showRestartUI()
        }
      case .shouldFetchChanges:
        guard case let .upAndRunning(dependencies, _) = state else { return }
        dependencies.libraryManager.fetchChanges { _ in }
    }
  }
}

extension AppCoordinator {
  private func showNotAuthenticatedPage() {
    dispatchPrecondition(condition: DispatchPredicate.onQueue(.main))
    if case .notAuthenticated = state { return }
    let page = ActionPage.initWith(
        primaryText: NSLocalizedString("iCloud.notAuthenticated.title", comment: ""),
        secondaryText: NSLocalizedString("iCloud.notAuthenticated.subtitle", comment: ""),
        image: #imageLiteral(resourceName: "CloudFailure"),
        actionTitle: NSLocalizedString("continue", comment: "")) { [weak self] in
      guard let `self` = self else { return }
      self.initializationRound = 0
      self.startUp()
    }
    state = .notAuthenticated(page)
    window.rootViewController = page
  }

  private func showRestartUI() {
    dispatchPrecondition(condition: DispatchPredicate.onQueue(.main))
    if case .readyForRestart = state { return }
    let page = ActionPage.initWith(
        primaryText: NSLocalizedString("iCloud.userDeletedZone", comment: ""),
        image: #imageLiteral(resourceName: "CloudDeleted"),
        actionTitle: NSLocalizedString("iCloud.userDeletedZone.actionTitle", comment: "")) { [weak self] in
      guard let `self` = self else { return }
      self.initializationRound = 0
      self.startUp()
    }
    state = .readyForRestart(page)
    window.rootViewController = page
  }

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
