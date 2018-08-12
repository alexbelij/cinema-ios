import Foundation

public protocol DataFormat {
  var defaultSchemaVersion: SchemaVersion? { get set }

  func serialize(_ elements: [Movie]) throws -> Data
  func serialize(_ elements: [Movie], schemaVersion: SchemaVersion) throws -> Data
  func deserialize(from data: Data) throws -> [Movie]
  func schemaVersion(of data: Data) throws -> SchemaVersion
}

public extension DataFormat {
  func serialize(_ elements: [Movie]) throws -> Data {
    guard let version = defaultSchemaVersion else {
      fatalError("no default schema version has been set")
    }
    return try serialize(elements, schemaVersion: version)
  }
}

enum DataFormatFormatters {
  static let v1DateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy"
    return formatter
  }()

  static let v2DateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()
}

public enum DataFormatError: Error {
  case invalidDataFormat
  case unsupportedSchemaVersion(versionString: String)
}

public enum SchemaVersion: Equatable, Comparable, CustomStringConvertible {
  // swiftlint:disable identifier_name
  // array of Movies
  case v1_0_0
  /*
   * schemaVersion -> <version>
   * payload -> array of Movies
   */
  case v2_0_0
  // swiftlint:enable identifier_name

  public var model: UInt {
    switch self {
      case .v1_0_0: return 1
      case .v2_0_0: return 2
    }
  }
  public var revision: UInt {
    switch self {
      case .v1_0_0, .v2_0_0: return 0
    }
  }
  public var addition: UInt {
    switch self {
      case .v1_0_0, .v2_0_0: return 0
    }
  }

  public init?(versionString: String) {
    switch versionString {
      case "1-0-0": self = .v1_0_0
      case "2-0-0": self = .v2_0_0
      default: return nil
    }
  }

  public var versionString: String {
    return "\(model)-\(revision)-\(addition)"
  }

  public var description: String {
    return versionString
  }

  public static func <(lhs: SchemaVersion, rhs: SchemaVersion) -> Bool {
    if lhs.model != rhs.model {
      return lhs.model < rhs.model
    }
    if lhs.revision != rhs.revision {
      return lhs.revision < rhs.revision
    }
    return lhs.addition < rhs.addition
  }
}

extension String {
  static let schemaVersionKey = "schemaVersion"
  static let payloadKey = "payload"
}
