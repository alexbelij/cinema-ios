import Foundation

public protocol MediaLibrary {

  var delegates: MulticastDelegate<MediaLibraryDelegate> { get }

  var persistentSchemaVersion: SchemaVersion { get }

  func fetchAllMediaItems() -> [MediaItem]

  func fetchMediaItems(for id: GenreIdentifier) -> [MediaItem]

  func containsMediaItem(with id: TmdbIdentifier) -> Bool

  func add(_ mediaItem: MediaItem) throws

  func update(_ mediaItem: MediaItem) throws

  func remove(_ mediaItem: MediaItem) throws

  func performBatchUpdates(_ updates: () throws -> Void) throws

}

public enum MediaLibraryError: Error {
  case storageError
  case itemDoesNotExist(id: TmdbIdentifier)
}

public protocol MediaLibraryDelegate: class {
  func library(_ library: MediaLibrary, didUpdateContent contentUpdate: MediaLibraryContentUpdate)
}

public struct MediaLibraryContentUpdate {
  public var addedItems: [MediaItem]
  public var removedItems: [MediaItem]
  public var updatedItems: [TmdbIdentifier: MediaItem]

  init(addedItems: [MediaItem] = [], removedItems: [MediaItem] = [], updatedItems: [TmdbIdentifier: MediaItem] = [:]) {
    self.addedItems = addedItems
    self.removedItems = removedItems
    self.updatedItems = updatedItems
  }
}
