import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

  var window: UIWindow?

  var library: MediaLibrary!
  var movieDb: MovieDbClient!

  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    // swiftlint:disable:next force_cast
    let splitViewController = window!.rootViewController as! UISplitViewController
    let navigationController = splitViewController
    // swiftlint:disable:next force_cast
        .viewControllers[splitViewController.viewControllers.count - 1] as! UINavigationController
    navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
    splitViewController.delegate = self

    library = FileBasedMediaLibrary(directory: Utils.applicationSupportDirectory(),
                                    fileName: "cinema.data",
                                    dataFormat: KeyedArchivalFormat())
    movieDb = TMDBSwiftWrapper(storeFront: .germany)
    movieDb.language = MovieDbLanguage(rawValue: Locale.current.languageCode ?? "en")
    movieDb.tryConnect()

    return true
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
      let controller = UIStoryboard(name: "Main", bundle: nil)
          // swiftlint:disable:next force_cast
          .instantiateViewController(withIdentifier: "ReplaceLibraryViewController") as! ReplaceLibraryViewController
      controller.replaceLibraryContent(of: self.library, withContentOf: url)
      UIApplication.shared.keyWindow!.rootViewController!.present(controller, animated: true)
    }))
    alert.addAction(UIAlertAction(title: NSLocalizedString("no", comment: ""), style: .default))
    UIApplication.shared.keyWindow!.rootViewController!.present(alert, animated: true)
    return true
  }

}
