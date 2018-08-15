import Foundation

public struct MovieLibraryMetadata: Codable {
  public let id: UUID
  public var name: String

  public init(name: String) {
    self.id = UUID()
    self.name = name
  }
}

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
  case dataAccessError
  case storageError
  case movieDoesNotExist(id: TmdbIdentifier)
}

public protocol MovieLibrary: class {
  var metadata: MovieLibraryMetadata { get }
  var delegates: MulticastDelegate<MovieLibraryDelegate> { get }

  // accessing library content
  func fetchMovies(then completion: @escaping (AsyncResult<[Movie], MovieLibraryError>) -> Void)
  func fetchMovies(for id: GenreIdentifier,
                   then completion: @escaping (AsyncResult<[Movie], MovieLibraryError>) -> Void)

  // getting information about the library
  func containsMovie(with id: TmdbIdentifier) -> Bool // call only when movies have already been fetched

  // managing library content
  func add(_ movie: Movie, then completion: @escaping (AsyncResult<Void, MovieLibraryError>) -> Void)
  func update(_ movie: Movie, then completion: @escaping (AsyncResult<Void, MovieLibraryError>) -> Void)
  func remove(_ movie: Movie, then completion: @escaping (AsyncResult<Void, MovieLibraryError>) -> Void)
}

protocol InternalMovieLibrary: MovieLibrary {
  var metadata: MovieLibraryMetadata { get set }
}
