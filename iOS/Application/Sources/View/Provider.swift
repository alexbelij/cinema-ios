import CinemaKit
import UIKit

protocol PosterProvider {
  func poster(for id: TmdbIdentifier, size: PosterSize) -> UIImage?
}

class EmptyPosterProvider: PosterProvider {
  func poster(for id: TmdbIdentifier, size: PosterSize) -> UIImage? {
    return nil
  }
}

class MovieDbPosterProvider: PosterProvider {
  private let movieDb: MovieDbClient

  init(_ movieDb: MovieDbClient) {
    self.movieDb = movieDb
  }

  func poster(for id: TmdbIdentifier, size: PosterSize) -> UIImage? {
    return movieDb.poster(for: id, size: size)
  }
}
