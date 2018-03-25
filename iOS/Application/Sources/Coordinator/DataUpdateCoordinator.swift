import CinemaKit
import Dispatch
import UIKit

protocol DataUpdateCoordinatorDelegate: class {
  func dataUpdateCoordinatorDidFinish(_ coordinator: DataUpdateCoordinator)
}

class DataUpdateCoordinator: PageCoordinator {
  weak var delegate: DataUpdateCoordinatorDelegate?
  private let updateAction: PropertyUpdateAction

  init(library: MediaLibrary, updates: [PropertyUpdate]) {
    self.updateAction = PropertyUpdateAction(library: library, updates: updates)
    super.init()
    showSetupPage()
  }

  private func showSetupPage() {
    showPage(ActionPage.initWith(primaryText: NSLocalizedString("dataUpdate.update", comment: ""),
                                 secondaryText: NSLocalizedString("dataUpdate.intention", comment: ""),
                                 actionTitle: NSLocalizedString("dataUpdate.start", comment: "")) { [weak self] in
      self?.showProgressPage()
    })
  }

  private func showProgressPage() {
    showPage(ProgressPage.initWith(primaryText: NSLocalizedString("dataUpdate.progress", comment: ""),
                                   progress: updateAction.progress))
    DispatchQueue.global(qos: .userInitiated).async {
      self.updateAction.performAction { result in
        switch result {
          case .result:
            DispatchQueue.main.async {
              self.showContinuePage(primaryText: NSLocalizedString("dataUpdate.succeeded", comment: ""),
                                    secondaryText: NSLocalizedString("dataUpdate.succeeded.description", comment: ""))
            }
          case let .error(error):
            DispatchQueue.main.async {
              self.showContinuePage(primaryText: NSLocalizedString("dataUpdate.failed", comment: ""),
                                    secondaryText: L10n.errorMessage(for: error))
            }
        }
      }
    }
  }

  private func showContinuePage(primaryText: String, secondaryText: String) {
    showPage(ActionPage.initWith(primaryText: primaryText,
                                 secondaryText: secondaryText,
                                 actionTitle: NSLocalizedString("continue", comment: "")) { [weak self] in
      guard let `self` = self else { return }
      self.delegate?.dataUpdateCoordinatorDidFinish(self)
    })
  }
}
