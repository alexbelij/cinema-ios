import CinemaKit
import Foundation
import os.log
import UIKit

class AppCoordinator: AutoPresentableCoordinator {
  enum State {
    case launched
    case gatheringDependencies
    case upAndRunning(AppDependencies, CoreCoordinator)
  }

  private static let logger = Logging.createLogger(category: "Main")
  private let window = UIWindow(frame: UIScreen.main.bounds)
  private var state: State = .launched {
    didSet {
      switch state {
        case .launched: fatalError("unreachable")
        case .gatheringDependencies:
          let dependencies = makeDependencies()
          transition(to: .upAndRunning(dependencies, CoreCoordinator(dependencies: dependencies)))
        case let .upAndRunning(_, mainCoordinator):
          os_log("up and running", log: AppCoordinator.logger, type: .default)
          replaceRootViewController(of: window, with: mainCoordinator.rootViewController)
      }
    }
  }

  private var importCoordinator: ImportCoordinator?

  func presentRootViewController() {
    transition(to: .gatheringDependencies)
    window.makeKeyAndVisible()
  }

  private func replaceRootViewController(of window: UIWindow, with newController: UIViewController) {
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

// MARK: - Making Dependencies

extension AppCoordinator {
  private func makeDependencies() -> AppDependencies {
    os_log("gathering dependencies", log: AppCoordinator.logger, type: .default)
    // Media Library
    let url = Utils.directoryUrl(for: .documentDirectory).appendingPathComponent("cinema.data")
    moveLegacyLibraryFile(to: url)
    let dataFormat = KeyedArchivalFormat()
    dataFormat.defaultSchemaVersion = .v2_0_0
    let library = FileBasedMediaLibrary(url: url, dataFormat: dataFormat)!

    // MovieDb Client
    let language = MovieDbLanguage(rawValue: Locale.current.languageCode ?? "en") ?? .en
    let country = MovieDbCountry(rawValue: Locale.current.regionCode ?? "US") ?? .unitedStates
    let movieDb = TMDBSwiftWrapper(language: language, country: country)

    return AppDependencies(library: library, movieDb: movieDb)
  }

  private func moveLegacyLibraryFile(to url: URL) {
    let legacyUrl = Utils.directoryUrl(for: .applicationSupportDirectory, createIfNecessary: false)
                         .appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)
                         .appendingPathComponent("cinema.data")
    if FileManager.default.fileExists(atPath: legacyUrl.path) {
      do {
        try FileManager.default.moveItem(at: legacyUrl, to: url)
        os_log("moved legacy library data file from 'Application Support' to 'Documents'",
               log: AppCoordinator.logger,
               type: .default)
      } catch {
        os_log("unable to move legacy library data file: %{public}@",
               log: AppCoordinator.logger,
               type: .fault,
               String(describing: error))
        fatalError("unable to move legacy library data file")
      }
    }
  }
}

// MARK: - Importing from URL

extension AppCoordinator: ImportCoordinatorDelegate {
  func handleImport(from url: URL) -> Bool {
    guard case let State.upAndRunning(dependencies, mainCoordinator) = state else { return false }
    importCoordinator = ImportCoordinator(importUrl: url, dependencies: dependencies)
    importCoordinator!.delegate = self
    mainCoordinator.rootViewController.present(importCoordinator!.rootViewController, animated: true)
    return true
  }

  func importCoordinatorDidFinish(_ coordinator: ImportCoordinator) {
    coordinator.rootViewController.dismiss(animated: true)
    self.importCoordinator = nil
  }
}

// MARK: - Finite State Machine Validation

extension AppCoordinator {
  func transition(to nextState: State) {
    let isValidNextState: Bool
    switch state {
      case .launched:
        switch nextState {
          case .gatheringDependencies: isValidNextState = true
          default: isValidNextState = false
        }
      case .gatheringDependencies:
        switch nextState {
          case .upAndRunning: isValidNextState = true
          default: isValidNextState = false
        }
      case .upAndRunning:
        isValidNextState = false
    }
    if isValidNextState {
      state = nextState
    } else {
      fatalError("illegal state transition from \(state) to \(nextState)")
    }
  }
}
