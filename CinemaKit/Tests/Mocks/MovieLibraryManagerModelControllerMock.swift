@testable import CinemaKit
import CloudKit

class MovieLibraryManagerModelControllerMock: ModelController {
  let model: MovieLibraryManagerModel?
  private let error: MovieLibraryManagerError?

  private init(libraries: [InternalMovieLibrary]) {
    if libraries.contains(where: { $0.metadata.isShared }) {
      preconditionFailure("this initializer does not allow for shared libraries")
    }
    self.model = MovieLibraryManagerModel(
        libraries: Dictionary(uniqueKeysWithValues: libraries.map { ($0.metadata.id, $0) }),
        libraryRecords: Dictionary(uniqueKeysWithValues: libraries.map {
          ($0.metadata.id, LibraryRecord(from: $0.metadata))
        }),
        shareRecords: [:])
    self.error = nil
  }

  private init(libraries: [InternalMovieLibrary], libraryRecords: [LibraryRecord], shares: [CKShare]) {
    self.model = MovieLibraryManagerModel(
        libraries: Dictionary(uniqueKeysWithValues: libraries.map { ($0.metadata.id, $0) }),
        libraryRecords: Dictionary(uniqueKeysWithValues: libraryRecords.map { ($0.id, $0) }),
        shareRecords: Dictionary(uniqueKeysWithValues: shares.map { ($0.recordID, $0) }))
    self.error = nil
  }

  private init(error: MovieLibraryManagerError) {
    self.model = nil
    self.error = error
  }

  func initializeWithDefaultValue() {
    fatalError("not implemented")
  }

  func access(onceLoaded modelHandler: @escaping (MovieLibraryManagerModel) -> Void,
              whenUnableToLoad errorHandler: @escaping (MovieLibraryManagerError) -> Void) {
    if let model = model {
      modelHandler(model)
    } else if let error = error {
      errorHandler(error)
    }
  }

  func access(_ modelHandler: @escaping (MovieLibraryManagerModel) -> Void) {
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

extension MovieLibraryManagerModelControllerMock {
  static func load(_ libraries: [InternalMovieLibrary]) -> MovieLibraryManagerModelControllerMock {
    return MovieLibraryManagerModelControllerMock(libraries: libraries)
  }

  static func load(_ libraries: [InternalMovieLibrary],
                   _ libraryRecords: [LibraryRecord],
                   _ shares: [CKShare]) -> MovieLibraryManagerModelControllerMock {
    return MovieLibraryManagerModelControllerMock(libraries: libraries, libraryRecords: libraryRecords, shares: shares)
  }

  static func fail(with error: MovieLibraryManagerError) -> MovieLibraryManagerModelControllerMock {
    return MovieLibraryManagerModelControllerMock(error: error)
  }
}
