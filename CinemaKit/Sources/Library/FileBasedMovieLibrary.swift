import Dispatch
import Foundation
import os.log

class FileBasedMovieLibrary: InternalMovieLibrary {
  private static let logger = Logging.createLogger(category: "Library")

  var metadata: MovieLibraryMetadata {
    didSet {
      delegates.invoke { $0.libraryDidUpdateMetadata(self) }
    }
  }
  let delegates: MulticastDelegate<MovieLibraryDelegate> = MulticastDelegate()

  private let queue = DispatchQueue(label: "de.martinbauer.cinema.library")
  private let url: URL
  private let dataFormat: DataFormat
  private var movies: [TmdbIdentifier: Movie]?
  private var pendingContentUpdate = MovieLibraryContentUpdate()

  init(metadata: MovieLibraryMetadata, url: URL, dataFormat: DataFormat) {
    self.metadata = metadata
    self.url = url
    self.dataFormat = dataFormat
  }

  private func whenMoviesAreLoaded<R>(else failureHandler: @escaping (AsyncResult<R, MovieLibraryError>) -> Void,
                                      then successHandler: @escaping () -> Void) {
    queue.async {
      guard self.movies == nil else {
        successHandler()
        return
      }
      if FileManager.default.fileExists(atPath: self.url.path) {
        os_log("library data file exists", log: FileBasedMovieLibrary.logger, type: .default)
        do {
          let data = try Data(contentsOf: URL(fileURLWithPath: self.url.path))
          let deserializedMovies = try self.dataFormat.deserialize(from: data)
          self.movies = Dictionary(uniqueKeysWithValues: deserializedMovies.map { ($0.tmdbID, $0) })
          successHandler()
        } catch {
          os_log("failed to load library data: %{public}@",
                 log: FileBasedMovieLibrary.logger,
                 type: .error,
                 String(describing: error))
          failureHandler(.failure(.dataAccessError))
        }
      } else {
        os_log("no data file for library", log: FileBasedMovieLibrary.logger, type: .default)
        self.movies = [:]
        successHandler()
      }
    }
  }

  func fetchMovies(then completion: @escaping (AsyncResult<[Movie], MovieLibraryError>) -> Void) {
    whenMoviesAreLoaded(else: completion) {
      completion(.success(Array(self.movies!.values)))
    }
  }

  func fetchMovies(for id: GenreIdentifier,
                   then completion: @escaping (AsyncResult<[Movie], MovieLibraryError>) -> Void) {
    whenMoviesAreLoaded(else: completion) {
      completion(.success(Array(self.movies!.values.filter { $0.genreIds.contains(id) })))
    }
  }

  func containsMovie(with id: TmdbIdentifier) -> Bool {
    return queue.sync {
      if movies == nil { fatalError("calling containsMovie(with:) is only allowed once movies were loaded") }
      return self.movies!.keys.contains(id)
    }
  }

  func add(_ movie: Movie, then completion: @escaping (AsyncResult<Void, MovieLibraryError>) -> Void) {
    whenMoviesAreLoaded(else: completion) {
      if self.movies!.keys.contains(movie.tmdbID) { return }
      self.movies![movie.tmdbID] = movie
      self.pendingContentUpdate.addedMovies.append(movie)
      do {
        try self.saveData()
        completion(.success(()))
      } catch {
        completion(.failure(.storageError))
      }
    }
  }

  func update(_ movie: Movie, then completion: @escaping (AsyncResult<Void, MovieLibraryError>) -> Void) {
    whenMoviesAreLoaded(else: completion) {
      if self.movies![movie.tmdbID] == nil {
        completion(.failure(.movieDoesNotExist(id: movie.tmdbID)))
        return
      }
      self.movies![movie.tmdbID] = movie
      self.pendingContentUpdate.updatedMovies[movie.tmdbID] = movie
      do {
        try self.saveData()
        completion(.success(()))
      } catch {
        completion(.failure(.storageError))
      }
    }
  }

  func remove(_ movie: Movie, then completion: @escaping (AsyncResult<Void, MovieLibraryError>) -> Void) {
    whenMoviesAreLoaded(else: completion) {
      if self.movies![movie.tmdbID] == nil {
        completion(.failure(.movieDoesNotExist(id: movie.tmdbID)))
        return
      }
      self.movies!.removeValue(forKey: movie.tmdbID)
      self.pendingContentUpdate.removedMovies.append(movie)
      do {
        try self.saveData()
        completion(.success(()))
      } catch {
        completion(.failure(.storageError))
      }
    }
  }

  private func saveData() throws {
    guard let data = try? dataFormat.serialize(Array(movies!.values)) else {
      throw MovieLibraryError.storageError
    }
    guard FileManager.default.createFile(atPath: url.path, contents: data) else {
      throw MovieLibraryError.storageError
    }
    delegates.invoke { $0.library(self, didUpdateContent: self.pendingContentUpdate) }
    pendingContentUpdate = MovieLibraryContentUpdate()
  }
}
