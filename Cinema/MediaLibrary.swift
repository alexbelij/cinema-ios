protocol MediaLibrary {

  func mediaItems(where predicate: (MediaItem) -> Bool) -> [MediaItem];

  func add(_ mediaItem: MediaItem) -> Bool;

}
