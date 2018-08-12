import Foundation
import os.log

public class FileBasedMovieLibrary: MovieLibrary {

  private static let logger = Logging.createLogger(category: "Storage")

  public let delegates: MulticastDelegate<MovieLibraryDelegate> = MulticastDelegate()

  private let url: URL

  private let dataFormat: DataFormat

  private var movies: [TmdbIdentifier: Movie]

  private var pendingContentUpdate = MovieLibraryContentUpdate()

  public init?(url: URL, dataFormat: DataFormat) {
    self.url = url
    self.dataFormat = dataFormat
    if FileManager.default.fileExists(atPath: url.path) {
      os_log("library data file exists", log: FileBasedMovieLibrary.logger, type: .default)
      do {
        let data = try Data(contentsOf: URL(fileURLWithPath: url.path))
        movies = Dictionary(uniqueKeysWithValues: try dataFormat.deserialize(from: data).map { ($0.tmdbID, $0) })
      } catch {
        os_log("failed to load library data: %{public}@",
               log: FileBasedMovieLibrary.logger,
               type: .error,
               String(describing: error))
        return nil
      }
    } else {
      os_log("no data file for library", log: FileBasedMovieLibrary.logger, type: .default)
      movies = [:]
    }
  }

  public func fetchMovies(then completion: @escaping (AsyncResult<[Movie], MovieLibraryError>) -> Void) {
    completion(.success(Array(movies.values)))
  }

  public func fetchMovies(for id: GenreIdentifier,
                          then completion: @escaping (AsyncResult<[Movie], MovieLibraryError>) -> Void) {
    completion(.success(Array(movies.values.filter { $0.genreIds.contains(id) })))
  }

  public func containsMovie(with id: TmdbIdentifier) -> Bool {
    return movies.keys.contains(id)
  }

  public func add(_ movie: Movie, then completion: @escaping (AsyncResult<Void, MovieLibraryError>) -> Void) {
    if movies.keys.contains(movie.tmdbID) { return }
    movies[movie.tmdbID] = movie
    pendingContentUpdate.addedMovies.append(movie)
    do {
      try saveData()
      completion(.success(()))
    } catch {
      completion(.failure(.storageError))
    }
  }

  public func update(_ movie: Movie, then completion: @escaping (AsyncResult<Void, MovieLibraryError>) -> Void) {
    if movies[movie.tmdbID] == nil {
      completion(.failure(.movieDoesNotExist(id: movie.tmdbID)))
      return
    }
    movies[movie.tmdbID] = movie
    pendingContentUpdate.updatedMovies[movie.tmdbID] = movie
    do {
      try saveData()
      completion(.success(()))
    } catch {
      completion(.failure(.storageError))
    }
  }

  public func remove(_ movie: Movie, then completion: @escaping (AsyncResult<Void, MovieLibraryError>) -> Void) {
    if movies[movie.tmdbID] == nil {
      completion(.failure(.movieDoesNotExist(id: movie.tmdbID)))
      return
    }
    movies.removeValue(forKey: movie.tmdbID)
    pendingContentUpdate.removedMovies.append(movie)
    do {
      try saveData()
      completion(.success(()))
    } catch {
      completion(.failure(.storageError))
    }
  }

  private func saveData() throws {
    guard let data = try? dataFormat.serialize(Array(movies.values)) else {
      throw MovieLibraryError.storageError
    }
    guard FileManager.default.createFile(atPath: url.path, contents: data) else {
      throw MovieLibraryError.storageError
    }
    delegates.invoke { $0.library(self, didUpdateContent: self.pendingContentUpdate) }
    pendingContentUpdate = MovieLibraryContentUpdate()
  }

}
