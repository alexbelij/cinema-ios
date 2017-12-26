import Foundation
import UIKit

class AppCoordinator: AutoPresentableCoordinator {
  private let window = UIWindow(frame: UIScreen.main.bounds)
  private var library: MediaLibrary!
  private var movieDb: MovieDbClient!

  func presentRootViewController() {
    movieDb = Config.initMovieDb()
    library = Config.initLibrary()

    let rootViewController: UIViewController
    let updates = Utils.updates(from: library.persistentSchemaVersion, using: movieDb)
    if updates.isEmpty {
      rootViewController = loadMainViewController()
    } else {
      rootViewController = loadMaintenanceViewController(updates: updates)
    }

    window.rootViewController = rootViewController
    window.makeKeyAndVisible()
  }

  private func loadMainViewController() -> UIViewController {
    // swiftlint:disable force_cast
    let mainNavController = UIStoryboard.main.instantiateInitialViewController() as! UINavigationController

    let masterViewController = mainNavController.topViewController! as! MasterViewController
    masterViewController.library = library
    masterViewController.movieDb = movieDb

    let addItemNavController = UIStoryboard.addItem.instantiateInitialViewController() as! UINavigationController
    let searchController = addItemNavController.topViewController as! SearchTMDBViewController
    searchController.library = library
    searchController.movieDb = movieDb
    // swiftlint:enable force_cast

    mainNavController.tabBarItem = UITabBarItem(title: NSLocalizedString("library", comment: ""),
                                                image: #imageLiteral(resourceName: "Tab-Library-normal"),
                                                selectedImage: #imageLiteral(resourceName: "Tab-Library-selected"))
    addItemNavController.tabBarItem = UITabBarItem(title: NSLocalizedString("addItem.title", comment: ""),
                                                   image: #imageLiteral(resourceName: "Tab-AddItem-normal"),
                                                   selectedImage: #imageLiteral(resourceName: "Tab-AddItem-selected"))
    let tabBarController = UITabBarController()
    tabBarController.viewControllers = [mainNavController, addItemNavController]
    return tabBarController
  }

  private func loadMaintenanceViewController(updates: [PropertyUpdate]) -> UIViewController {
    let controller = UIStoryboard.maintenance.instantiate(MaintenanceViewController.self)
    controller.run(PropertyUpdateAction(library: library, updates: updates),
                   initiation: .button(title: NSLocalizedString("maintenance.start", comment: ""))) { result in
      switch result {
        case .result:
          controller.primaryText = NSLocalizedString("maintenance.succeeded", comment: "")
        case let .error(error):
          controller.primaryText = NSLocalizedString("maintenance.failed", comment: "")
          controller.secondaryText = Utils.localizedErrorMessage(for: error)
      }
    }
    controller.primaryText = NSLocalizedString("maintenance.intention", comment: "")
    controller.dismissHandler = .custom(handler: { [weak self] in
      guard let `self` = self else { return }
      self.replaceRootViewControllerAnimated(newController: self.loadMainViewController())
    })
    return controller
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
