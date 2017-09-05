import Foundation

class FileBasedMediaLibrary: MediaLibrary {

  private let url: URL

  private let dataFormat: DataFormat

  private var mediaItems: [MediaItem]

  private var isPerformingBatchUpdates = false

  init(url: URL, dataFormat: DataFormat) throws {
    self.url = url
    self.dataFormat = dataFormat
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

  var persistentSchemaVersion: SchemaVersion {
    guard FileManager.default.fileExists(atPath: url.path) else {
      return dataFormat.defaultSchemaVersion!
    }
    do {
      return try dataFormat.schemaVersion(of: try Data(contentsOf: url))
    } catch let error {
      fatalError("Could not detect version of data at \(url): \(error)")
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

  func performBatchUpdates(_ updates: () throws -> Void) throws {
    isPerformingBatchUpdates = true
    try updates()
    isPerformingBatchUpdates = false
    try saveData()
  }

  private func saveData() throws {
    guard !isPerformingBatchUpdates else { return }
    NotificationCenter.default.post(name: .didChangeMediaLibraryContent, object: self)
    guard let data = try? dataFormat.serialize(mediaItems) else {
      throw MediaLibraryError.storageError
    }
    let success = FileManager.default.createFile(atPath: url.path, contents: data)
    if !success {
      throw MediaLibraryError.storageError
    }
  }

}
