import Foundation

public class KeyedArchivalFormat: DataFormat {
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
      case .v1_0_0: return try deserializeVersion1_0_0(from: data)
      case .v2_0_0: return try deserializeVersion2_0_0(from: data)
    }
  }

  public func schemaVersion(of data: Data) throws -> SchemaVersion {
    // traps when invalid archive, but ignored since only used for internal model
    let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
    let versionString = (unarchiver.decodeObject(forKey: .schemaVersionKey) as? String)
                        ?? SchemaVersion.v1_0_0.versionString
    unarchiver.finishDecoding()
    guard let version = SchemaVersion(versionString: versionString) else {
      throw DataFormatError.unsupportedSchemaVersion(versionString: versionString)
    }
    return version
  }
}

// MARK: - Version 2-0-0

extension KeyedArchivalFormat {
  private func serializeVersion2_0_0(_ elements: [Movie]) throws -> Data {
    let payload: [[String: Any]] = elements.map { movie in
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
      return dictionary
    }
    let data = NSMutableData()
    let archiver = NSKeyedArchiver(forWritingWith: data)
    archiver.encode(SchemaVersion.v2_0_0.versionString, forKey: .schemaVersionKey)
    archiver.encode(payload, forKey: .payloadKey)
    archiver.finishEncoding()
    return data as Data
  }

  private func deserializeVersion2_0_0(from data: Data) throws -> [Movie] {
    let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
    guard let array = unarchiver.decodeObject(forKey: .payloadKey) as? [[String: Any]] else {
      throw DataFormatError.invalidDataFormat
    }
    unarchiver.finishDecoding()
    var movies = [Movie]()
    for dict in array {
      let id = (dict["id"] as? Int).map(TmdbIdentifier.init)
      let title = dict["title"] as? String
      let subtitle = dict["subtitle"] as? String
      let runtime = (dict["runtime"] as? Int).map { Measurement(value: Double($0), unit: UnitDuration.minutes) }
      let releaseDate = (dict["releaseDate"] as? String).flatMap { DataFormatFormatters.v2DateFormatter.date(from: $0) }
      let diskType = DiskType(rawValue: dict["diskType"] as? String ?? "")
      let genreIds = dict["genreIds"] as? [Int] ?? []
      if let id = id, let title = title, let diskType = diskType {
        let movie = Movie(tmdbID: id,
                          title: title,
                          subtitle: subtitle,
                          runtime: runtime,
                          releaseDate: releaseDate,
                          diskType: diskType,
                          genreIds: genreIds.map(GenreIdentifier.init))
        movies.append(movie)
      } else {
        throw DataFormatError.invalidDataFormat
      }
    }
    return movies
  }
}

// MARK: - Version 1-0-0

extension KeyedArchivalFormat {
  private func serializeVersion1_0_0(_ elements: [Movie]) throws -> Data {
    let rootObject: [[String: Any]] = elements.map { movie in
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
      return dictionary
    }
    return NSKeyedArchiver.archivedData(withRootObject: rootObject)
  }

  private func deserializeVersion1_0_0(from data: Data) throws -> [Movie] {
    guard let array = NSKeyedUnarchiver.unarchiveObject(with: data) as? [[String: Any]] else {
      throw DataFormatError.invalidDataFormat
    }
    var movies = [Movie]()
    for dict in array {
      let id = (dict["id"] as? Int).map(TmdbIdentifier.init)
      let title = dict["title"] as? String
      let subtitle = dict["subtitle"] as? String
      let runtime: Measurement<UnitDuration>?
      if let rawRuntime = dict["runtime"] as? Int, rawRuntime > 0 {
        runtime = Measurement(value: Double(rawRuntime), unit: UnitDuration.minutes)
      } else {
        runtime = nil
      }
      let year = dict["year"] as? Int
      let diskType = DiskType(rawValue: dict["diskType"] as? String ?? "")
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
