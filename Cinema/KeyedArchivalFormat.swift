import Foundation

class KeyedArchivalFormat: DataFormat {

  func serialize(_ elements: [ArchivableStruct]) -> Data {
    return NSKeyedArchiver.archivedData(withRootObject: elements.map { $0.dataDictionary })
  }

  func deserialize<T: ArchivableStruct>(from data: Data, as: T.Type) -> [T] {
    let array = NSKeyedUnarchiver.unarchiveObject(with: data) as! [[String: Any]]
    return array.map { T.init(dataDictionary: $0) }
  }

}
