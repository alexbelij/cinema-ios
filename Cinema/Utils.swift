import Foundation
import UIKit

class Utils {

  static func formatDuration(_ duration: Int) -> String {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .full
    formatter.allowedUnits = [ .hour, .minute ]
    formatter.zeroFormattingBehavior = [ .dropAll ]

    return formatter.string(from: Double(duration * 60))!
  }
}

extension UIStoryboardSegue {
  var unwrappedDestination: UIViewController {
    switch destination {
      case let navigation as UINavigationController:
        return navigation.topViewController!
      default:
        return destination
    }
  }
}
