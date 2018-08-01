import Foundation
import os.log

public class FileBasedMediaLibrary: MediaLibrary {

  private static let logger = Logging.createLogger(category: "Storage")

  public let delegates: MulticastDelegate<MediaLibraryDelegate> = MulticastDelegate()

  private let url: URL

  private let dataFormat: DataFormat

  private var mediaItems: [TmdbIdentifier: MediaItem]

  private var isPerformingBatchUpdates = false

  private var pendingContentUpdate = MediaLibraryContentUpdate()

  public init?(url: URL, dataFormat: DataFormat) {
    self.url = url
    self.dataFormat = dataFormat
    if FileManager.default.fileExists(atPath: url.path) {
      os_log("library data file exists", log: FileBasedMediaLibrary.logger, type: .default)
      do {
        let data = try Data(contentsOf: URL(fileURLWithPath: url.path))
        mediaItems = Dictionary(uniqueKeysWithValues: try dataFormat.deserialize(from: data).map { ($0.tmdbID, $0) })
      } catch {
        os_log("failed to load library data: %{public}@",
               log: FileBasedMediaLibrary.logger,
               type: .error,
               String(describing: error))
        return nil
      }
    } else {
      os_log("no data file for library", log: FileBasedMediaLibrary.logger, type: .default)
      mediaItems = [:]
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
    return Array(mediaItems.values)
  }

  public func fetchMediaItems(for id: GenreIdentifier) -> [MediaItem] {
    return fetchAllMediaItems().filter { $0.genreIds.contains(id) }
  }

  public func containsMediaItem(with id: TmdbIdentifier) -> Bool {
    return mediaItems.keys.contains(id)
  }

  public func add(_ mediaItem: MediaItem) throws {
    guard !mediaItems.keys.contains(mediaItem.tmdbID) else { return }
    mediaItems[mediaItem.tmdbID] = mediaItem
    pendingContentUpdate.addedItems.append(mediaItem)
    try saveData()
  }

  public func update(_ mediaItem: MediaItem) throws {
    guard mediaItems[mediaItem.tmdbID] != nil else {
      throw MediaLibraryError.itemDoesNotExist(id: mediaItem.tmdbID)
    }
    mediaItems[mediaItem.tmdbID] = mediaItem
    pendingContentUpdate.updatedItems[mediaItem.tmdbID] = mediaItem
    try saveData()
  }

  public func remove(_ mediaItem: MediaItem) throws {
    guard mediaItems[mediaItem.tmdbID] != nil else {
      throw MediaLibraryError.itemDoesNotExist(id: mediaItem.tmdbID)
    }
    mediaItems.removeValue(forKey: mediaItem.tmdbID)
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
    guard let data = try? dataFormat.serialize(Array(mediaItems.values)) else {
      throw MediaLibraryError.storageError
    }
    guard FileManager.default.createFile(atPath: url.path, contents: data) else {
      throw MediaLibraryError.storageError
    }
    delegates.invoke { $0.library(self, didUpdateContent: self.pendingContentUpdate) }
    pendingContentUpdate = MediaLibraryContentUpdate()
  }

}
