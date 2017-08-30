import Foundation
import UIKit

class Utils {

  static func formatDuration(_ duration: Int) -> String {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .full
    formatter.allowedUnits = [.hour, .minute]
    formatter.zeroFormattingBehavior = [.dropAll]

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

  static func localizedGenreNames(for genreIds: [Int]) -> [String] {
    return genreIds.map(localizedGenreName(for:)).filter { $0 != nil }.map { $0! }
  }

  // swiftlint:disable:next cyclomatic_complexity
  private static func localizedGenreName(for genreId: Int) -> String? {
    let key: String?
    switch genreId {
      case 12: key = "genre.adventure"
      case 14: key = "genre.fantasy"
      case 16: key = "genre.animation"
      case 18: key = "genre.drama"
      case 27: key = "genre.horror"
      case 28: key = "genre.action"
      case 35: key = "genre.comedy"
      case 36: key = "genre.history"
      case 37: key = "genre.western"
      case 53: key = "genre.thriller"
      case 80: key = "genre.crime"
      case 99: key = "genre.documentary"
      case 878: key = "genre.scienceFiction"
      case 9648: key = "genre.mystery"
      case 10402: key = "genre.music"
      case 10749: key = "genre.romance"
      case 10751: key = "genre.family"
      case 10752: key = "genre.war"
      case 10770: key = "genre.tvMovie"
      default: key = nil
    }
    if let key = key {
      return NSLocalizedString(key, comment: "")
    } else {
      return nil
    }
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

extension UIImage {
  static func genericPosterImage(minWidth: CGFloat) -> UIImage {
    let width: CGFloat
    switch minWidth {
      case 0...92:    width =  92
      case 93...154:  width = 154
      case 155...185: width = 185
      default:        fatalError("poster for min width \(minWidth) not yet added to project")
    }
    return UIImage(named: "GenericPoster-w\(width)")!
  }
}
