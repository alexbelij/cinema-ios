import Foundation

public protocol MovieLibraryDelegate: class {
  func library(_ library: MovieLibrary, didUpdateMovies changeSet: ChangeSet<TmdbIdentifier, Movie>)
  func libraryDidUpdateMetadata(_ library: MovieLibrary)
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
