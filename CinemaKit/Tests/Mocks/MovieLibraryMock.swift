@testable import CinemaKit

class MovieLibraryMock: InternalMovieLibrary {
  var metadata: MovieLibraryMetadata
  let delegates: MulticastDelegate<MovieLibraryDelegate> = MulticastDelegate()

  init(metadata: MovieLibraryMetadata = MovieLibraryMetadata(name: "Library")) {
    self.metadata = metadata
  }

  func fetchMovies(then completion: @escaping (Result<[Movie], MovieLibraryError>) -> Void) {
    fatalError("not implemented")
  }

  func fetchMovies(for id: GenreIdentifier, then completion: @escaping (Result<[Movie], MovieLibraryError>) -> Void) {
    fatalError("not implemented")
  }

  func addMovie(with tmdbID: TmdbIdentifier,
                diskType: DiskType,
                then completion: @escaping (Result<Movie, MovieLibraryError>) -> Void) {
    fatalError("not implemented")
  }

  func update(_ movie: Movie, then completion: @escaping (Result<Movie, MovieLibraryError>) -> Void) {
    fatalError("not implemented")
  }

  func removeMovie(with tmdbID: TmdbIdentifier, then completion: @escaping (Result<Void, MovieLibraryError>) -> Void) {
    fatalError("not implemented")
  }

  var didCallProcessChanges = false

  func processChanges(_ changes: FetchedChanges) {
    didCallProcessChanges = true
  }

  var didCallCleanupForRemoval = false

  func cleanupForRemoval() {
    didCallCleanupForRemoval = true
  }

  func migrateMovies(from url: URL, then completion: @escaping (Bool) -> Void) {
    fatalError("not implemented")
  }
}
