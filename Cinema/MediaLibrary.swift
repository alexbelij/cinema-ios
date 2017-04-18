protocol MediaLibrary {

  func mediaItems(where predicate: (MediaItem) -> Bool) -> [MediaItem];

}
