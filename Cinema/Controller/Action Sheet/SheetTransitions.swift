import UIKit

class ContentViewPresentTransition: NSObject, UIViewControllerAnimatedTransitioning {
  public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
    return 0.4
  }

  public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
    let fromViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from)!
    let fromView = fromViewController.view!
    let toViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)!
    let toView = toViewController.view!

    transitionContext.containerView.addSubview(toView)
    UIView.animate(withDuration: transitionDuration(using: transitionContext),
                   delay: 0.0,
                   usingSpringWithDamping: 1.0,
                   initialSpringVelocity: 0.0,
                   options: [.curveEaseOut],
                   animations: {
                     toView.frame.origin.y = fromView.bounds.origin.y + fromView.bounds.height
                                             - toView.bounds.size.height
                   },
                   completion: { _ in
                     transitionContext.completeTransition(true)
                   })
  }
}

class ContentViewDismissTransition: NSObject, UIViewControllerAnimatedTransitioning {
  public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
    return 0.4
  }

  public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
    let fromViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from)!
    let fromView = fromViewController.view!
    let toViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)!
    let toView = toViewController.view!

    UIView.animate(withDuration: transitionDuration(using: transitionContext),
                   delay: 0.0,
                   usingSpringWithDamping: 1.0,
                   initialSpringVelocity: 0.0,
                   options: [.curveEaseIn],
                   animations: {
                     fromView.frame.origin.y = toView.bounds.origin.y + toView.bounds.height
                   },
                   completion: { _ in
                     fromView.removeFromSuperview()
                     transitionContext.completeTransition(true)
                   })
  }
}
