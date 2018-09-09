@testable import CinemaKit
import CloudKit
import XCTest

class DeviceSyncingLibraryChangesTests: XCTestCase {
  func testProcessEmptyChanges() {
    let modelController = MovieLibraryModelControllerMock.load([])
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        modelController: modelController
    )
    let changes = FetchedChanges()

    library.processChanges(changes)

    XCTAssertFalse(modelController.didCallPersist)
  }

  func testProcessChangesAddsMovie() {
    let metadata = MovieLibraryMetadata(name: "Library")
    let modelController = MovieLibraryModelControllerMock.load([])
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        metadata: metadata,
        modelController: modelController,
        tmdbPropertiesProvider: TmdbMoviePropertiesProviderMock.returnEmpty()
    )
    let newMovie = MovieBuilder.makeMovie(tmdbID: 1, inLibraryWithID: metadata.id)
    let changes = FetchedChanges(changedRecords: [MovieRecord(from: newMovie.cloudProperties).rawRecord])

    library.processChanges(changes)

    XCTAssertNotNil(modelController.model!.movies[newMovie.id])
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testProcessChangesUpdatesMovie() {
    let metadata = MovieLibraryMetadata(name: "Library")
    let movie = MovieBuilder.makeMovie(tmdbID: 1, inLibraryWithID: metadata.id)
    let modelController = MovieLibraryModelControllerMock.load([movie])
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        metadata: metadata,
        modelController: modelController,
        tmdbPropertiesProvider: TmdbMoviePropertiesProviderMock.returnEmpty()
    )
    let updatedRecord = MovieRecord(from: movie.cloudProperties)
    updatedRecord.title = "Updated"
    let changes = FetchedChanges(changedRecords: [updatedRecord.rawRecord])

    library.processChanges(changes)

    XCTAssertNotNil(modelController.model!.movies[movie.id])
    XCTAssertEqual(modelController.model!.movies[movie.id]!.title, "Updated")
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testProcessChangesRemovesMovie() {
    let metadata = MovieLibraryMetadata(name: "Library")
    let movie = MovieBuilder.makeMovie(tmdbID: 1, inLibraryWithID: metadata.id)
    let modelController = MovieLibraryModelControllerMock.load([movie])
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        metadata: metadata,
        modelController: modelController
    )
    let changes = FetchedChanges(deletedRecordIDsAndTypes: [(movie.id, MovieRecord.recordType)])

    library.processChanges(changes)

    XCTAssertTrue(modelController.model!.movies.isEmpty)
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testProcessChangesSkipsMoviesWhichDoNotBelongToLibrary() {
    let modelController = MovieLibraryModelControllerMock.load([])
    let library = DeviceSyncingMovieLibrary.makeForTesting(
        metadata: MovieLibraryMetadata(name: "Library"),
        modelController: modelController
    )
    let movie = MovieBuilder.makeMovie(tmdbID: 1, inLibraryWithID: makeRecordID())
    let changes = FetchedChanges(changedRecords: [MovieRecord(from: movie.cloudProperties).rawRecord])

    library.processChanges(changes)

    XCTAssertTrue(modelController.model!.movies.isEmpty)
    XCTAssertFalse(modelController.didCallPersist)
  }
}
