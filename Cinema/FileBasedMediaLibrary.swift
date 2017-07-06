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
    if FileManager.default.fileExists(atPath: url.path) {
      mediaItems = FileBasedMediaLibrary.readData(from: url, format: dataFormat) ?? [MediaItem]()
    } else {
      mediaItems = []
    }
  }

  private static func readData(from url: URL, format: DataFormat) -> [MediaItem]? {
    do {
      let data = try Data(contentsOf: URL(fileURLWithPath: url.path))
      return try format.deserialize(from: data)
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

  func add(_ mediaItem: MediaItem) -> Bool {
    guard !mediaItems.contains(where: { $0.id == mediaItem.id }) else { return true }
    mediaItems.append(mediaItem)
    NotificationCenter.default.post(name: .mediaLibraryChangedContent, object: self)
    return FileBasedMediaLibrary.writeData(mediaItems,
                                           to: directory.appendingPathComponent(fileName),
                                           format: dataFormat)
  }

  func replaceItems(_ mediaItems: [MediaItem]) -> Bool {
    self.mediaItems = mediaItems
    NotificationCenter.default.post(name: .mediaLibraryChangedContent, object: self)
    return FileBasedMediaLibrary.writeData(mediaItems,
                                           to: directory.appendingPathComponent(fileName),
                                           format: dataFormat)
  }

}

extension Notification.Name {
  static let mediaLibraryChangedContent = Notification.Name("mediaLibraryChangedContent")
}
