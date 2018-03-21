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

struct MediaItem: Equatable, Hashable {
  let tmdbID: TmdbIdentifier
  var title: String
  var subtitle: String?
  let runtime: Int?
  var releaseDate: Date?
  let diskType: DiskType
  var genreIds: [GenreIdentifier]

  init(tmdbID: TmdbIdentifier,
       title: String,
       subtitle: String? = nil,
       runtime: Int? = nil,
       releaseDate: Date? = nil,
       diskType: DiskType = .bluRay,
       genreIds: [GenreIdentifier] = []) {
    self.tmdbID = tmdbID
    self.title = title
    self.subtitle = subtitle
    if let runtime = runtime, runtime > 0 {
      self.runtime = runtime
    } else {
      self.runtime = nil
    }
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

  static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
    guard lhs.tmdbID == rhs.tmdbID else { return false }
    guard lhs.title == rhs.title else { return false }
    guard lhs.subtitle == rhs.subtitle else { return false }
    guard lhs.runtime == rhs.runtime else { return false }
    guard lhs.releaseDate == rhs.releaseDate else { return false }
    guard lhs.diskType == rhs.diskType else { return false }
    guard lhs.genreIds == rhs.genreIds else { return false }
    return true
  }

  var hashValue: Int {
    return tmdbID.rawValue
  }

}

enum DiskType: String {
  case dvd, bluRay
}

struct PartialMediaItem: Equatable, Hashable {
  let tmdbID: TmdbIdentifier
  let title: String
  let releaseDate: Date?

  static func == (lhs: PartialMediaItem, rhs: PartialMediaItem) -> Bool {
    guard lhs.tmdbID == rhs.tmdbID else { return false }
    guard lhs.title == rhs.title else { return false }
    guard lhs.releaseDate == rhs.releaseDate else { return false }
    return true
  }

  var hashValue: Int {
    return tmdbID.rawValue
  }
}
