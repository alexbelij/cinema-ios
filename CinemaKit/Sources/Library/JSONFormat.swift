import Foundation
import SwiftyJSON

public class JSONFormat: DataFormat {
  public var defaultSchemaVersion: SchemaVersion?

  public init() {
  }

  public func serialize(_ elements: [Movie], schemaVersion: SchemaVersion) throws -> Data {
    switch schemaVersion {
      case .v1_0_0: return try serializeVersion1_0_0(elements)
      case .v2_0_0: return try serializeVersion2_0_0(elements)
    }
  }

  public func deserialize(from data: Data) throws -> [Movie] {
    let version = try schemaVersion(of: data)
    switch version {
      case .v1_0_0: return try deserializeVersion1_0_0(from: JSON(data: data))
      case .v2_0_0: return try deserializeVersion2_0_0(from: JSON(data: data))
    }
  }

  public func schemaVersion(of data: Data) throws -> SchemaVersion {
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
  private func serializeVersion2_0_0(_ elements: [Movie]) throws -> Data {
    let payload: [JSON] = elements.map { movie in
      var dictionary: [String: Any] = [
        "id": movie.tmdbID.rawValue,
        "title": movie.title,
        "diskType": movie.diskType.rawValue,
        "genreIds": movie.genreIds.map { $0.rawValue }
      ]
      if let subtitle = movie.subtitle {
        dictionary["subtitle"] = subtitle
      }
      if let runtime = movie.runtime {
        dictionary["runtime"] = Int(runtime.converted(to: UnitDuration.minutes).value)
      }
      if let releaseDate = movie.releaseDate {
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

  private func deserializeVersion2_0_0(from json: JSON) throws -> [Movie] {
    var movies = [Movie]()
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
        let movie = Movie(tmdbID: id,
                          title: title,
                          subtitle: subtitle,
                          runtime: runtime,
                          releaseDate: releaseDate,
                          diskType: diskType,
                          genreIds: genreIds)
        movies.append(movie)
      } else {
        throw DataFormatError.invalidDataFormat
      }
    }
    return movies
  }
}

// MARK: - Version 1-0-0

extension JSONFormat {
  private func serializeVersion1_0_0(_ elements: [Movie]) throws -> Data {
    let jsonArray: [JSON] = elements.map { movie in
      var dictionary: [String: Any] = [
        "id": movie.tmdbID.rawValue,
        "title": movie.title,
        "runtime": movie.runtime.map { Int($0.converted(to: UnitDuration.minutes).value) } ?? -1,
        "year": movie.releaseDate.map { Int(DataFormatFormatters.v1DateFormatter.string(from: $0))! } ?? -1,
        "diskType": movie.diskType.rawValue
      ]
      if let subtitle = movie.subtitle {
        dictionary["subtitle"] = subtitle
      }
      return JSON(dictionary)
    }
    return try JSON(jsonArray).rawData(options: .prettyPrinted)
  }

  private func deserializeVersion1_0_0(from json: JSON) throws -> [Movie] {
    var movies = [Movie]()
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
        let movie = Movie(tmdbID: id,
                          title: title,
                          subtitle: subtitle,
                          runtime: runtime,
                          releaseDate: releaseDate,
                          diskType: diskType,
                          genreIds: [])
        movies.append(movie)
      } else {
        throw DataFormatError.invalidDataFormat
      }
    }
    return movies
  }
}
