import CinemaKit

final class ExternalMovieViewModel: PosterHaving {
  enum LibraryState {
    case new
    case updateInProgress
    case addedToLibrary
  }

  let movie: PartialMediaItem
  var poster: ImageState
  var state: LibraryState

  init(_ movie: PartialMediaItem, state: LibraryState) {
    self.movie = movie
    self.state = state
    self.poster = .unknown
  }

  var tmdbID: TmdbIdentifier {
    return movie.tmdbID
  }
}
