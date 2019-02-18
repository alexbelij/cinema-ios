import Crashlytics
import Foundation

class CrashlyticsErrorReporter: ErrorReporter {
  static let shared = CrashlyticsErrorReporter()
  private let reporter: Crashlytics = Crashlytics.sharedInstance()

  private init() {
  }

  func report(_ error: Error, info: [String: Any]?) {
    reporter.recordError(error, withAdditionalUserInfo: info)
  }
}
