import Foundation

public protocol MovieLibrary {
  var delegates: MulticastDelegate<MovieLibraryDelegate> { get }

  // accessing library content
  func fetchMovies(then completion: @escaping (AsyncResult<[Movie], MovieLibraryError>) -> Void)
  func fetchMovies(for id: GenreIdentifier,
                   then completion: @escaping (AsyncResult<[Movie], MovieLibraryError>) -> Void)

  // getting information about the library
  func containsMovie(with id: TmdbIdentifier) -> Bool

  // managing library content
  func add(_ movie: Movie, then completion: @escaping (AsyncResult<Void, MovieLibraryError>) -> Void)
  func update(_ movie: Movie, then completion: @escaping (AsyncResult<Void, MovieLibraryError>) -> Void)
  func remove(_ movie: Movie, then completion: @escaping (AsyncResult<Void, MovieLibraryError>) -> Void)
}

public enum MovieLibraryError: Error {
  case storageError
  case movieDoesNotExist(id: TmdbIdentifier)
}

public protocol MovieLibraryDelegate: class {
  func library(_ library: MovieLibrary, didUpdateContent contentUpdate: MovieLibraryContentUpdate)
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
