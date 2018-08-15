class InMemoryMovieLibrary: InternalMovieLibrary {
  var metadata: MovieLibraryMetadata {
    didSet {
      delegates.invoke { $0.libraryDidUpdateMetadata(self) }
    }
  }
  let delegates: MulticastDelegate<MovieLibraryDelegate> = MulticastDelegate()
  private var movies = [Movie]()

  init(metadata: MovieLibraryMetadata) {
    self.metadata = metadata
  }

  func fetchMovies(then completion: @escaping (AsyncResult<[Movie], MovieLibraryError>) -> Void) {
    completion(.success(movies))
  }

  func fetchMovies(for id: GenreIdentifier,
                   then completion: @escaping (AsyncResult<[Movie], MovieLibraryError>) -> Void) {
    completion(.success(movies.filter { $0.genreIds.contains(id) }))
  }

  func containsMovie(with id: TmdbIdentifier) -> Bool {
    return movies.contains { $0.tmdbID == id }
  }

  func add(_ movie: Movie, then completion: @escaping (AsyncResult<Void, MovieLibraryError>) -> Void) {
    movies.append(movie)
    let update = MovieLibraryContentUpdate(addedMovies: [movie])
    delegates.invoke { $0.library(self, didUpdateContent: update) }
    completion(.success(()))
  }

  func update(_ movie: Movie, then completion: @escaping (AsyncResult<Void, MovieLibraryError>) -> Void) {
    guard let index = movies.index(of: movie) else { preconditionFailure() }
    movies[index] = movie
    let update = MovieLibraryContentUpdate(updatedMovies: [movie.tmdbID: movie])
    delegates.invoke { $0.library(self, didUpdateContent: update) }
    completion(.success(()))
  }

  func removeMovie(with tmdbID: TmdbIdentifier,
                   then completion: @escaping (AsyncResult<Void, MovieLibraryError>) -> Void) {
    guard let index = movies.index(where: { $0.tmdbID == tmdbID }) else { preconditionFailure() }
    let movie = movies.remove(at: index)
    let update = MovieLibraryContentUpdate(removedMovies: [movie])
    delegates.invoke { $0.library(self, didUpdateContent: update) }
    completion(.success(()))
  }
}
