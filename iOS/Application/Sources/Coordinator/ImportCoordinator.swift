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
    showImportingPage()
  }
}

extension ImportCoordinator {
  private func showImportingPage() {
    let importAndUpdateAction = ImportAndUpdateAction(library: dependencies.library,
                                                      movieDb: dependencies.movieDb,
                                                      from: importUrl)
    showPage(ProgressPage.initWith(primaryText: NSLocalizedString("import.progress", comment: ""),
                                   progress: importAndUpdateAction.progress))
    DispatchQueue.global(qos: .userInitiated).async {
      importAndUpdateAction.performAction { result in
        switch result {
          case let .result(addedItems):
            let count = addedItems.count
            DispatchQueue.main.async {
              let format = NSLocalizedString("import.succeeded.changes", comment: "")
              self.showContinuePage(primaryText: NSLocalizedString("import.succeeded", comment: ""),
                                    secondaryText: .localizedStringWithFormat(format, count))
            }
          case let .error(error):
            DispatchQueue.main.async {
              self.showContinuePage(primaryText: NSLocalizedString("import.failed", comment: ""),
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
      self.delegate?.importCoordinatorDidFinish(self)
    })
  }
}
