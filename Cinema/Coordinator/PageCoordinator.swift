import UIKit

class PageCoordinator: NSObject, CustomPresentableCoordinator {
  var rootViewController: UIViewController {
    return navigationController
  }
  private let navigationController = UINavigationController()

  override init() {
    super.init()
    navigationController.navigationBar.isTranslucent = false
    navigationController.navigationBar.shadowImage = UIImage()
    navigationController.navigationBar.setBackgroundImage(UIImage(), for: .default)
    navigationController.delegate = self
  }

  func showPage(_ page: UIViewController) {
    page.navigationItem.hidesBackButton = true
    navigationController.pushViewController(page, animated: true)
  }
}

extension PageCoordinator: UINavigationControllerDelegate {
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
