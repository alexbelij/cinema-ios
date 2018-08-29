import CloudKit
import Foundation

public protocol MovieLibraryDelegate: class {
  func library(_ library: MovieLibrary, didUpdateMovies changeSet: ChangeSet<TmdbIdentifier, Movie>)
  func libraryDidUpdateMetadata(_ library: MovieLibrary)
}

public enum MovieLibraryError: Error {
  case detailsFetchError
  case globalError(ApplicationWideEvent)
  case nonRecoverableError
  case movieDoesNotExist
  case permissionFailure
}

extension CloudKitError {
  var asMovieLibraryError: MovieLibraryError {
    switch self {
      case .itemNoLongerExists:
        return .movieDoesNotExist
      case .notAuthenticated:
        return .globalError(.notAuthenticated)
      case .userDeletedZone:
        return .globalError(.userDeletedZone)
      case .permissionFailure:
        return .permissionFailure
      case .nonRecoverableError:
        return .nonRecoverableError
      case .conflict, .zoneNotFound:
        fatalError("\(self) can not be expressed as MovieLibraryError")
    }
  }
}

public protocol MovieLibrary: class {
  var metadata: MovieLibraryMetadata { get }
  var delegates: MulticastDelegate<MovieLibraryDelegate> { get }

  // accessing library content
  func fetchMovies(then completion: @escaping (Result<[Movie], MovieLibraryError>) -> Void)
  func fetchMovies(for id: GenreIdentifier,
                   then completion: @escaping (Result<[Movie], MovieLibraryError>) -> Void)

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

  func processChanges(_ changes: FetchedChanges)
  func cleanupForRemoval()
}
