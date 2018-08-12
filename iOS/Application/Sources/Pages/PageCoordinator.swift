import UIKit

class PageCoordinator: NSObject, CustomPresentableCoordinator {
  var rootViewController: UIViewController {
    return navigationController
  }
  private let navigationController = UINavigationController()
  private var isPresenting = false
  private let transitionDuration: TimeInterval = 0.3

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
    isPresenting = operation == .push
    return self
  }
}

extension PageCoordinator: UIViewControllerAnimatedTransitioning {
  func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
    guard let fromView = transitionContext.view(forKey: UITransitionContextViewKey.from) else { return }
    guard let toView = transitionContext.view(forKey: UITransitionContextViewKey.to) else { return }
    transitionContext.containerView.addSubview(toView)
    let width = (isPresenting ? 1 : -1) * fromView.frame.size.width
    toView.frame.origin.x += width
    UIView.animate(withDuration: transitionDuration,
                   animations: {
                     fromView.frame.origin.x -= width
                     toView.frame.origin.x -= width
                   },
                   completion: { _ in
                     transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                   })
  }

  func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
    return transitionDuration
  }
}
