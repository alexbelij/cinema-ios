import CinemaKit
import UIKit

protocol PosterProvider {
  func poster(for id: TmdbIdentifier, size: PosterSize, purpose: PosterPurpose) -> UIImage?
}

class EmptyPosterProvider: PosterProvider {
  func poster(for id: TmdbIdentifier, size: PosterSize, purpose: PosterPurpose) -> UIImage? {
    return nil
  }
}

class MovieDbPosterProvider: PosterProvider {
  private let movieDb: MovieDbClient

  init(_ movieDb: MovieDbClient) {
    self.movieDb = movieDb
  }

  func poster(for id: TmdbIdentifier, size: PosterSize, purpose: PosterPurpose) -> UIImage? {
    return movieDb.poster(for: id, size: size, purpose: purpose)
  }
}
