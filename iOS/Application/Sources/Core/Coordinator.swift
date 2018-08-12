import UIKit

protocol Coordinator: class {
}

protocol AutoPresentableCoordinator: Coordinator {
  func presentRootViewController()
}

protocol CustomPresentableCoordinator: Coordinator {
  var rootViewController: UIViewController { get }
}
