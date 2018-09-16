import CloudKit
import Foundation

public struct TmdbIdentifier: RawRepresentable, CustomStringConvertible, Hashable, Codable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  public var description: String {
    return String(rawValue)
  }
}

public struct GenreIdentifier: RawRepresentable, CustomStringConvertible, Hashable, Codable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  public var description: String {
    return String(rawValue)
  }
}

public enum DiskType: String {
  case dvd, bluRay
}

public struct Movie {
  struct CloudProperties: DeviceSyncable {
    let id: CKRecord.ID
    let tmdbID: TmdbIdentifier
    let libraryID: CKRecord.ID
    var title: String
    var subtitle: String?
    let diskType: DiskType

    init(tmdbID: TmdbIdentifier,
         libraryID: CKRecord.ID,
         title: String,
         subtitle: String? = nil,
         diskType: DiskType) {
      self.id = CKRecord.ID(recordName: UUID().uuidString, zoneID: libraryID.zoneID)
      self.tmdbID = tmdbID
      self.libraryID = libraryID
      self.title = title
      self.subtitle = subtitle
      self.diskType = diskType
    }

    init(from record: MovieRecord) {
      self.id = record.id
      self.tmdbID = TmdbIdentifier(rawValue: record.tmdbID)
      self.libraryID = record.library.recordID
      self.title = record.title
      self.subtitle = record.subtitle
      self.diskType = DiskType(rawValue: record.diskType)!
    }

    func setCustomFields(in record: MovieRecord) {
      precondition(record.id == id)
      record.tmdbID = tmdbID.rawValue
      record.library = CKRecord.Reference(recordID: libraryID, action: .deleteSelf)
      record.title = title
      record.subtitle = subtitle
      record.diskType = diskType.rawValue
    }
  }

  struct TmdbProperties: Codable {
    let runtime: Measurement<UnitDuration>?
    let releaseDate: Date?
    let genreIds: [GenreIdentifier]
    let certification: String?
    let overview: String?

    init(runtime: Measurement<UnitDuration>? = nil,
         releaseDate: Date? = nil,
         genreIds: [GenreIdentifier] = [],
         certification: String? = nil,
         overview: String? = nil) {
      self.runtime = runtime
      self.releaseDate = releaseDate
      self.genreIds = genreIds
      self.certification = certification
      self.overview = overview
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      runtime = try container.decodeIfPresent(Double.self, forKey: .runtime)
                             .map { Measurement(value: $0, unit: .minutes) }
      releaseDate = try container.decodeIfPresent(Date.self, forKey: .releaseDate)
      genreIds = try container.decode([GenreIdentifier].self, forKey: .genreIds)
      certification = try container.decodeIfPresent(String.self, forKey: .certification)
      overview = try container.decodeIfPresent(String.self, forKey: .overview)
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      if let runtime = runtime {
        try container.encode(runtime.converted(to: .minutes).value, forKey: .runtime)
      }
      if let releaseDate = releaseDate {
        try container.encode(releaseDate, forKey: .releaseDate)
      }
      try container.encode(genreIds, forKey: .genreIds)
      if let certification = certification {
        try container.encode(certification, forKey: .certification)
      }
      if let overview = overview {
        try container.encode(overview, forKey: .overview)
      }
    }

    private enum CodingKeys: String, CodingKey {
      case runtime
      case releaseDate
      case genreIds
      case certification
      case overview
    }
  }

  var cloudProperties: CloudProperties
  let tmdbProperties: TmdbProperties

  var id: CKRecord.ID {
    return cloudProperties.id
  }
  public var tmdbID: TmdbIdentifier {
    return cloudProperties.tmdbID
  }
  public var title: String {
    get {
      return cloudProperties.title
    }
    set {
      cloudProperties.title = newValue
    }
  }
  public var subtitle: String? {
    get {
      return cloudProperties.subtitle
    }
    set {
      cloudProperties.subtitle = newValue
    }
  }
  public var diskType: DiskType {
    return cloudProperties.diskType
  }
  public var runtime: Measurement<UnitDuration>? {
    return tmdbProperties.runtime
  }
  public var releaseDate: Date? {
    return tmdbProperties.releaseDate
  }
  public var genreIds: [GenreIdentifier] {
    return tmdbProperties.genreIds
  }
  public var certification: String? {
    return tmdbProperties.certification
  }
  public var overview: String? {
    return tmdbProperties.overview
  }

  init(_ cloudProperties: CloudProperties, _ tmdbProperties: TmdbProperties) {
    self.cloudProperties = cloudProperties
    self.tmdbProperties = tmdbProperties
  }

  public var fullTitle: String {
    if let subtitle = subtitle {
      return "\(title): \(subtitle)"
    } else {
      return title
    }
  }
}

extension Collection where Element == Movie {
  public func index(of movie: Movie) -> Index? {
    return index { $0.tmdbID == movie.tmdbID }
  }
}
