import Foundation

public protocol MaintenanceAction {
  associatedtype ResultType

  var progress: Progress { get }

  func performAction(completion: (ActionResult<ResultType>) -> Void)

}

public enum ActionResult<ResultType> {
  case result(ResultType)
  case error(Error)
}
