import Foundation

class FileBasedMediaLibrary: MediaLibrary {

  private let directory: URL

  private let fileName: String

  private var mediaItems: [MediaItem]

  init(directory: URL, fileName: String) {
    self.directory = directory
    self.fileName = fileName
    let url = directory.appendingPathComponent(fileName)
    mediaItems = FileBasedMediaLibrary.readData(from: url) ?? [MediaItem]()
  }

  private static func readData(from url: URL) -> [MediaItem]? {
    do {
      let data = try Data(contentsOf: URL(fileURLWithPath: url.path))
      let array = NSKeyedUnarchiver.unarchiveObject(with: data) as! [[String: Any]]
      return array.map { MediaItem(dataDictionary: $0) }
    } catch let error {
      print("error while reading from \(url): \(error)")
    }
    return nil
  }

  private static func writeData(_ data: [MediaItem], to url: URL) -> Bool {
    let data = NSKeyedArchiver.archivedData(withRootObject: data.map { $0.dataDictionary })
    return FileManager.default.createFile(atPath: url.path, contents: data)
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
