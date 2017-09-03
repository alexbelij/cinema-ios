import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?

  var library: MediaLibrary!
  var movieDb: MovieDbClient!

  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    let arguments = ProcessInfo.processInfo.arguments

    self.movieDb = Config.initMovieDb(launchArguments: arguments)
    self.movieDb.language = MovieDbLanguage(rawValue: Locale.current.languageCode ?? "en")
    self.movieDb.tryConnect()

    self.library = Config.initLibrary(launchArguments: arguments)

    let rootViewController: UIViewController
    let updates = Utils.updates(from: library.persistentSchemaVersion, using: movieDb)
    if updates.isEmpty {
      rootViewController = loadMainViewController()
    } else {
      rootViewController = loadMaintenanceViewController(updates: updates)
    }

    self.window = UIWindow(frame: UIScreen.main.bounds)
    self.window?.makeKeyAndVisible()
    self.window!.rootViewController = rootViewController
    return true
  }

  private func loadMainViewController() -> UIViewController {
    // swiftlint:disable force_cast
    let mainNavController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()
    as! UINavigationController

    let masterViewController = mainNavController.topViewController! as! MasterViewController
    masterViewController.library = library
    masterViewController.movieDb = movieDb

    let addItemNavController = UIStoryboard(name: "AddItem", bundle: nil).instantiateInitialViewController()
    as! UINavigationController
    let searchController = addItemNavController.topViewController as! SearchTMDBViewController
    searchController.library = library
    searchController.movieDb = movieDb
    // swiftlint:enable force_cast

    mainNavController.tabBarItem = UITabBarItem(title: NSLocalizedString("library", comment: ""),
                                                image: #imageLiteral(resourceName:"Tab-Library-normal"),
                                                selectedImage: #imageLiteral(resourceName:"Tab-Library-selected"))
    addItemNavController.tabBarItem = UITabBarItem(title: NSLocalizedString("addItem.title", comment: ""),
                                                   image: #imageLiteral(resourceName:"Tab-AddItem-normal"),
                                                   selectedImage: #imageLiteral(resourceName:"Tab-AddItem-selected"))
    let tabBarController = UITabBarController()
    tabBarController.viewControllers = [mainNavController, addItemNavController]
    return tabBarController
  }

  private func loadMaintenanceViewController(updates: [PropertyUpdate]) -> UIViewController {
    let controller = UIStoryboard(name: "Maintenance", bundle: nil).instantiateInitialViewController()
    // swiftlint:disable:next force_cast
    as! MaintenanceViewController
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
    if let snapShot = self.window!.snapshotView(afterScreenUpdates: true) {
      newController.view.addSubview(snapShot)
      self.window!.rootViewController = newController
      UIView.animate(withDuration: 0.3, animations: {
        snapShot.layer.opacity = 0
        snapShot.layer.transform = CATransform3DMakeScale(1.5, 1.5, 1.5)
      }) { _ in
        snapShot.removeFromSuperview()
      }
    } else {
      self.window!.rootViewController = newController
    }
  }

  public func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
    let alert = UIAlertController(title: NSLocalizedString("replaceLibrary.alert.title", comment: ""),
                                  message: nil,
                                  preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: NSLocalizedString("yes", comment: ""), style: .destructive) { _ in
      let controller = UIStoryboard(name: "ReplaceLibrary", bundle: nil)
          // swiftlint:disable:next force_cast
          .instantiateInitialViewController() as! ReplaceLibraryViewController
      controller.replaceLibraryContent(of: self.library, withContentOf: url)
      self.window!.rootViewController!.present(controller, animated: true)
    })
    alert.addAction(UIAlertAction(title: NSLocalizedString("no", comment: ""), style: .default))
    window!.rootViewController!.present(alert, animated: true)
    return true
  }

}
