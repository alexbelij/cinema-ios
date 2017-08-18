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

    self.window = UIWindow(frame: UIScreen.main.bounds)
    self.window?.makeKeyAndVisible()
    self.window!.rootViewController = loadMainViewController()
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
