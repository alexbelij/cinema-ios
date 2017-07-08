import Foundation

class FileBasedMediaLibrary: MediaLibrary {

  private let directory: URL

  private let fileName: String

  private let dataFormat: DataFormat

  private var mediaItems: [MediaItem]

  init(directory: URL, fileName: String, dataFormat: DataFormat) throws {
    self.directory = directory
    self.fileName = fileName
    self.dataFormat = dataFormat
    let url = directory.appendingPathComponent(fileName)
    if FileManager.default.fileExists(atPath: url.path) {
      guard let data = try? Data(contentsOf: URL(fileURLWithPath: url.path)) else {
        throw MediaLibraryError.storageError
      }
      do {
        mediaItems = try dataFormat.deserialize(from: data)
      } catch {
        throw MediaLibraryError.storageError
      }
    } else {
      mediaItems = []
    }
  }

  func mediaItems(where predicate: (MediaItem) -> Bool) -> [MediaItem] {
    return mediaItems.filter(predicate)
  }

  func add(_ mediaItem: MediaItem) throws {
    guard !mediaItems.contains(where: { $0.id == mediaItem.id }) else { return }
    mediaItems.append(mediaItem)
    try saveData()
  }

  func update(_ mediaItem: MediaItem) throws {
    guard let index = mediaItems.index(where: { $0.id == mediaItem.id }) else {
      throw MediaLibraryError.itemDoesNotExist(id: mediaItem.id)
    }
    mediaItems.remove(at: index)
    mediaItems.insert(mediaItem, at: index)
    try saveData()
  }

  func remove(_ mediaItem: MediaItem) throws {
    guard let index = mediaItems.index(where: { $0.id == mediaItem.id }) else {
      throw MediaLibraryError.itemDoesNotExist(id: mediaItem.id)
    }
    mediaItems.remove(at: index)
    try saveData()
  }

  func replaceItems(_ mediaItems: [MediaItem]) throws {
    self.mediaItems = mediaItems
    try saveData()
  }

  private func saveData() throws {
    NotificationCenter.default.post(name: .mediaLibraryChangedContent, object: self)
    guard let data = try? dataFormat.serialize(mediaItems) else {
      throw MediaLibraryError.storageError
    }
    let success = FileManager.default.createFile(atPath: directory.appendingPathComponent(fileName).path,
                                                 contents: data)
    if !success {
      throw MediaLibraryError.storageError
    }
  }

}

extension Notification.Name {
  static let mediaLibraryChangedContent = Notification.Name("mediaLibraryChangedContent")
}
