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
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let payload: [[String: Any]] = elements.map { item in
      var dictionary: [String: Any] = [
        "id": item.id,
        "title": item.title,
        "diskType": item.diskType.rawValue,
        "genreIds": item.genreIds
      ]
      if let subtitle = item.subtitle {
        dictionary["subtitle"] = subtitle
      }
      if let runtime = item.runtime {
        dictionary["runtime"] = runtime
      }
      if let releaseDate = item.releaseDate {
        dictionary["releaseDate"] = dateFormatter.string(from: releaseDate)
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
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    var items = [MediaItem]()
    for dict in array {
      let id = dict["id"] as? Int
      let title = dict["title"] as? String
      let subtitle = dict["subtitle"] as? String
      let runtime = dict["runtime"] as? Int
      let releaseDate = (dict["releaseDate"] as? String).flatMap { dateFormatter.date(from: $0) }
      let diskType = DiskType(rawValue: dict["diskType"] as? String ?? "")
      let genreIds = dict["genreIds"] as? [Int] ?? []
      if let id = id, let title = title, let diskType = diskType {
        let mediaItem = MediaItem(id: id,
                                  title: title,
                                  subtitle: subtitle,
                                  runtime: runtime,
                                  releaseDate: releaseDate,
                                  diskType: diskType,
                                  genreIds: genreIds)
        items.append(mediaItem)
      } else {
        throw DataFormatError.invalidDataFormat
      }
    }
    return items
  }

  // MARK: - Version 1-0-0

  private func serializeVersion1_0_0(_ elements: [MediaItem]) throws -> Data {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy"
    let rootObject: [[String: Any]] = elements.map { item in
      var dictionary: [String: Any] = [
        "id": item.id,
        "title": item.title,
        "runtime": item.runtime ?? -1,
        "year": item.releaseDate.map { dateFormatter.string(from: $0) } ?? -1,
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
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy"
    for dict in array {
      let id = dict["id"] as? Int
      let title = dict["title"] as? String
      let subtitle = dict["subtitle"] as? String
      let runtime = dict["runtime"] as? Int
      let year = dict["year"] as? Int
      let diskType = DiskType(rawValue: dict["diskType"] as? String ?? "")
      if let id = id, let title = title, let runtime = runtime, let year = year, let diskType = diskType {
        let releaseDate: Date?
        if year > 0 {
          releaseDate = dateFormatter.date(from: String(year))!
        } else {
          releaseDate = nil
        }
        let mediaItem = MediaItem(id: id,
                                  title: title,
                                  subtitle: subtitle,
                                  runtime: runtime,
                                  releaseDate: releaseDate,
                                  diskType: diskType,
                                  genreIds: [])
        items.append(mediaItem)
      } else {
        throw DataFormatError.invalidDataFormat
      }
    }
    return items
  }

}
