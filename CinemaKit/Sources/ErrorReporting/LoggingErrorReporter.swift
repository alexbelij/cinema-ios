import os.log

class LoggingErrorReporter: ErrorReporter {
  static let shared = LoggingErrorReporter()
  private static let logger = Logging.createLogger(category: "ErrorReporter")

  private init() {
  }

  func report(_ error: Error, info: [String: Any]?) {
    let nserror = error as NSError
    os_log("%{public}@ (code %{public}d)", log: LoggingErrorReporter.logger, type: .error, nserror.domain, nserror.code)
  }
}
