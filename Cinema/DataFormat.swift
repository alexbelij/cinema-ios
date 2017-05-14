import Foundation

protocol DataFormat {

  func serialize(_ elements: [ArchivableStruct]) throws -> Data

  func deserialize<T: ArchivableStruct>(from data: Data, as: T.Type) throws -> [T]

}
