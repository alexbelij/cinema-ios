@testable import CinemaKit
import CloudKit
import XCTest

class DeviceSyncingLibraryFailureTests: XCTestCase {
  private func assertNonRecoverableError(_ error: MovieLibraryError?, file: StaticString = #file, line: UInt = #line) {
    switch error {
      case .nonRecoverableError?:
        break
      case nil, .tmdbDetailsCouldNotBeFetched?, .globalError?, .movieDoesNotExist?, .permissionFailure?:
        XCTFail("expected nonRecoverableError", file: file, line: line)
    }
  }

  private func assertMovieDoesNotExistError(_ error: MovieLibraryError?,
                                            file: StaticString = #file,
                                            line: UInt = #line) {
    switch error {
      case .movieDoesNotExist?:
        break
      case nil, .tmdbDetailsCouldNotBeFetched?, .globalError?, .nonRecoverableError?, .permissionFailure?:
        XCTFail("expected movieDoesNotExist", file: file, line: line)
    }
  }

  func testFetchMoviesButUnableToLoad() {
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        modelController: MovieLibraryModelControllerMock.fail(with: .nonRecoverableError)
    )

    var result: Result<[Movie], MovieLibraryError>!
    let expectation = self.expectation(description: "fetch completion")
    library.fetchMovies {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    assertNonRecoverableError(result.error)
    assertNonRecoverableError(result.error)
  }

  func testFetchMoviesWithSpecificGenreButUnableToLoad() {
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        modelController: MovieLibraryModelControllerMock.fail(with: .nonRecoverableError)
    )

    var result: Result<[Movie], MovieLibraryError>!
    let expectation = self.expectation(description: "fetch completion")
    library.fetchMovies(for: GenreIdentifier(rawValue: 1)) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    assertNonRecoverableError(result.error)
  }

  func testAddMovieWithoutTmdbProperties() {
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        tmdbPropertiesProvider: TmdbMoviePropertiesProviderMock.returnNil()
    )

    var result: Result<Movie, MovieLibraryError>!
    let expectation = self.expectation(description: "add completion")
    library.addMovie(with: TmdbIdentifier(rawValue: 1), diskType: .bluRay) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    switch result.error {
      case .tmdbDetailsCouldNotBeFetched?:
        break
      case nil, .nonRecoverableError?, .globalError?, .movieDoesNotExist?, .permissionFailure?:
        XCTFail("expected tmdbDetailsCouldNotBeFetched")
    }
  }

  func testAddMovieButUnableToLoad() {
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        modelController: MovieLibraryModelControllerMock.fail(with: .nonRecoverableError),
        tmdbPropertiesProvider: TmdbMoviePropertiesProviderMock.returnEmpty()
    )

    var result: Result<Movie, MovieLibraryError>!
    let expectation = self.expectation(description: "add completion")
    library.addMovie(with: TmdbIdentifier(rawValue: 1), diskType: .bluRay) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    assertNonRecoverableError(result.error)
  }

  func testAddMovie() {
    let syncManager = SyncManagerMock()
    syncManager.whenSync { CloudKitError.nonRecoverableError }
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        modelController: MovieLibraryModelControllerMock.load([]),
        tmdbPropertiesProvider: TmdbMoviePropertiesProviderMock.returnEmpty(),
        syncManager: syncManager
    )

    var result: Result<Movie, MovieLibraryError>!
    let expectation = self.expectation(description: "add completion")
    library.addMovie(with: TmdbIdentifier(rawValue: 1), diskType: .bluRay) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    assertNonRecoverableError(result.error)
  }

  func testUpdateUnknownMovie() {
    let metadata = MovieLibraryMetadata(name: "Library")
    let modelController = MovieLibraryModelControllerMock.load([])
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        metadata: metadata,
        modelController: modelController
    )

    var result: Result<Movie, MovieLibraryError>!
    let expectation = self.expectation(description: "update completion")
    library.update(MovieBuilder.makeMovie(tmdbID: 1, inLibraryWithID: metadata.id)) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    assertMovieDoesNotExistError(result.error)
  }

  func testUpdateMovieButUnableToLoad() {
    let metadata = MovieLibraryMetadata(name: "Library")
    let modelController = MovieLibraryModelControllerMock.fail(with: .nonRecoverableError)
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        metadata: metadata,
        modelController: modelController
    )

    var result: Result<Movie, MovieLibraryError>!
    let expectation = self.expectation(description: "update completion")
    library.update(MovieBuilder.makeMovie(tmdbID: 1, inLibraryWithID: metadata.id)) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    assertNonRecoverableError(result.error)
  }

  func testUpdateMovieButSyncFails() {
    let metadata = MovieLibraryMetadata(name: "Library")
    let movie = MovieBuilder.makeMovie(tmdbID: 1, inLibraryWithID: metadata.id, title: "Movie")
    let modelController = MovieLibraryModelControllerMock.load([movie])
    let syncManager = SyncManagerMock()
    syncManager.whenSync { CloudKitError.nonRecoverableError }
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        metadata: metadata,
        modelController: modelController,
        syncManager: syncManager
    )

    var updatedMovie = movie
    let newTitle = "Updated"
    updatedMovie.title = newTitle
    var result: Result<Movie, MovieLibraryError>!
    let expectation = self.expectation(description: "update completion")
    library.update(updatedMovie) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    assertNonRecoverableError(result.error)
    XCTAssertTrue(modelController.didRequestReload)
  }

  func testUpdateDeletedMovie() {
    let metadata = MovieLibraryMetadata(name: "Library")
    let movie = MovieBuilder.makeMovie(tmdbID: 1, inLibraryWithID: metadata.id, title: "Movie")
    let modelController = MovieLibraryModelControllerMock.load([movie])
    let syncManager = SyncManagerMock()
    syncManager.whenSync { CloudKitError.itemNoLongerExists }
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        metadata: metadata,
        modelController: modelController,
        syncManager: syncManager
    )

    var updatedMovie = movie
    let newTitle = "Updated"
    updatedMovie.title = newTitle
    var result: Result<Movie, MovieLibraryError>!
    let expectation = self.expectation(description: "update completion")
    library.update(updatedMovie) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    assertMovieDoesNotExistError(result.error)
    XCTAssertTrue(modelController.model!.movies.isEmpty)
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testRemoveMovieButUnableToLoad() {
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        modelController: MovieLibraryModelControllerMock.fail(with: .nonRecoverableError)
    )

    var result: Result<Void, MovieLibraryError>!
    let expectation = self.expectation(description: "remove completion")
    library.removeMovie(with: TmdbIdentifier(rawValue: 1)) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    assertNonRecoverableError(result.error)
  }

  func testRemoveMovie() {
    let metadata = MovieLibraryMetadata(name: "Library")
    let syncManager = SyncManagerMock()
    syncManager.whenDelete { CloudKitError.nonRecoverableError }
    let movie = MovieBuilder.makeMovie(tmdbID: 1, inLibraryWithID: metadata.id)
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        metadata: metadata,
        modelController: MovieLibraryModelControllerMock.load([movie]),
        syncManager: syncManager
    )

    var result: Result<Void, MovieLibraryError>!
    let expectation = self.expectation(description: "remove completion")
    library.removeMovie(with: movie.tmdbID) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    assertNonRecoverableError(result.error)
  }
}
