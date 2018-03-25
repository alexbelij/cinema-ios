import CinemaKit
import Foundation
import UIKit

class AppCoordinator: AutoPresentableCoordinator {
  enum State {
    case launched
    case gatheringDependencies
    case checkingForDataUpdates(AppDependencies)
    case updatingData(AppDependencies, DataUpdateCoordinator)
    case upAndRunning(AppDependencies, CoreCoordinator)
  }

  private let window = UIWindow(frame: UIScreen.main.bounds)
  private var state: State = .launched {
    didSet {
      switch state {
        case .launched: fatalError("unreachable")
        case .gatheringDependencies:
          transition(to: .checkingForDataUpdates(makeDependencies()))
        case let .checkingForDataUpdates(dependencies):
          checkForDataUpdates(dependencies: dependencies)
        case let .updatingData(_, dataUpdateCoordinator):
          window.rootViewController = dataUpdateCoordinator.rootViewController
        case let .upAndRunning(_, mainCoordinator):
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
    // Media Library
    let url = Utils.directoryUrl(for: .documentDirectory).appendingPathComponent("cinema.data")
    moveLegacyLibraryFile(to: url)
    let dataFormat = KeyedArchivalFormat()
    dataFormat.defaultSchemaVersion = .v2_0_0
    // swiftlint:disable:next force_try
    let library = try! FileBasedMediaLibrary(url: url, dataFormat: dataFormat)

    // MovieDb Client
    let language = MovieDbLanguage(rawValue: Locale.current.languageCode ?? "en") ?? .en
    let country = MovieDbCountry(rawValue: Locale.current.regionCode ?? "US") ?? .unitedStates
    let movieDb = TMDBSwiftWrapper(language: language, country: country, cache: StandardTMDBSwiftCache())

    return AppDependencies(library: library, movieDb: movieDb)
  }

  private func moveLegacyLibraryFile(to url: URL) {
    let legacyUrl = Utils.directoryUrl(for: .applicationSupportDirectory, createIfNecessary: false)
                         .appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)
                         .appendingPathComponent("cinema.data")
    if FileManager.default.fileExists(atPath: legacyUrl.path) {
      do {
        try FileManager.default.moveItem(at: legacyUrl, to: url)
      } catch {
        fatalError("could not move library file: \(error)")
      }
    }
  }
}

// MARK: - Data Updates

extension AppCoordinator: DataUpdateCoordinatorDelegate {
  private func checkForDataUpdates(dependencies: AppDependencies) {
    let updates = UpdateUtils.updates(from: dependencies.library.persistentSchemaVersion, using: dependencies.movieDb)
    if updates.isEmpty {
      transition(to: .upAndRunning(dependencies, CoreCoordinator(dependencies: dependencies)))
    } else {
      let dataUpdateCoordinator = DataUpdateCoordinator(library: dependencies.library, updates: updates)
      dataUpdateCoordinator.delegate = self
      transition(to: .updatingData(dependencies, dataUpdateCoordinator))
    }
  }

  func dataUpdateCoordinatorDidFinish(_ coordinator: DataUpdateCoordinator) {
    guard case let State.updatingData(dependencies, _) = state else {
      preconditionFailure("delegate method called but not in appropriate state: \(state)")
    }
    transition(to: .upAndRunning(dependencies, CoreCoordinator(dependencies: dependencies)))
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
  // swiftlint:disable:next cyclomatic_complexity
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
          case .checkingForDataUpdates: isValidNextState = true
          default: isValidNextState = false
        }
      case .checkingForDataUpdates:
        switch nextState {
          case .updatingData, .upAndRunning: isValidNextState = true
          default: isValidNextState = false
        }
      case .updatingData:
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
