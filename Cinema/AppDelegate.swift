import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

  var window: UIWindow?

  var library: MediaLibrary!
  var movieDb: MovieDbClient!

  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    self.window = UIWindow(frame: UIScreen.main.bounds)
    self.window?.makeKeyAndVisible()
    self.window!.rootViewController = loadMainViewController()
    return true
  }

  private func loadMainViewController() -> UIViewController {
    let arguments = ProcessInfo.processInfo.arguments

    library = Config.initLibrary(launchArguments: arguments)

    movieDb = Config.initMovieDb(launchArguments: arguments)
    movieDb.language = MovieDbLanguage(rawValue: Locale.current.languageCode ?? "en")
    movieDb.tryConnect()

    // swiftlint:disable force_cast
    let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
    let splitViewController = mainStoryboard.instantiateViewController(withIdentifier: "SplitViewController")
    as! UISplitViewController
    splitViewController.delegate = self

    let primaryNavController = splitViewController.viewControllers.first as! UINavigationController
    let masterViewController = (primaryNavController).topViewController! as! MasterViewController
    masterViewController.library = library
    masterViewController.movieDb = movieDb

    let secondaryNavController = splitViewController.viewControllers[1] as! UINavigationController
    let detailViewController = secondaryNavController.topViewController! as! DetailViewController
    detailViewController.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
    // swiftlint:enable force_cast

    return splitViewController
  }

  // MARK: - Split view

  func splitViewController(_ splitViewController: UISplitViewController,
                           collapseSecondary secondaryViewController: UIViewController,
                           onto primaryViewController: UIViewController) -> Bool {
    guard let secondaryAsNavController = secondaryViewController as? UINavigationController else { return false }
    guard let topAsDetailController = secondaryAsNavController.topViewController as? DetailViewController
        else { return false }
    if topAsDetailController.detailItem == nil {
      // Return true to indicate that we have handled the collapse by doing nothing;
      // the secondary controller will be discarded.
      return true
    }
    return false
  }

  public func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
    let alert = UIAlertController(title: NSLocalizedString("replaceLibrary.alert.title", comment: ""),
                                  message: nil,
                                  preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: NSLocalizedString("yes", comment: ""), style: .destructive, handler: { _ in
      let controller = UIStoryboard(name: "ReplaceLibrary", bundle: nil)
          // swiftlint:disable:next force_cast
          .instantiateInitialViewController() as! ReplaceLibraryViewController
      controller.replaceLibraryContent(of: self.library, withContentOf: url)
      self.window!.rootViewController!.present(controller, animated: true)
    }))
    alert.addAction(UIAlertAction(title: NSLocalizedString("no", comment: ""), style: .default))
    window!.rootViewController!.present(alert, animated: true)
    return true
  }

}
