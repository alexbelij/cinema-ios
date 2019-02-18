import Crashlytics
import Foundation

class CrashlyticsErrorReporter: ErrorReporter {
  static let shared = CrashlyticsErrorReporter()
  private let reporter: Crashlytics = Crashlytics.sharedInstance()

  private init() {
  }

  func report(_ error: Error, info: [String: Any]?) {
    #if targetEnvironment(simulator)
    fatalError("unhandled error")
    #else
    reporter.recordError(error, withAdditionalUserInfo: info)
    #endif
  }
}
