import CinemaKit
import Dispatch
import UIKit

protocol ImportCoordinatorDelegate: class {
  func importCoordinatorDidFinish(_ coordinator: ImportCoordinator)
}

class ImportCoordinator: PageCoordinator {
  typealias Dependencies = LibraryDependency & MovieDbDependency

  weak var delegate: ImportCoordinatorDelegate?
  private let dependencies: Dependencies
  private let importUrl: URL

  init(importUrl: URL, dependencies: Dependencies) {
    self.importUrl = importUrl
    self.dependencies = dependencies
    super.init()
    showContinuePage(primaryText: "Imports are currently disabled.",
                     secondaryText: "Please check back later.")
  }
}

extension ImportCoordinator {
  private func showContinuePage(primaryText: String, secondaryText: String) {
    showPage(ActionPage.initWith(primaryText: primaryText,
                                 secondaryText: secondaryText,
                                 actionTitle: NSLocalizedString("continue", comment: "")) { [weak self] in
      guard let `self` = self else { return }
      self.delegate?.importCoordinatorDidFinish(self)
    })
  }
}
