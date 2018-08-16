import Foundation

public struct TmdbIdentifier: RawRepresentable, CustomStringConvertible, Hashable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  public var description: String {
    return String(rawValue)
  }
}

public struct GenreIdentifier: RawRepresentable, CustomStringConvertible, Hashable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  public var description: String {
    return String(rawValue)
  }
}

public struct Movie {
  public let tmdbID: TmdbIdentifier
  public var title: String
  public var subtitle: String?
  public let diskType: DiskType
  public let runtime: Measurement<UnitDuration>?
  public let releaseDate: Date?
  public let genreIds: [GenreIdentifier]
  public let certification: String?
  public let overview: String?

  public init(tmdbID: TmdbIdentifier,
              title: String,
              subtitle: String? = nil,
              diskType: DiskType = .bluRay,
              runtime: Measurement<UnitDuration>? = nil,
              releaseDate: Date? = nil,
              genreIds: [GenreIdentifier] = [],
              certification: String? = nil,
              overview: String? = nil) {
    self.tmdbID = tmdbID
    self.title = title
    self.subtitle = subtitle
    self.diskType = diskType
    self.runtime = runtime
    self.releaseDate = releaseDate
    self.genreIds = genreIds
    self.certification = certification
    self.overview = overview
  }

  public var fullTitle: String {
    if let subtitle = subtitle {
      return "\(title): \(subtitle)"
    } else {
      return title
    }
  }
}

public enum DiskType: String {
  case dvd, bluRay
}

extension Collection where Element == Movie {
  public func index(of movie: Movie) -> Index? {
    return index { $0.tmdbID == movie.tmdbID }
  }
}
