import Foundation

protocol MediaLibrary {

  var delegates: MulticastDelegate<MediaLibraryDelegate> { get }

  var persistentSchemaVersion: SchemaVersion { get }

  func mediaItems(where predicate: (MediaItem) -> Bool) -> [MediaItem]

  func containsMediaItem(withId id: Int) -> Bool

  func add(_ mediaItem: MediaItem) throws

  func update(_ mediaItem: MediaItem) throws

  func remove(_ mediaItem: MediaItem) throws

  func performBatchUpdates(_ updates: () throws -> Void) throws

}

enum MediaLibraryError: Error {
  case storageError
  case itemDoesNotExist(id: Int)
}

protocol MediaLibraryDelegate: class {
  func library(_ library: MediaLibrary, didUpdateContent contentUpdate: MediaLibraryContentUpdate)
}

struct MediaLibraryContentUpdate {
  var addedItems: [MediaItem]
  var removedItems: [MediaItem]
  var updatedItems: [Int: MediaItem]

  init(addedItems: [MediaItem] = [], removedItems: [MediaItem] = [], updatedItems: [Int: MediaItem] = [:]) {
    self.addedItems = addedItems
    self.removedItems = removedItems
    self.updatedItems = updatedItems
  }
}
