import Foundation

public class FileBasedMediaLibrary: MediaLibrary {

  public let delegates: MulticastDelegate<MediaLibraryDelegate> = MulticastDelegate()

  private let url: URL

  private let dataFormat: DataFormat

  private var mediaItems: [MediaItem]

  private var isPerformingBatchUpdates = false

  private var pendingContentUpdate = MediaLibraryContentUpdate()

  public init(url: URL, dataFormat: DataFormat) throws {
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

  public var persistentSchemaVersion: SchemaVersion {
    guard FileManager.default.fileExists(atPath: url.path) else {
      return dataFormat.defaultSchemaVersion!
    }
    do {
      return try dataFormat.schemaVersion(of: try Data(contentsOf: url))
    } catch {
      fatalError("Could not detect version of data at \(url): \(error)")
    }
  }

  public func fetchAllMediaItems() -> [MediaItem] {
    return mediaItems
  }

  public func fetchMediaItems(for id: GenreIdentifier) -> [MediaItem] {
    return mediaItems.filter { $0.genreIds.contains(id) }
  }

  public func containsMediaItem(with id: TmdbIdentifier) -> Bool {
    return mediaItems.contains { item in item.tmdbID == id }
  }

  public func add(_ mediaItem: MediaItem) throws {
    guard !mediaItems.contains(where: { $0.tmdbID == mediaItem.tmdbID }) else { return }
    mediaItems.append(mediaItem)
    pendingContentUpdate.addedItems.append(mediaItem)
    try saveData()
  }

  public func update(_ mediaItem: MediaItem) throws {
    guard let index = mediaItems.index(where: { $0.tmdbID == mediaItem.tmdbID }) else {
      throw MediaLibraryError.itemDoesNotExist(id: mediaItem.tmdbID)
    }
    mediaItems.remove(at: index)
    mediaItems.insert(mediaItem, at: index)
    pendingContentUpdate.updatedItems[mediaItem.tmdbID] = mediaItem
    try saveData()
  }

  public func remove(_ mediaItem: MediaItem) throws {
    guard let index = mediaItems.index(where: { $0.tmdbID == mediaItem.tmdbID }) else {
      throw MediaLibraryError.itemDoesNotExist(id: mediaItem.tmdbID)
    }
    mediaItems.remove(at: index)
    pendingContentUpdate.removedItems.append(mediaItem)
    try saveData()
  }

  public func performBatchUpdates(_ updates: () throws -> Void) throws {
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