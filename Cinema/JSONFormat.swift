import Foundation
import SwiftyJSON

class JSONFormat: DataFormat {

  var defaultSchemaVersion: SchemaVersion?

  func serialize(_ elements: [MediaItem], schemaVersion: SchemaVersion) throws -> Data {
    switch schemaVersion {
      case .v1_0_0: return try serializeVersion1_0_0(elements)
    }
  }

  func deserialize(from data: Data) throws -> [MediaItem] {
    let json = JSON(data: data)
    if json.type == .null {
      throw DataFormatError.invalidDataFormat
    }
    let versionString = json["schemaVersion"].string ?? SchemaVersion.v1_0_0.versionString
    guard let version = SchemaVersion(versionString: versionString) else {
      throw DataFormatError.unsupportedSchemaVersion(versionString: versionString)
    }
    switch version {
      case .v1_0_0: return try deserializeVersion1_0_0(from: json)
    }
  }

  // MARK: - Version 1-0-0

  private func serializeVersion1_0_0(_ elements: [MediaItem]) throws -> Data {
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

  private func deserializeVersion1_0_0(from json: JSON) throws -> [MediaItem] {
    var items = [MediaItem]()
    for jsonItem in json.arrayValue {
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
