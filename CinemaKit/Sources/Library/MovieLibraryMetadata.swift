import Foundation

public struct MovieLibraryMetadata: Codable {
  public let id: UUID
  public var name: String

  public init(name: String) {
    self.id = UUID()
    self.name = name
  }
}
