import CloudKit
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  private var appCoordinator: AppCoordinator!

  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    appCoordinator = AppCoordinator(application: application)
    appCoordinator.presentRootViewController()
    return true
  }

  func application(_ application: UIApplication,
                   didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                   fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    appCoordinator.handleRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
    appCoordinator.applicationDidBecomeActive()
  }

  func application(_ application: UIApplication,
                   userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
    appCoordinator.acceptCloudKitShare(with: cloudKitShareMetadata)
  }
}
