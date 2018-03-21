import Foundation

class FileBasedMediaLibrary: MediaLibrary {

  let delegates: MulticastDelegate<MediaLibraryDelegate> = MulticastDelegate()

  private let url: URL

  private let dataFormat: DataFormat

  private var mediaItems: [MediaItem]

  private var isPerformingBatchUpdates = false

  private var pendingContentUpdate = MediaLibraryContentUpdate()

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

  func fetchAllMediaItems() -> [MediaItem] {
    return mediaItems
  }

  func fetchMediaItems(for id: GenreIdentifier) -> [MediaItem] {
    return mediaItems.filter { $0.genreIds.contains(id) }
  }

  func containsMediaItem(with id: TmdbIdentifier) -> Bool {
    return mediaItems.contains { item in item.tmdbID == id }
  }

  func add(_ mediaItem: MediaItem) throws {
    guard !mediaItems.contains(where: { $0.tmdbID == mediaItem.tmdbID }) else { return }
    mediaItems.append(mediaItem)
    pendingContentUpdate.addedItems.append(mediaItem)
    try saveData()
  }

  func update(_ mediaItem: MediaItem) throws {
    guard let index = mediaItems.index(where: { $0.tmdbID == mediaItem.tmdbID }) else {
      throw MediaLibraryError.itemDoesNotExist(id: mediaItem.tmdbID)
    }
    mediaItems.remove(at: index)
    mediaItems.insert(mediaItem, at: index)
    pendingContentUpdate.updatedItems[mediaItem.tmdbID] = mediaItem
    try saveData()
  }

  func remove(_ mediaItem: MediaItem) throws {
    guard let index = mediaItems.index(where: { $0.tmdbID == mediaItem.tmdbID }) else {
      throw MediaLibraryError.itemDoesNotExist(id: mediaItem.tmdbID)
    }
    mediaItems.remove(at: index)
    pendingContentUpdate.removedItems.append(mediaItem)
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
    guard let data = try? dataFormat.serialize(mediaItems) else {
      throw MediaLibraryError.storageError
    }
    guard FileManager.default.createFile(atPath: url.path, contents: data) else {
      throw MediaLibraryError.storageError
    }
    delegates.invoke { $0.library(self, didUpdateContent: self.pendingContentUpdate) }
    pendingContentUpdate = MediaLibraryContentUpdate()
  }

}
