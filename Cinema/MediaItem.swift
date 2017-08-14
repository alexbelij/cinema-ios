struct MediaItem: Equatable, Hashable {
  let id: Int
  let title: String
  let subtitle: String?
  let runtime: Int?
  let year: Int?
  let diskType: DiskType
  let genreIds: [Int]

  init(id: Int, title: String, subtitle: String? = nil,
       runtime: Int? = nil, year: Int? = nil, diskType: DiskType = .bluRay,
       genreIds: [Int]) {
    self.id = id
    self.title = title
    self.subtitle = subtitle
    if let runtime = runtime, runtime > 0 {
      self.runtime = runtime
    } else {
      self.runtime = nil
    }
    if let year = year, year > 0 {
      self.year = year
    } else {
      self.year = nil
    }
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
    guard lhs.year == rhs.year else { return false }
    guard lhs.diskType == rhs.diskType else { return false }
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
  let year: Int?

  static func == (lhs: PartialMediaItem, rhs: PartialMediaItem) -> Bool {
    guard lhs.id == rhs.id else { return false }
    guard lhs.title == rhs.title else { return false }
    guard lhs.year == rhs.year else { return false }
    return true
  }

  var hashValue: Int {
    return id
  }
}
