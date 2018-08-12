import CinemaKit
import Foundation
import os.log
import UIKit

class AppCoordinator: AutoPresentableCoordinator {
  enum State {
    case launched
    case startup
    case upAndRunning(AppDependencies, CoreCoordinator)
  }

  private static let logger = Logging.createLogger(category: "Main")
  private let window = UIWindow(frame: UIScreen.main.bounds)
  private var state: State = .launched {
    didSet {
      switch state {
        case .launched: fatalError("unreachable")
        case .startup:
          // TODO initialize on .userInitiated queue and display startup ui
          initializeCinemaKit()
        case let .upAndRunning(_, mainCoordinator):
          os_log("up and running", log: AppCoordinator.logger, type: .default)
          replaceRootViewController(of: window, with: mainCoordinator.rootViewController)
      }
    }
  }

  private var importCoordinator: ImportCoordinator?

  func presentRootViewController() {
    transition(to: .startup)
    window.makeKeyAndVisible()
  }

  private func initializeCinemaKit() {
    CinemaKitStartupManager().initialize { dependencies in
      dependencies.libraryManager.fetchLibraries { result in
        switch result {
          case let .failure(error):
            fatalError("unable to fetch libraries: \(error)")
          case let .success(libraries):
            guard libraries.count == 1 else { fatalError("which one is the default one?") }
            let coreCoordinator = CoreCoordinator(for: libraries.first!, dependencies: dependencies)
            self.transition(to: .upAndRunning(dependencies, coreCoordinator))
        }
      }
    }
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
          case .startup: isValidNextState = true
          default: isValidNextState = false
        }
      case .startup:
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
