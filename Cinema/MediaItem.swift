import Foundation

struct MediaItem: Equatable, Hashable {
  let id: Int
  let title: String
  let subtitle: String?
  let runtime: Int?
  let releaseDate: Date?
  let diskType: DiskType
  let genreIds: [Int]

  init(id: Int,
       title: String,
       subtitle: String? = nil,
       runtime: Int? = nil,
       releaseDate: Date? = nil,
       diskType: DiskType = .bluRay,
       genreIds: [Int] = []) {
    self.id = id
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
    guard lhs.id == rhs.id else { return false }
    guard lhs.title == rhs.title else { return false }
    guard lhs.subtitle == rhs.subtitle else { return false }
    guard lhs.runtime == rhs.runtime else { return false }
    guard lhs.releaseDate == rhs.releaseDate else { return false }
    guard lhs.diskType == rhs.diskType else { return false }
    guard lhs.genreIds == rhs.genreIds else { return false }
    return true
  }

  var hashValue: Int {
    return id
  }

}

enum DiskType: String {
  case dvd, bluRay
}

struct PartialMediaItem: Equatable, Hashable {
  let id: Int
  let title: String
  let releaseDate: Date?

  static func == (lhs: PartialMediaItem, rhs: PartialMediaItem) -> Bool {
    guard lhs.id == rhs.id else { return false }
    guard lhs.title == rhs.title else { return false }
    guard lhs.releaseDate == rhs.releaseDate else { return false }
    return true
  }

  var hashValue: Int {
    return id
  }
}
