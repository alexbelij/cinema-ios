import Foundation

class KeyedArchivalFormat: DataFormat {

  var defaultSchemaVersion: SchemaVersion?

  func serialize(_ elements: [MediaItem], schemaVersion: SchemaVersion) throws -> Data {
    switch schemaVersion {
      case .v1_0_0: return try serializeVersion1_0_0(elements)
      case .v2_0_0: return try serializeVersion2_0_0(elements)
    }
  }

  func deserialize(from data: Data) throws -> [MediaItem] {
    // traps when invalid archive, but ignored since only used for internal model
    let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
    let versionString = (unarchiver.decodeObject(forKey: .schemaVersionKey) as? String)
                        ?? SchemaVersion.v1_0_0.versionString
    unarchiver.finishDecoding()
    guard let version = SchemaVersion(versionString: versionString) else {
      throw DataFormatError.unsupportedSchemaVersion(versionString: versionString)
    }
    switch version {
      case .v1_0_0: return try deserializeVersion1_0_0(from: data)
      case .v2_0_0: return try deserializeVersion2_0_0(from: data)
    }
  }

  // MARK: - Version 2-0-0

  private func serializeVersion2_0_0(_ elements: [MediaItem]) throws -> Data {
    let payload: [[String: Any]] = elements.map { item in
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
    let data = NSMutableData()
    let archiver = NSKeyedArchiver.init(forWritingWith: data)
    archiver.encode(SchemaVersion.v2_0_0.versionString, forKey: .schemaVersionKey)
    archiver.encode(payload, forKey: .payloadKey)
    archiver.finishEncoding()
    return data as Data
  }

  private func deserializeVersion2_0_0(from data: Data) throws -> [MediaItem] {
    let unarchiver = NSKeyedUnarchiver.init(forReadingWith: data)
    guard let array = unarchiver.decodeObject(forKey: .payloadKey) as? [[String: Any]] else {
      throw DataFormatError.invalidDataFormat
    }
    unarchiver.finishDecoding()
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

  // MARK: - Version 1-0-0

  private func serializeVersion1_0_0(_ elements: [MediaItem]) throws -> Data {
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

  private func deserializeVersion1_0_0(from data: Data) throws -> [MediaItem] {
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
