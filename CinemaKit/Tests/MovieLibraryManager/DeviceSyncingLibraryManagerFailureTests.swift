@testable import CinemaKit
import CloudKit
import XCTest

class DeviceSyncingLibraryManagerFailureTests: XCTestCase {
  private func assertNonRecoverableError(_ error: MovieLibraryManagerError?,
                                         file: StaticString = #file,
                                         line: UInt = #line) {
    switch error {
      case .nonRecoverableError?:
        break
      case nil, .globalError?, .libraryDoesNotExist?, .permissionFailure?:
        XCTFail("expected nonRecoverableError", file: file, line: line)
    }
  }

  private func assertLibraryDoesNotExistError(_ error: MovieLibraryManagerError?,
                                              file: StaticString = #file,
                                              line: UInt = #line) {
    switch error {
      case .libraryDoesNotExist?:
        break
      case nil, .globalError?, .permissionFailure?, .nonRecoverableError?:
        XCTFail("expected libraryDoesNotExist", file: file, line: line)
    }
  }

  func testFetchLibrariesButUnableToLoad() {
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: MovieLibraryManagerModelControllerMock.fail(with: .nonRecoverableError)
    )

    var result: Result<[MovieLibrary], MovieLibraryManagerError>!
    let expectation = self.expectation(description: "fetch completion")
    libraryManager.fetchLibraries {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    assertNonRecoverableError(result.error)
  }

  func testAddLibrary() {
    let syncManager = SyncManagerMock()
    syncManager.whenSync { CloudKitError.nonRecoverableError }
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: MovieLibraryManagerModelControllerMock.load([]),
        syncManager: syncManager
    )

    var result: Result<MovieLibrary, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "add completion")
    libraryManager.addLibrary(with: MovieLibraryMetadata(name: "Library")) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    assertNonRecoverableError(result.error)
  }

  func testAddLibraryButUnableToLoad() {
    let syncManager = SyncManagerMock()
    syncManager.whenSync { nil }
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: MovieLibraryManagerModelControllerMock.fail(with: .nonRecoverableError),
        syncManager: syncManager
    )

    var result: Result<MovieLibrary, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "add completion")
    libraryManager.addLibrary(with: MovieLibraryMetadata(name: "Library")) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    assertNonRecoverableError(result.error)
  }

  func testUpdateUnknownLibrary() {
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: MovieLibraryManagerModelControllerMock.load([])
    )

    var result: Result<MovieLibrary, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "update completion")
    libraryManager.updateLibrary(with: MovieLibraryMetadata(name: "Library")) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    assertLibraryDoesNotExistError(result.error)
  }

  func testUpdateLibraryButUnableToLoad() {
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: MovieLibraryManagerModelControllerMock.fail(with: .nonRecoverableError)
    )

    var result: Result<MovieLibrary, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "update completion")
    libraryManager.updateLibrary(with: MovieLibraryMetadata(name: "Library")) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    assertNonRecoverableError(result.error)
  }

  func testUpdateLibraryButSyncFails() {
    let library = MovieLibraryMock()
    let modelController = MovieLibraryManagerModelControllerMock.load([library])
    let syncManager = SyncManagerMock()
    syncManager.whenSync { CloudKitError.nonRecoverableError }
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        syncManager: syncManager
    )

    var result: Result<MovieLibrary, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "update completion")
    var metadata = library.metadata
    let newName = "Updated"
    metadata.name = newName
    libraryManager.updateLibrary(with: metadata) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    assertNonRecoverableError(result.error)
    XCTAssertTrue(modelController.didRequestReload)
  }

  func testUpdateDeletedLibrary() {
    let library = MovieLibraryMock()
    let modelController = MovieLibraryManagerModelControllerMock.load([library])
    let syncManager = SyncManagerMock()
    syncManager.whenSync { CloudKitError.itemNoLongerExists }
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        syncManager: syncManager
    )

    var result: Result<MovieLibrary, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "update completion")
    var metadata = library.metadata
    let newName = "Updated"
    metadata.name = newName
    libraryManager.updateLibrary(with: metadata) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    assertLibraryDoesNotExistError(result.error)
    XCTAssertTrue(modelController.model!.libraries.isEmpty)
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testRemoveLibraryButUnableToLoad() {
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: MovieLibraryManagerModelControllerMock.fail(with: .nonRecoverableError)
    )

    var result: Result<Void, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "remove completion")
    libraryManager.removeLibrary(with: makeRecordID()) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    assertNonRecoverableError(result.error)
  }

  func testRemoveLibrary() {
    let library = MovieLibraryMock()
    let syncManager = SyncManagerMock()
    syncManager.whenDelete { CloudKitError.nonRecoverableError }
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: MovieLibraryManagerModelControllerMock.load([library]),
        syncManager: syncManager
    )

    var result: Result<Void, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "remove completion")
    libraryManager.removeLibrary(with: library.metadata.id) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    assertNonRecoverableError(result.error)
  }

  func testFetchChangesButFetchFails() {
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: MovieLibraryManagerModelControllerMock.load([]),
        changesManager: ChangesManagerMock.fail(with: .nonRecoverableError)
    )

    var result: Result<Bool, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "fetch changes completion")
    libraryManager.fetchChanges {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    assertNonRecoverableError(result.error)
  }

  func testAcceptShareButUnableToLoad() {
    let (_, sharedLibraryRecord, share) = SampleData.library(sharedBy: "User1")
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: MovieLibraryManagerModelControllerMock.fail(with: .nonRecoverableError)
    )
    let shareMetadata = CKShareMetadataMock(share: share, rootRecordID: sharedLibraryRecord.id)

    var result: Result<AcceptShareResult, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "accept completion")
    libraryManager.acceptCloudKitShare(with: shareMetadata) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    assertNonRecoverableError(result.error)
  }

  func testAcceptShareButAcceptingFailed() {
    let (_, sharedLibraryRecord, share) = SampleData.library(sharedBy: "User1")
    let modelController = MovieLibraryManagerModelControllerMock.load([])
    let shareManager = ShareManagerMock()
    shareManager.whenAcceptShare { CloudKitError.nonRecoverableError }
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        shareManager: shareManager
    )
    let shareMetadata = CKShareMetadataMock(share: share, rootRecordID: sharedLibraryRecord.id)

    var result: Result<AcceptShareResult, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "accept completion")
    libraryManager.acceptCloudKitShare(with: shareMetadata) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    assertNonRecoverableError(result.error)
  }

  func testAcceptShareButFetchingRootRecordFailed() {
    let (_, sharedLibraryRecord, share) = SampleData.library(sharedBy: "User1")
    let modelController = MovieLibraryManagerModelControllerMock.load([])
    let fetchManager = FetchManagerMock()
    fetchManager.whenFetchRecord { (nil, CloudKitError.nonRecoverableError) }
    let shareManager = ShareManagerMock()
    shareManager.whenAcceptShare { nil }
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        fetchManager: fetchManager,
        shareManager: shareManager
    )
    let shareMetadata = CKShareMetadataMock(share: share, rootRecordID: sharedLibraryRecord.id)

    var result: Result<AcceptShareResult, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "accept completion")
    libraryManager.acceptCloudKitShare(with: shareMetadata) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isFailure)
    assertNonRecoverableError(result.error)
  }
}
