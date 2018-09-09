import CinemaKit

final class ExternalMovieViewModel: PosterHaving {
  enum LibraryState {
    case new
    case updateInProgress
    case addedToLibrary
  }

  let movie: PartialMovie
  var poster: ImageState
  var state: LibraryState

  init(_ movie: PartialMovie, state: LibraryState) {
    self.movie = movie
    self.state = state
    self.poster = .unknown
  }

  var tmdbID: TmdbIdentifier {
    return movie.tmdbID
  }
}
