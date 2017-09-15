class GenreIdsUpdate: PropertyUpdate {

  private var movieDb: MovieDbClient

  init(movieDb: MovieDbClient) {
    self.movieDb = movieDb
  }

  func apply(on item: inout MediaItem) {
    item.genreIds = movieDb.genreIds(for: item.id)
  }

}

class ReleaseDateUpdate: PropertyUpdate {

  private var movieDb: MovieDbClient

  init(movieDb: MovieDbClient) {
    self.movieDb = movieDb
  }

  func apply(on item: inout MediaItem) {
    item.releaseDate = movieDb.releaseDate(for: item.id)
  }

}
