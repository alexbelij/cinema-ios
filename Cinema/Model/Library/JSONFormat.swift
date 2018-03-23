import Foundation
import SwiftyJSON

class JSONFormat: DataFormat {

  var defaultSchemaVersion: SchemaVersion?

  func serialize(_ elements: [MediaItem], schemaVersion: SchemaVersion) throws -> Data {
    switch schemaVersion {
      case .v1_0_0: return try serializeVersion1_0_0(elements)
      case .v2_0_0: return try serializeVersion2_0_0(elements)
    }
  }

  func deserialize(from data: Data) throws -> [MediaItem] {
    let version = try schemaVersion(of: data)
    switch version {
      case .v1_0_0: return try deserializeVersion1_0_0(from: JSON(data: data))
      case .v2_0_0: return try deserializeVersion2_0_0(from: JSON(data: data))
    }
  }

  func schemaVersion(of data: Data) throws -> SchemaVersion {
    let json = JSON(data: data)
    if json.type == .null {
      throw DataFormatError.invalidDataFormat
    }
    let versionString = json[String.schemaVersionKey].string ?? SchemaVersion.v1_0_0.versionString
    guard let version = SchemaVersion(versionString: versionString) else {
      throw DataFormatError.unsupportedSchemaVersion(versionString: versionString)
    }
    return version
  }
}

// MARK: - Version 2-0-0

extension JSONFormat {
  private func serializeVersion2_0_0(_ elements: [MediaItem]) throws -> Data {
    let payload: [JSON] = elements.map { item in
      var dictionary: [String: Any] = [
        "id": item.tmdbID.rawValue,
        "title": item.title,
        "diskType": item.diskType.rawValue,
        "genreIds": item.genreIds.map { $0.rawValue }
      ]
      if let subtitle = item.subtitle {
        dictionary["subtitle"] = subtitle
      }
      if let runtime = item.runtime {
        dictionary["runtime"] = Int(runtime.converted(to: UnitDuration.minutes).value)
      }
      if let releaseDate = item.releaseDate {
        dictionary["releaseDate"] = DataFormatFormatters.v2DateFormatter.string(from: releaseDate)
      }
      return JSON(dictionary)
    }
    let jsonDict: [String: JSON] = [
      .schemaVersionKey: JSON(SchemaVersion.v2_0_0.versionString),
      .payloadKey: JSON(payload)
    ]
    return try JSON(jsonDict).rawData(options: .prettyPrinted)
  }

  private func deserializeVersion2_0_0(from json: JSON) throws -> [MediaItem] {
    var items = [MediaItem]()
    for jsonItem in json[String.payloadKey].arrayValue {
      let id = jsonItem["id"].int.map(TmdbIdentifier.init)
      let title = jsonItem["title"].string
      let subtitle = jsonItem["subtitle"].string
      let runtime = jsonItem["runtime"].int.map { Measurement(value: Double($0), unit: UnitDuration.minutes) }
      let releaseDate = jsonItem["releaseDate"].string.flatMap { DataFormatFormatters.v2DateFormatter.date(from: $0) }
      let diskType = DiskType(rawValue: jsonItem["diskType"].string ?? "")
      let genreIds: [GenreIdentifier]
      if let ids = jsonItem["genreIds"].array {
        genreIds = ids.map { GenreIdentifier(rawValue: $0.int!) }
      } else {
        genreIds = []
      }
      if let id = id, let title = title, let diskType = diskType {
        let mediaItem = MediaItem(tmdbID: id,
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
}

// MARK: - Version 1-0-0

extension JSONFormat {
  private func serializeVersion1_0_0(_ elements: [MediaItem]) throws -> Data {
    let jsonArray: [JSON] = elements.map { item in
      var dictionary: [String: Any] = [
        "id": item.tmdbID.rawValue,
        "title": item.title,
        "runtime": item.runtime.map { Int($0.converted(to: UnitDuration.minutes).value) } ?? -1,
        "year": item.releaseDate.map { Int(DataFormatFormatters.v1DateFormatter.string(from: $0))! } ?? -1,
        "diskType": item.diskType.rawValue
      ]
      if let subtitle = item.subtitle {
        dictionary["subtitle"] = subtitle
      }
      return JSON(dictionary)
    }
    return try JSON(jsonArray).rawData(options: .prettyPrinted)
  }

  private func deserializeVersion1_0_0(from json: JSON) throws -> [MediaItem] {
    var items = [MediaItem]()
    for jsonItem in json.arrayValue {
      let id = jsonItem["id"].int.map(TmdbIdentifier.init)
      let title = jsonItem["title"].string
      let subtitle = jsonItem["subtitle"].string
      let runtime: Measurement<UnitDuration>?
      if let rawRuntime = jsonItem["runtime"].int, rawRuntime > 0 {
        runtime = Measurement(value: Double(rawRuntime), unit: UnitDuration.minutes)
      } else {
        runtime = nil
      }
      let year = jsonItem["year"].int
      let diskType = DiskType(rawValue: jsonItem["diskType"].string ?? "")
      if let id = id, let title = title, let runtime = runtime, let year = year, let diskType = diskType {
        let releaseDate: Date?
        if year > 0 {
          releaseDate = DataFormatFormatters.v1DateFormatter.date(from: String(year))!
        } else {
          releaseDate = nil
        }
        let mediaItem = MediaItem(tmdbID: id,
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
