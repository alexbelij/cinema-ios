import CinemaKit
import Foundation

enum L10n {
  // swiftlint:disable:next cyclomatic_complexity
  static func genreName(for genreId: GenreIdentifier) -> String? {
    let key: String?
    switch genreId.rawValue {
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

extension DiskType {
  var localizedName: String {
    switch self {
      case .dvd: return NSLocalizedString("diskType.dvd", comment: "")
      case .bluRay: return NSLocalizedString("diskType.bluRay", comment: "")
    }
  }
}
