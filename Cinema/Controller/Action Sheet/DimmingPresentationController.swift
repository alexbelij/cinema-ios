import UIKit

class DimmingPresentationController: UIPresentationController {
  private let dimmingView: UIView = {
    let dimmingView = UIView()
    dimmingView.translatesAutoresizingMaskIntoConstraints = false
    dimmingView.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.4)
    dimmingView.alpha = 0.0
    return dimmingView
  }()

  override func presentationTransitionWillBegin() {
    containerView?.insertSubview(dimmingView, at: 0)
    presentedViewController.transitionCoordinator!.animate(alongsideTransition: { _ in self.dimmingView.alpha = 1.0 },
                                                           completion: nil)
  }

  override func containerViewDidLayoutSubviews() {
    super.containerViewDidLayoutSubviews()
    dimmingView.frame = frameOfPresentedViewInContainerView
  }

  override func dismissalTransitionWillBegin() {
    presentedViewController.transitionCoordinator!.animate(alongsideTransition: { _ in self.dimmingView.alpha = 0.0 },
                                                           completion: nil)
  }
}
