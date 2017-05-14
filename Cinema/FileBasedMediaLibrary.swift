import Foundation

class FileBasedMediaLibrary: MediaLibrary {

  private let directory: URL

  private let fileName: String

  private let dataFormat: DataFormat

  private var mediaItems: [MediaItem]

  init(directory: URL, fileName: String, dataFormat: DataFormat) {
    self.directory = directory
    self.fileName = fileName
    self.dataFormat = dataFormat
    let url = directory.appendingPathComponent(fileName)
    mediaItems = FileBasedMediaLibrary.readData(from: url, format: dataFormat) ?? [MediaItem]()
  }

  private static func readData(from url: URL, format: DataFormat) -> [MediaItem]? {
    do {
      let data = try Data(contentsOf: URL(fileURLWithPath: url.path))
      return try format.deserialize(from: data, as: MediaItem.self)
    } catch let error {
      print("error while reading from \(url): \(error)")
    }
    return nil
  }

  private static func writeData(_ data: [MediaItem], to url: URL, format: DataFormat) -> Bool {
    do {
      let data = try format.serialize(data)
      return FileManager.default.createFile(atPath: url.path, contents: data)
    } catch {
      print("error while writing to \(url): \(error)")
    }
    return false
  }

  func mediaItems(where predicate: (MediaItem) -> Bool) -> [MediaItem] {
    return mediaItems.filter(predicate)
  }

}

extension MediaItem: ArchivableStruct {

  var dataDictionary: [String: Any] {
    var dictionary: [String: Any] = [
        "id": self.id,
        "title": self.title,
        "runtime": self.runtime,
        "year": self.year,
        "diskType": self.diskType.rawValue,
    ]
    if let subtitle = self.subtitle {
      dictionary["subtitle"] = subtitle
    }
    return dictionary
  }

  init(dataDictionary dict: [String: Any]) {
    self.id = dict["id"] as! Int
    self.title = dict["title"] as! String
    self.subtitle = dict["subtitle"] as? String
    self.runtime = dict["runtime"] as! Int
    self.year = dict["year"] as! Int
    self.diskType = DiskType(rawValue: dict["diskType"] as! String)!
  }

}
