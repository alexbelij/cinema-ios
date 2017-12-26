import UIKit

protocol DataUpdateCoordinatorDelegate: class {
  func dataUpdateCoordinatorDidFinish(_ coordinator: DataUpdateCoordinator)
}

class DataUpdateCoordinator: CustomPresentableCoordinator {
  // coordinator stuff
  var rootViewController: UIViewController {
    return maintenanceController
  }
  weak var delegate: DataUpdateCoordinatorDelegate?

  // other properties
  private let library: MediaLibrary
  private let movieDb: MovieDbClient

  // managed controller
  private let maintenanceController: MaintenanceViewController

  init(library: MediaLibrary, movieDb: MovieDbClient, updates: [PropertyUpdate]) {
    self.library = library
    self.movieDb = movieDb
    maintenanceController = UIStoryboard.maintenance.instantiate(MaintenanceViewController.self)
    maintenanceController.run(PropertyUpdateAction(library: library, updates: updates),
                              initiation: .button(title: NSLocalizedString("maintenance.start", comment: "")),
                              completion: maintenanceActionDidComplete)
    maintenanceController.primaryText = NSLocalizedString("maintenance.intention", comment: "")
    maintenanceController.dismissHandler = .custom(handler: { [weak self] in
      guard let `self` = self else { return }
      self.delegate?.dataUpdateCoordinatorDidFinish(self)
    })
  }

  private func maintenanceActionDidComplete(with result: ActionResult<Void>) {
    switch result {
      case .result:
        maintenanceController.primaryText = NSLocalizedString("maintenance.succeeded", comment: "")
      case let .error(error):
        maintenanceController.primaryText = NSLocalizedString("maintenance.failed", comment: "")
        maintenanceController.secondaryText = Utils.localizedErrorMessage(for: error)
    }
  }
}
