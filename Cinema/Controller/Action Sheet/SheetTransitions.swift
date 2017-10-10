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
    guard toView.subviews.count == 1 else { preconditionFailure("toView should have exactly one subview") }
    let contentView = toView.subviews.first!

    transitionContext.containerView.addSubview(toView)
    UIView.animate(withDuration: transitionDuration(using: transitionContext),
                   delay: 0.0,
                   usingSpringWithDamping: 1.0,
                   initialSpringVelocity: 0.0,
                   options: [.curveEaseOut],
                   animations: {
                     contentView.frame.origin.y = fromView.bounds.origin.y + fromView.bounds.height
                                                  - contentView.bounds.size.height
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
    guard fromView.subviews.count == 1 else { preconditionFailure("fromView should have exactly one subview") }
    let contentView = fromView.subviews.first!

    UIView.animate(withDuration: transitionDuration(using: transitionContext),
                   delay: 0.0,
                   usingSpringWithDamping: 1.0,
                   initialSpringVelocity: 0.0,
                   options: [.curveEaseIn],
                   animations: {
                     contentView.frame.origin.y = toView.bounds.origin.y + toView.bounds.height
                   },
                   completion: { _ in
                     fromView.removeFromSuperview()
                     transitionContext.completeTransition(true)
                   })
  }
}
