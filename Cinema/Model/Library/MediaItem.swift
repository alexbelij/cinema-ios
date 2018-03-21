import Foundation

struct TmdbIdentifier: RawRepresentable, CustomStringConvertible, Hashable {
  let rawValue: Int

  init(rawValue: Int) {
    self.rawValue = rawValue
  }

  var description: String {
    return String(rawValue)
  }
}

struct GenreIdentifier: RawRepresentable, CustomStringConvertible, Hashable {
  let rawValue: Int

  init(rawValue: Int) {
    self.rawValue = rawValue
  }

  var description: String {
    return String(rawValue)
  }
}

struct MediaItem: Hashable {
  let tmdbID: TmdbIdentifier
  var title: String
  var subtitle: String?
  let runtime: Measurement<UnitDuration>?
  var releaseDate: Date?
  let diskType: DiskType
  var genreIds: [GenreIdentifier]

  init(tmdbID: TmdbIdentifier,
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

  var fullTitle: String {
    if let subtitle = subtitle {
      return "\(title): \(subtitle)"
    } else {
      return title
    }
  }

  var hashValue: Int {
    return tmdbID.rawValue
  }
}

enum DiskType: String {
  case dvd, bluRay
}

struct PartialMediaItem: Hashable {
  let tmdbID: TmdbIdentifier
  let title: String
  let releaseDate: Date?

  var hashValue: Int {
    return tmdbID.rawValue
  }
}
