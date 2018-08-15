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
  public let runtime: Measurement<UnitDuration>?
  public var releaseDate: Date?
  public let diskType: DiskType
  public var genreIds: [GenreIdentifier]

  public init(tmdbID: TmdbIdentifier,
              title: String,
              subtitle: String? = nil,
              runtime: Measurement<UnitDuration>? = nil,
              releaseDate: Date? = nil,
              diskType: DiskType = .bluRay,
              genreIds: [GenreIdentifier] = []) {
    self.tmdbID = tmdbID
    self.title = title
    self.subtitle = subtitle
    self.runtime = runtime
    self.releaseDate = releaseDate
    self.diskType = diskType
    self.genreIds = genreIds
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
