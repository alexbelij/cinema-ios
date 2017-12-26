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
}

// MARK: - Localization

extension DiskType {
  var localizedName: String {
    switch self {
      case .dvd: return NSLocalizedString("mediaItem.disk.dvd", comment: "")
      case .bluRay: return NSLocalizedString("mediaItem.disk.bluRay", comment: "")
    }
  }
}

extension Array where Array.Element == Int {
  var localizedGenreNames: [String] {
    return map(localizedGenreName(for:)).filter { $0 != nil }.map { $0! }
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func localizedGenreName(for genreId: Int) -> String? {
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

extension Utils {
  static func localizedErrorMessage(for error: Error) -> String {
    switch error {
      case DataFormatError.unsupportedSchemaVersion:
        return NSLocalizedString("error.unsupportedSchemaVersion", comment: "")
      case DataFormatError.invalidDataFormat:
        return NSLocalizedString("error.invalidDataFormat", comment: "")
      case MediaLibraryError.storageError:
        return NSLocalizedString("error.storageError", comment: "")
      default:
        return NSLocalizedString("error.genericError", comment: "")
    }
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
  static var addItem = UIStoryboard(name: "AddItem", bundle: nil)
  static var editItem = UIStoryboard(name: "EditItem", bundle: nil)
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
  static let destructive = UIColor(red: 1.0, green: 0.231, blue: 0.188, alpha: 1.0)
  static let posterBorder = UIColor(red: 0, green: 0, blue: 0, alpha: 0.2)
  static let dimBackground = UIColor(red: 0, green: 0, blue: 0, alpha: 0.4)
  // swiftlint:enable object_literal
}

extension String {
  var nilIfEmptyString: String? {
    return self.isEmpty ? nil : self
  }
}
