@testable import CinemaKit
import CloudKit
import XCTest

class DeviceSyncingLibraryTests: XCTestCase {
  func testFetchMovies() {
    let metadata = MovieLibraryMetadata(name: "Library")
    let modelController = MovieLibraryModelControllerMock.load(
        [MovieBuilder.makeMovie(tmdbID: 1, inLibraryWithID: metadata.id)])
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        metadata: metadata,
        modelController: modelController
    )

    var result: Result<[Movie], MovieLibraryError>!
    let expectation = self.expectation(description: "fetch completion")
    library.fetchMovies {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertEqual(result.value!.count, 1)
  }

  func testFetchMoviesWithSpecificGenre() {
    let metadata = MovieLibraryMetadata(name: "Library")
    let modelController = MovieLibraryModelControllerMock.load(
        [MovieBuilder.makeMovie(tmdbID: 1, inLibraryWithID: metadata.id, genreId: 1),
         MovieBuilder.makeMovie(tmdbID: 2, inLibraryWithID: metadata.id, genreId: 2)])
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        metadata: metadata,
        modelController: modelController
    )

    var result: Result<[Movie], MovieLibraryError>!
    let expectation = self.expectation(description: "fetch completion")
    library.fetchMovies(for: GenreIdentifier(rawValue: 1)) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertEqual(result.value!.count, 1)
  }

  func testAddExistingMovie() {
    let metadata = MovieLibraryMetadata(name: "Library")
    let movie = MovieBuilder.makeMovie(tmdbID: 1, inLibraryWithID: metadata.id)
    let modelController = MovieLibraryModelControllerMock.load([movie])
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        metadata: metadata,
        modelController: modelController
    )

    var result: Result<Movie, MovieLibraryError>!
    let expectation = self.expectation(description: "add completion")
    library.addMovie(with: movie.tmdbID, diskType: .bluRay) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertEqual(modelController.model!.movies.count, 1)
    XCTAssertFalse(modelController.didCallPersist)
  }

  func testAddNewMovie() {
    let metadata = MovieLibraryMetadata(name: "Library")
    let movie = MovieBuilder.makeMovie(tmdbID: 1, inLibraryWithID: metadata.id)
    let modelController = MovieLibraryModelControllerMock.load([movie])
    let syncManager = SyncManagerMock()
    syncManager.whenSync { nil }
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        metadata: metadata,
        modelController: modelController,
        tmdbPropertiesProvider: TmdbMoviePropertiesProviderMock.returnEmpty(),
        syncManager: syncManager
    )

    var result: Result<Movie, MovieLibraryError>!
    let expectation = self.expectation(description: "add completion")
    library.addMovie(with: TmdbIdentifier(rawValue: 2), diskType: .bluRay) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertEqual(modelController.model!.movies.count, 2)
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testAddMovieAsDuplicate() {
    let metadata = MovieLibraryMetadata(name: "Library")
    let modelController = MovieLibraryModelControllerMock.load(
        [MovieBuilder.makeMovie(tmdbID: 1, inLibraryWithID: metadata.id)])
    let newMovie = MovieBuilder.makeMovie(tmdbID: 2, inLibraryWithID: metadata.id)
    let syncManager = SyncManagerMock()
    syncManager.whenSync {
      modelController.model!.add(newMovie, with: MovieRecord(from: newMovie.cloudProperties))
      return nil
    }
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        metadata: metadata,
        modelController: modelController,
        tmdbPropertiesProvider: TmdbMoviePropertiesProviderMock.returnEmpty(),
        syncManager: syncManager
    )

    var result: Result<Movie, MovieLibraryError>!
    let expectation = self.expectation(description: "add completion")
    library.addMovie(with: newMovie.tmdbID, diskType: .bluRay) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertEqual(modelController.model!.movies.count, 2)
    XCTAssertEqual(newMovie.id, result.value!.id)
    XCTAssertEqual(syncManager.silentlyDeletedRecordIDs.count, 1)
  }

  func testUpdateMovie() {
    let metadata = MovieLibraryMetadata(name: "Library")
    let movie = MovieBuilder.makeMovie(tmdbID: 1, inLibraryWithID: metadata.id, title: "Movie")
    let modelController = MovieLibraryModelControllerMock.load([movie])
    let syncManager = SyncManagerMock()
    syncManager.whenSync { nil }
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

    XCTAssertTrue(result.isSuccess)
    XCTAssertEqual(result.value!.title, newTitle)
    XCTAssertEqual(modelController.model!.movies.count, 1)
    XCTAssertEqual(modelController.model!.movies.first!.value.title, newTitle)
    XCTAssertEqual(modelController.model!.movieRecords.first!.value.title, newTitle)
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testUpdateMovieWithConflict() {
    let metadata = MovieLibraryMetadata(name: "Library")
    let localMovie = MovieBuilder.makeMovie(tmdbID: 1, inLibraryWithID: metadata.id, title: "Local")
    let remoteMovieRecord = MovieRecord(from: localMovie.cloudProperties)
    remoteMovieRecord.title = "Remote"
    let modelController = MovieLibraryModelControllerMock.load([localMovie])
    let syncManager = SyncManagerMock()
    syncManager.whenSync {
      CloudKitError.conflict(serverRecord: remoteMovieRecord.rawRecord)
    }
    syncManager.whenSync { nil }
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        metadata: metadata,
        modelController: modelController,
        syncManager: syncManager
    )

    var updatedMovie = localMovie
    let newTitle = "Updated"
    updatedMovie.title = newTitle
    var result: Result<Movie, MovieLibraryError>!
    let expectation = self.expectation(description: "update completion")
    library.update(updatedMovie) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertEqual(result.value!.title, newTitle)
    XCTAssertEqual(modelController.model!.movies.count, 1)
    XCTAssertEqual(modelController.model!.movies.first!.value.title, newTitle)
    XCTAssertEqual(modelController.model!.movieRecords.first!.value.title, newTitle)
    XCTAssertEqual(modelController.model!.movieRecords.first!.value.id, remoteMovieRecord.id)
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testRemoveExistingMovie() {
    let metadata = MovieLibraryMetadata(name: "Library")
    let movie1 = MovieBuilder.makeMovie(tmdbID: 1, inLibraryWithID: metadata.id)
    let movie2 = MovieBuilder.makeMovie(tmdbID: 2, inLibraryWithID: metadata.id)
    let modelController = MovieLibraryModelControllerMock.load([movie1, movie2])
    let syncManager = SyncManagerMock()
    syncManager.whenDelete { nil }
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        metadata: metadata,
        modelController: modelController,
        syncManager: syncManager
    )

    var result: Result<Void, MovieLibraryError>!
    let expectation = self.expectation(description: "remove completion")
    library.removeMovie(with: movie1.tmdbID) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertEqual(modelController.model!.movies.count, 1)
    XCTAssertEqual(modelController.model!.movieRecords.first!.value.id, movie2.id)
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testRemoveUnknownMovie() {
    let modelController = MovieLibraryModelControllerMock.load([])
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        modelController: modelController
    )

    var result: Result<Void, MovieLibraryError>!
    let expectation = self.expectation(description: "remove completion")
    library.removeMovie(with: TmdbIdentifier(rawValue: 42)) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertFalse(modelController.didCallPersist)
  }

  func testRemoveDeletedMovie() {
    let metadata = MovieLibraryMetadata(name: "Library")
    let movie = MovieBuilder.makeMovie(tmdbID: 1, inLibraryWithID: metadata.id)
    let modelController = MovieLibraryModelControllerMock.load([movie])
    let syncManager = SyncManagerMock()
    syncManager.whenDelete { CloudKitError.itemNoLongerExists }
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        metadata: metadata,
        modelController: modelController,
        syncManager: syncManager
    )

    var result: Result<Void, MovieLibraryError>!
    let expectation = self.expectation(description: "remove completion")
    library.removeMovie(with: movie.tmdbID) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertTrue(modelController.model!.movies.isEmpty)
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testRemoveMovieWhileAlreadyRemoved() {
    let metadata = MovieLibraryMetadata(name: "Library")
    let movie = MovieBuilder.makeMovie(tmdbID: 1, inLibraryWithID: metadata.id)
    let modelController = MovieLibraryModelControllerMock.load([movie])
    let syncManager = SyncManagerMock()
    syncManager.whenDelete {
      modelController.model!.remove(movie.id)
      return CloudKitError.itemNoLongerExists
    }
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        metadata: metadata,
        modelController: modelController,
        syncManager: syncManager
    )

    var result: Result<Void, MovieLibraryError>!
    let expectation = self.expectation(description: "remove completion")
    library.removeMovie(with: movie.tmdbID) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertTrue(modelController.model!.movies.isEmpty)
    XCTAssertFalse(modelController.didCallPersist)
  }
}
