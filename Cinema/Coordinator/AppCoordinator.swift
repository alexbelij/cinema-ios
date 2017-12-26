import Foundation
import UIKit

class AppCoordinator: AutoPresentableCoordinator {
  private let window = UIWindow(frame: UIScreen.main.bounds)
  private var library: MediaLibrary!
  private var movieDb: MovieDbClient!

  // child coordinators
  private var coreCoordinator: CoreCoordinator!
  private var dataUpdateCoordinator: DataUpdateCoordinator!

  func presentRootViewController() {
    // Media Library
    let url = Utils.directoryUrl(for: .documentDirectory).appendingPathComponent("cinema.data")
    moveLegacyLibraryFile(to: url)
    let dataFormat = KeyedArchivalFormat()
    dataFormat.defaultSchemaVersion = .v2_0_0
    // swiftlint:disable:next force_try
    library = try! FileBasedMediaLibrary(url: url, dataFormat: dataFormat)

    // MovieDb Client
    let language = MovieDbLanguage(rawValue: Locale.current.languageCode ?? "en") ?? .en
    let country = MovieDbCountry(rawValue: Locale.current.regionCode ?? "US") ?? .unitedStates
    movieDb = TMDBSwiftWrapper(language: language, country: country, cache: StandardTMDBSwiftCache())

    let rootViewController: UIViewController
    let updates = Utils.updates(from: library.persistentSchemaVersion, using: movieDb)
    if updates.isEmpty {
      coreCoordinator = CoreCoordinator(library: library, movieDb: movieDb)
      rootViewController = coreCoordinator.rootViewController
    } else {
      dataUpdateCoordinator = DataUpdateCoordinator(library: library, movieDb: movieDb, updates: updates)
      dataUpdateCoordinator.delegate = self
      rootViewController = dataUpdateCoordinator.rootViewController
    }

    window.rootViewController = rootViewController
    window.makeKeyAndVisible()
  }

  private func replaceRootViewControllerAnimated(newController: UIViewController) {
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

// MARK: - Legacy

extension AppCoordinator {
  private func moveLegacyLibraryFile(to url: URL) {
    let legacyUrl = Utils.directoryUrl(for: .applicationSupportDirectory, createIfNecessary: false)
                         .appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)
                         .appendingPathComponent("cinema.data")
    if FileManager.default.fileExists(atPath: legacyUrl.path) {
      do {
        try FileManager.default.moveItem(at: legacyUrl, to: url)
      } catch let error {
        fatalError("could not move library file: \(error)")
      }
    }
  }
}

// MARK: - DataUpdateCoordinatorDelegate

extension AppCoordinator: DataUpdateCoordinatorDelegate {
  func dataUpdateCoordinatorDidFinish(_ coordinator: DataUpdateCoordinator) {
    coreCoordinator = CoreCoordinator(library: library, movieDb: movieDb)
    replaceRootViewControllerAnimated(newController: coreCoordinator.rootViewController)
  }
}

// MARK: - Importing from URL

extension AppCoordinator {
  func handleImport(from url: URL) -> Bool {
    let controller = UIStoryboard.maintenance.instantiate(MaintenanceViewController.self)
    controller.run(ImportAndUpdateAction(library: library, movieDb: movieDb, from: url),
                   initiation: .runAutomatically) { result in
      switch result {
        case let .result(addedItems):
          controller.primaryText = NSLocalizedString("import.succeeded", comment: "")
          let format = NSLocalizedString("import.succeeded.changes", comment: "")
          controller.secondaryText = .localizedStringWithFormat(format, addedItems.count)
        case let .error(error):
          controller.primaryText = NSLocalizedString("import.failed", comment: "")
          controller.secondaryText = Utils.localizedErrorMessage(for: error)
      }
    }
    controller.primaryText = NSLocalizedString("import.progress", comment: "")
    window.rootViewController!.present(controller, animated: true)
    return true
  }
}
