import Foundation

protocol MediaLibrary {

  var persistentSchemaVersion: SchemaVersion { get }

  func mediaItems(where predicate: (MediaItem) -> Bool) -> [MediaItem]

  func add(_ mediaItem: MediaItem) throws

  func update(_ mediaItem: MediaItem) throws

  func remove(_ mediaItem: MediaItem) throws

  func performBatchUpdates(_ updates: () throws -> Void) throws

}

enum MediaLibraryError: Error {
  case storageError
  case itemDoesNotExist(id: Int)
}

extension Notification.Name {
  static let didChangeMediaLibraryContent = Notification.Name("didChangeMediaLibraryContent")
}
