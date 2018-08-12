import Foundation

public protocol MovieLibrary {
  var delegates: MulticastDelegate<MovieLibraryDelegate> { get }

  // accessing library content
  func fetchAllMovies() -> [Movie]
  func fetchMovies(for id: GenreIdentifier) -> [Movie]

  // getting information about the library
  func containsMovie(with id: TmdbIdentifier) -> Bool

  // managing library content
  func add(_ movie: Movie) throws
  func update(_ movie: Movie) throws
  func remove(_ movie: Movie) throws
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
