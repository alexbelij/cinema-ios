import Foundation

public protocol MovieLibraryDelegate: class {
  func library(_ library: MovieLibrary, didUpdateContent contentUpdate: MovieLibraryContentUpdate)
  func libraryDidUpdateMetadata(_ library: MovieLibrary)
}

public struct MovieLibraryContentUpdate {
  public var addedMovies: [Movie]
  public var removedMovies: [Movie]
  public var updatedMovies: [TmdbIdentifier: Movie]

  init(addedMovies: [Movie] = [], removedMovies: [Movie] = [], updatedMovies: [TmdbIdentifier: Movie] = [:]) {
    self.addedMovies = addedMovies
    self.removedMovies = removedMovies
    self.updatedMovies = updatedMovies
  }
}

public enum MovieLibraryError: Error {
  case detailsFetchError
}

public protocol MovieLibrary: class {
  var metadata: MovieLibraryMetadata { get }
  var delegates: MulticastDelegate<MovieLibraryDelegate> { get }

  // accessing library content
  func fetchMovies(then completion: @escaping (Result<[Movie], MovieLibraryError>) -> Void)
  func fetchMovies(for id: GenreIdentifier,
                   then completion: @escaping (Result<[Movie], MovieLibraryError>) -> Void)

  // getting information about the library
  func containsMovie(with id: TmdbIdentifier) -> Bool // call only when movies have already been fetched

  // managing library content
  func addMovie(with tmdbID: TmdbIdentifier,
                diskType: DiskType,
                then completion: @escaping (Result<Movie, MovieLibraryError>) -> Void)
  func update(_ movie: Movie, then completion: @escaping (Result<Movie, MovieLibraryError>) -> Void)
  func removeMovie(with tmdbID: TmdbIdentifier,
                   then completion: @escaping (Result<Void, MovieLibraryError>) -> Void)
}

protocol InternalMovieLibrary: MovieLibrary {
  var metadata: MovieLibraryMetadata { get set }
}
