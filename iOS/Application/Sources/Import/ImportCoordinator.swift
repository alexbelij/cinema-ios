import CinemaKit
import Dispatch
import UIKit

protocol ImportCoordinatorDelegate: class {
  func importCoordinatorDidFinish(_ coordinator: ImportCoordinator)
}

class ImportCoordinator: PageCoordinator {
  weak var delegate: ImportCoordinatorDelegate?
  private let movieDb: MovieDbClient
  private let importUrl: URL

  init(importUrl: URL, dependencies: AppDependencies) {
    self.importUrl = importUrl
    self.movieDb = dependencies.movieDb
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
