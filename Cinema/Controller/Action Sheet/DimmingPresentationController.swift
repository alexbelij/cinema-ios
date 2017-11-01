import UIKit

class DimmingPresentationController: UIPresentationController {
  private let dimmingView: UIView = {
    let dimmingView = UIView()
    dimmingView.translatesAutoresizingMaskIntoConstraints = false
    dimmingView.backgroundColor = .dimBackground
    dimmingView.alpha = 0.0
    return dimmingView
  }()

  override func presentationTransitionWillBegin() {
    dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dimmingViewTapped)))
    containerView?.insertSubview(dimmingView, at: 0)
    presentingViewController.view.tintAdjustmentMode = .dimmed
    presentedViewController.transitionCoordinator!.animate(alongsideTransition: { _ in self.dimmingView.alpha = 1.0 },
                                                           completion: nil)
  }

  @objc
  private func dimmingViewTapped() {
    presentedViewController.dismiss(animated: true)
  }

  override func containerViewDidLayoutSubviews() {
    super.containerViewDidLayoutSubviews()
    dimmingView.frame = frameOfPresentedViewInContainerView
  }

  override func dismissalTransitionWillBegin() {
    presentingViewController.view.tintAdjustmentMode = .automatic
    presentedViewController.transitionCoordinator!.animate(alongsideTransition: { _ in self.dimmingView.alpha = 0.0 },
                                                           completion: nil)
  }
}
