import Dispatch
import UIKit

protocol ImportCoordinatorDelegate: class {
  func importCoordinatorDidFinish(_ coordinator: ImportCoordinator)
}

class ImportCoordinator: NSObject, CustomPresentableCoordinator {
  typealias Dependencies = LibraryDependency & MovieDbDependency

  var rootViewController: UIViewController {
    return navigationController
  }
  weak var delegate: ImportCoordinatorDelegate?
  private let dependencies: Dependencies
  private let importUrl: URL

  private let navigationController = UINavigationController()

  init(importUrl: URL, dependencies: Dependencies) {
    self.importUrl = importUrl
    self.dependencies = dependencies
    super.init()
    navigationController.navigationBar.isTranslucent = false
    navigationController.navigationBar.shadowImage = UIImage()
    navigationController.navigationBar.setBackgroundImage(UIImage(), for: .default)
    navigationController.delegate = self
    showImportingPage()
  }

  private func showPage(_ page: UIViewController) {
    page.navigationItem.hidesBackButton = true
    navigationController.pushViewController(page, animated: true)
  }
}

extension ImportCoordinator: UINavigationControllerDelegate {
  func navigationController(_ navigationController: UINavigationController,
                            animationControllerFor operation: UINavigationControllerOperation,
                            from fromVC: UIViewController,
                            to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    switch operation {
      case .push:
        return ScrollAnimator(isPresenting: true)
      default:
        return ScrollAnimator(isPresenting: false)
    }
  }
}

private class ScrollAnimator: NSObject, UIViewControllerAnimatedTransitioning {
  private var duration: TimeInterval
  private var isPresenting: Bool

  init(isPresenting: Bool) {
    self.duration = 0.3
    self.isPresenting = isPresenting
  }

  func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
    guard let fromView = transitionContext.view(forKey: UITransitionContextViewKey.from) else { return }
    guard let toView = transitionContext.view(forKey: UITransitionContextViewKey.to) else { return }
    transitionContext.containerView.addSubview(toView)
    let width = (isPresenting ? 1 : -1) * fromView.frame.size.width
    toView.frame.origin.x += width
    UIView.animate(withDuration: duration,
                   animations: {
                     fromView.frame.origin.x -= width
                     toView.frame.origin.x -= width
                   },
                   completion: { _ in
                     transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                   })
  }

  func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
    return duration
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
