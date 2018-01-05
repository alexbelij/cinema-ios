import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  private lazy var appCoordinator = AppCoordinator()

  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    appCoordinator.presentRootViewController()
    return true
  }

  public func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
    return appCoordinator.handleImport(from: url)
  }
}
