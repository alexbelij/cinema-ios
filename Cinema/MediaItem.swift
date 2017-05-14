struct MediaItem {
  let id: Int
  let title: String
  let subtitle: String?
  let runtime: Int
  let year: Int
  let diskType: DiskType

  init(id: Int, title: String, subtitle: String? = nil,
       runtime: Int, year: Int, diskType: DiskType = .bluRay) {
    self.id = id
    self.title = title
    self.subtitle = subtitle
    self.runtime = runtime
    self.year = year
    self.diskType = diskType
  }
}

enum DiskType: String {
  case dvd, bluRay
}
