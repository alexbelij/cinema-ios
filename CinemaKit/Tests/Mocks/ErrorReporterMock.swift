@testable import CinemaKit
import XCTest

class ErrorReporterMock: ErrorReporter {
  var reportedErrors = [Error]()

  func report(_ error: Error, info: [String: Any]?) {
    reportedErrors.append(error)
  }
}
