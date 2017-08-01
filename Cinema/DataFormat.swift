import Foundation

protocol DataFormat {

  var defaultSchemaVersion: SchemaVersion? { get set }

  func serialize(_ elements: [MediaItem]) throws -> Data

  func serialize(_ elements: [MediaItem], schemaVersion: SchemaVersion) throws -> Data

  func deserialize(from data: Data) throws -> [MediaItem]

}

extension DataFormat {
  func serialize(_ elements: [MediaItem]) throws -> Data {
    guard let version = defaultSchemaVersion else {
      fatalError("no default schema version has been set")
    }
    return try serialize(elements, schemaVersion: version)
  }
}

enum DataFormatError: Error {
  case invalidDataFormat
  case unsupportedSchemaVersion(versionString: String)
}

enum SchemaVersion: Equatable, Comparable, CustomStringConvertible {

  // swiftlint:disable identifier_name
  case v1_0_0
  case v2_0_0
  // swiftlint:enable identifier_name

  var model: UInt {
    switch self {
      case .v1_0_0: return 1
      case .v2_0_0: return 2
    }
  }
  var revision: UInt {
    switch self {
      case .v1_0_0, .v2_0_0: return 0
    }
  }
  var addition: UInt {
    switch self {
      case .v1_0_0, .v2_0_0: return 0
    }
  }

  init?(versionString: String) {
    switch versionString {
      case "1-0-0": self = .v1_0_0
      case "2-0-0": self = .v2_0_0
      default: return nil
    }
  }

  var versionString: String {
    return "\(model)-\(revision)-\(addition)"
  }

  var description: String {
    return versionString
  }

  static func == (lhs: SchemaVersion, rhs: SchemaVersion) -> Bool {
    return lhs.model == rhs.model && lhs.revision == rhs.revision && lhs.addition == rhs.addition
  }

  static func < (lhs: SchemaVersion, rhs: SchemaVersion) -> Bool {
    if lhs.model != rhs.model {
      return lhs.model < rhs.model
    }
    if lhs.revision != rhs.revision {
      return lhs.revision < rhs.revision
    }
    return lhs.addition < rhs.addition
  }
}
