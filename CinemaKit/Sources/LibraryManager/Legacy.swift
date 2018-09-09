import Foundation

enum Legacy {
  struct LegacyMovieData {
    let tmdbID: TmdbIdentifier
    let title: String
    let subtitle: String?
    let diskType: DiskType
  }

  static func deserialize(from data: Data) -> [LegacyMovieData] {
    let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
    // swiftlint:disable force_cast
    let array = unarchiver.containsValue(forKey: "payload")
        ? unarchiver.decodeObject(forKey: "payload") as! [[String: Any]]
        : NSKeyedUnarchiver.unarchiveObject(with: data) as! [[String: Any]]
    // swiftlint:enable force_cast
    unarchiver.finishDecoding()
    var movies = [LegacyMovieData]()
    for dict in array {
      let id = (dict["id"] as? Int).map(TmdbIdentifier.init)!
      // swiftlint:disable:next force_cast
      let title = dict["title"] as! String
      let subtitle = dict["subtitle"] as? String
      let diskType = DiskType(rawValue: dict["diskType"] as? String ?? "")!
      movies.append(LegacyMovieData(tmdbID: id, title: title, subtitle: subtitle, diskType: diskType))
    }
    return movies
  }
}
