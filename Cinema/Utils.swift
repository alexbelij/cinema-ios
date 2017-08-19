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

  static func directoryUrl(for directory: FileManager.SearchPathDirectory,
                           createIfNecessary: Bool = true) -> URL {
    let fileManager = FileManager.default
    let dir = fileManager.urls(for: directory, in: .userDomainMask).first!
    do {
      var isDirectory: ObjCBool = false
      if !(FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDirectory)
           && isDirectory.boolValue) {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
      }
    } catch {
      fatalError("Could not create \(dir)")
    }
    return dir
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
