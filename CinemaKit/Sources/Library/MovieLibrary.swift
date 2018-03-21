import Foundation

public protocol MovieLibrary {

  var delegates: MulticastDelegate<MovieLibraryDelegate> { get }

  var persistentSchemaVersion: SchemaVersion { get }

  func fetchAllMovies() -> [Movie]

  func fetchMovies(for id: GenreIdentifier) -> [Movie]

  func containsMovie(with id: TmdbIdentifier) -> Bool

  func add(_ movie: Movie) throws

  func update(_ movie: Movie) throws

  func remove(_ movie: Movie) throws

  func performBatchUpdates(_ updates: () throws -> Void) throws

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
