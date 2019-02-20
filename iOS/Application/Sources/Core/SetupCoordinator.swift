import CinemaKit
import Dispatch
import UIKit

class SetupCoordinator: PageCoordinator {
  enum State {
    case initializingCloud
    case foundLegacyData((Bool) -> Void)
    case migratingFailed
    case finished(() -> Void)
  }

  func change(to newState: State) {
    DispatchQueue.main.async {
      switch newState {
        case .initializingCloud:
          self.showPage(WaitingPage.initWith(primaryText: NSLocalizedString("setup.initializing", comment: "")))
        case let .foundLegacyData(shouldMigrateDecision):
          let page = ActionPage.initWith(
              primaryText: NSLocalizedString("setup.uploadMovies", comment: ""),
              secondaryText: NSLocalizedString("setup.uploadMovies.secondaryText", comment: ""),
              image: #imageLiteral(resourceName: "CloudUpload"),
              primaryActionTitle: NSLocalizedString("setup.uploadMovies", comment: ""),
              primaryActionHandler: { [weak self] in
                guard let `self` = self else { return }
                shouldMigrateDecision(true)
                self.showPage(WaitingPage.initWith(
                    primaryText: NSLocalizedString("setup.uploading", comment: ""),
                    secondaryText: NSLocalizedString("thisMayTakeSomeTime", comment: "")))
              },
              secondaryActionTitle: NSLocalizedString("setup.startFresh", comment: ""),
              secondaryActionHandler: { self.showFreshStartAlert { shouldMigrateDecision(false) } })
          self.showPage(page)
        case .migratingFailed:
          self.showPage(ActionPage.initWith(primaryText: NSLocalizedString("setup.upload.failed", comment: ""),
                                            secondaryText: NSLocalizedString("error.tryAgain", comment: ""),
                                            image: #imageLiteral(resourceName: "CloudFailure")))
        case let .finished(continuation):
          self.showPage(ActionPage.initWith(
              primaryText: NSLocalizedString("setup.complete", comment: ""),
              secondaryText: NSLocalizedString("setup.complete.secondaryText", comment: ""),
              actionTitle: NSLocalizedString("continue", comment: "")) { continuation() })
      }
    }
  }

  private func showFreshStartAlert(confirmation: @escaping () -> Void) {
    let alert = UIAlertController(title: NSLocalizedString("setup.startFresh.alert.title", comment: ""),
                                  message: NSLocalizedString("setup.startFresh.alert.message", comment: ""),
                                  preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: NSLocalizedString("setup.startFresh.alert.delete", comment: ""),
                                  style: .destructive) { _ in confirmation() })
    alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel) { _ in })
    rootViewController.present(alert, animated: true)
  }
}
