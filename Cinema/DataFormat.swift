import Foundation

protocol DataFormat {

  func serialize(_ elements: [MediaItem]) throws -> Data

  func deserialize(from data: Data) throws -> [MediaItem]

}
