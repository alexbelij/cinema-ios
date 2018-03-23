import Foundation
import UIKit

class Utils {
  private static let durationFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .full
    formatter.allowedUnits = [.hour, .minute]
    formatter.zeroFormattingBehavior = [.dropAll]
    return formatter
  }()

  static func formatDuration(_ duration: Measurement<UnitDuration>) -> String {
    return durationFormatter.string(from: duration.converted(to: UnitDuration.seconds).value)!
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

// MARK: - Migration

extension Utils {
  static func updates(from version: SchemaVersion, using movieDb: MovieDbClient) -> [PropertyUpdate] {
    switch version {
      case .v1_0_0: return [GenreIdsUpdate(movieDb: movieDb), ReleaseDateUpdate(movieDb: movieDb)]
      case .v2_0_0: return []
    }
  }
}

// MARK: - Other Extensions

extension UIStoryboard {
  static var movieList = UIStoryboard(name: "MovieList", bundle: nil)
  static var searchTmdb = UIStoryboard(name: "SearchTmdb", bundle: nil)
  static var popularMovies = UIStoryboard(name: "PopularMovies", bundle: nil)
  static var editItem = UIStoryboard(name: "EditItem", bundle: nil)
  static var genreList = UIStoryboard(name: "GenreList", bundle: nil)
  static var maintenance = UIStoryboard(name: "Maintenance", bundle: nil)

  func instantiate<ViewController: UIViewController>(_ viewController: ViewController.Type) -> ViewController {
    let identifier = String(describing: viewController)
    guard let controller = instantiateViewController(withIdentifier: identifier)
    as? ViewController else {
      fatalError("could not instantiate view controller with identifier \(identifier) ")
    }
    return controller
  }
}

extension UIImage {
  static func genericPosterImage(minWidth: CGFloat) -> UIImage {
    let width: CGFloat
    switch minWidth {
      case 0...92: width = 92
      case 93...154: width = 154
      case 155...185: width = 185
      default: fatalError("poster for min width \(minWidth) not yet added to project")
    }
    return UIImage(named: "GenericPoster-w\(width)")!
  }
}

extension UIColor {
  // swiftlint:disable object_literal
  static let disabledControlText = UIColor(white: 0.58, alpha: 1.0)
  static let secondaryText = UIColor(white: 0.5, alpha: 1.0)
  static let destructive = UIColor(red: 1.0, green: 0.231, blue: 0.188, alpha: 1.0)
  static let posterBorder = UIColor(red: 0, green: 0, blue: 0, alpha: 0.2)
  static let dimBackground = UIColor(red: 0, green: 0, blue: 0, alpha: 0.4)
  static let missingArtworkBackground = UIColor(white: 0.88, alpha: 1.0)
  // swiftlint:enable object_literal
}

extension String {
  var nilIfEmptyString: String? {
    return self.isEmpty ? nil : self
  }
}
