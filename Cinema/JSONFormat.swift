import Foundation
import SwiftyJSON

class JSONFormat: DataFormat {

  func serialize(_ elements: [MediaItem]) throws -> Data {
    let jsonArray: [JSON] = elements.map { item in
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
      return JSON(dictionary)
    }
    return try JSON(array: jsonArray).rawData(options: .prettyPrinted)
  }

  func deserialize(from data: Data) throws -> [MediaItem] {
    var items = [MediaItem]()
    let jsonData = JSON(data: data).arrayValue
    for jsonItem in jsonData {
      let id = jsonItem["id"].int
      let title = jsonItem["title"].string
      let subtitle = jsonItem["subtitle"].string
      let runtime = jsonItem["runtime"].int
      let year = jsonItem["year"].int
      let diskType = DiskType(rawValue: jsonItem["diskType"].string ?? "")
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