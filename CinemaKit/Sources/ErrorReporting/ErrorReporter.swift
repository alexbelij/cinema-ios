import Foundation

public protocol ErrorReporter {
  func report(_ error: Error, info: [String: Any]?)
}

extension ErrorReporter {
  public func report(_ error: Error, info: [String: Any]? = nil) {
    report(error, info: nil)
  }
}
