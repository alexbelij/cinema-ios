import Foundation

class KeyedArchivalFormat: DataFormat {

  func serialize(_ elements: [MediaItem]) -> Data {
    let rootObject: [[String: Any]] = elements.map { item in
      var dictionary: [String: Any] = [
        "id": item.id,
        "title": item.title,
        "runtime": item.runtime,
        "year": item.year,
        "diskType": item.diskType.rawValue
      ]
      if let subtitle = item.subtitle {
        dictionary["subtitle"] = subtitle
      }
      return dictionary
    }
    return NSKeyedArchiver.archivedData(withRootObject: rootObject)
  }

  func deserialize(from data: Data) throws -> [MediaItem] {
    guard let array = NSKeyedUnarchiver.unarchiveObject(with: data) as? [[String: Any]] else {
      throw DataFormatError.invalidDataFormat
    }
    var items = [MediaItem]()
    for dict in array {
      let id = dict["id"] as? Int
      let title = dict["title"] as? String
      let subtitle = dict["subtitle"] as? String
      let runtime = dict["runtime"] as? Int
      let year = dict["year"] as? Int
      let diskType = DiskType(rawValue: dict["diskType"] as? String ?? "")
      if let id = id, let title = title, let runtime = runtime, let year = year, let diskType = diskType {
        let mediaItem = MediaItem(id: id,
                                  title: title,
                                  subtitle: subtitle,
                                  runtime: runtime,
                                  year: year,
                                  diskType: diskType)
        items.append(mediaItem)
      } else {
        throw DataFormatError.invalidDataFormat
      }
    }
    return items
  }

}
