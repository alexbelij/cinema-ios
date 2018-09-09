@testable import CinemaKit
import CloudKit

class MovieLibraryModelControllerMock: ModelController {
  let model: MovieLibraryModel?
  private let error: MovieLibraryError?

  private init(movies: [Movie]) {
    self.model = MovieLibraryModel(
        movies: Dictionary(uniqueKeysWithValues: movies.map { ($0.id, $0) }),
        movieRecords: Dictionary(uniqueKeysWithValues: movies.map { ($0.id, MovieRecord(from: $0.cloudProperties)) }),
        recordIDsByTmdbID: Dictionary(uniqueKeysWithValues: movies.map { ($0.tmdbID, $0.id) }))
    self.error = nil
  }

  private init(error: MovieLibraryError) {
    self.model = nil
    self.error = error
  }

  func initializeWithDefaultValue() {
    fatalError("not implemented")
  }

  func access(onceLoaded modelHandler: @escaping (MovieLibraryModel) -> Void,
              whenUnableToLoad errorHandler: @escaping (MovieLibraryError) -> Void) {
    if let model = model {
      modelHandler(model)
    } else if let error = error {
      errorHandler(error)
    }
  }

  func access(_ modelHandler: @escaping (MovieLibraryModel) -> Void) {
    if let model = model {
      modelHandler(model)
    } else if error != nil {
      fatalError("accessing model which could not be loaded")
    }
  }

  var didRequestReload = false

  func requestReload() {
    didRequestReload = true
  }

  var didCallPersist = false

  func persist() {
    didCallPersist = true
  }

  var didCallClear = false

  func clear() {
    didCallClear = true
  }
}

extension MovieLibraryModelControllerMock {
  static func load(_ movies: [Movie]) -> MovieLibraryModelControllerMock {
    return MovieLibraryModelControllerMock(movies: movies)
  }

  static func fail(with error: MovieLibraryError) -> MovieLibraryModelControllerMock {
    return MovieLibraryModelControllerMock(error: error)
  }
}
