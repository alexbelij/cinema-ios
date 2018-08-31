import Foundation

enum Legacy {
  struct LegacyMovieData {
    let tmdbID: TmdbIdentifier
    let title: String
    let subtitle: String?
    let diskType: DiskType
  }

  static func deserialize(from data: Data) -> [LegacyMovieData] {
    let array: [[String: Any]]
    let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
    if unarchiver.containsValue(forKey: "payload") {
      // swiftlint:disable:next force_cast
      array = unarchiver.decodeObject(forKey: "payload") as! [[String: Any]]
    } else {
      array = NSKeyedUnarchiver.unarchiveObject(with: data) as! [[String: Any]]
    }
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
