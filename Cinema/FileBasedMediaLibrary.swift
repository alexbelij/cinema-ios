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
      do {
        let data = try Data(contentsOf: URL(fileURLWithPath: url.path))
        mediaItems = try dataFormat.deserialize(from: data)
      } catch {
        mediaItems = []
      }
    } else {
      mediaItems = []
    }
  }

  func mediaItems(where predicate: (MediaItem) -> Bool) -> [MediaItem] {
    return mediaItems.filter(predicate)
  }

  func add(_ mediaItem: MediaItem) -> Bool {
    guard !mediaItems.contains(where: { $0.id == mediaItem.id }) else { return true }
    mediaItems.append(mediaItem)
    return saveData()
  }

  func replaceItems(_ mediaItems: [MediaItem]) -> Bool {
    self.mediaItems = mediaItems
    NotificationCenter.default.post(name: .mediaLibraryChangedContent, object: self)
    return saveData()
  }

  private func saveData() -> Bool {
    NotificationCenter.default.post(name: .mediaLibraryChangedContent, object: self)
    do {
      let data = try dataFormat.serialize(mediaItems)
      return FileManager.default.createFile(atPath: directory.appendingPathComponent(fileName).path, contents: data)
    } catch {
      return false
    }
  }

}

extension Notification.Name {
  static let mediaLibraryChangedContent = Notification.Name("mediaLibraryChangedContent")
}
