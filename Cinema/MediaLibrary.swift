protocol MediaLibrary {

  func mediaItems(where predicate: (MediaItem) -> Bool) -> [MediaItem]

  func add(_ mediaItem: MediaItem) throws

  func update(_ mediaItem: MediaItem) throws

  func replaceItems(_ mediaItems: [MediaItem]) throws

}

enum MediaLibraryError: Error {
  case storageError
  case itemDoesNotExist(id: Int)
}
