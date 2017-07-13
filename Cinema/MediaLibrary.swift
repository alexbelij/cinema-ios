import Foundation

protocol MediaLibrary {

  func mediaItems(where predicate: (MediaItem) -> Bool) -> [MediaItem]

  func add(_ mediaItem: MediaItem) throws

  func update(_ mediaItem: MediaItem) throws

  func remove(_ mediaItem: MediaItem) throws

  func replaceItems(_ mediaItems: [MediaItem]) throws

}

enum MediaLibraryError: Error {
  case storageError
  case itemDoesNotExist(id: Int)
}

extension Notification.Name {
  static let didChangeMediaLibraryContent = Notification.Name("didChangeMediaLibraryContent")
}
