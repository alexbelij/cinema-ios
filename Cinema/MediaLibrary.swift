protocol MediaLibrary {

  func mediaItems(where predicate: (MediaItem) -> Bool) -> [MediaItem]

  func add(_ mediaItem: MediaItem) -> Bool

  func replaceItems(_ mediaItems: [MediaItem]) -> Bool

}
