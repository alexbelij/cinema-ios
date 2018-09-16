@testable import CinemaKit
import XCTest

class DeviceSyncingLibraryManagerTests: XCTestCase {
  func testFetchLibraries() {
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: .load([MovieLibraryMock()])
    )

    var result: Result<[MovieLibrary], MovieLibraryManagerError>!
    let expectation = self.expectation(description: "fetch completion")
    libraryManager.fetchLibraries {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertEqual(result.value!.count, 1)
  }

  func testAddLibrary() {
    let modelController = MovieLibraryManagerModelControllerMock.load([])
    let syncManager = SyncManagerMock()
    syncManager.whenSync { nil }
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        syncManager: syncManager
    )

    var result: Result<MovieLibrary, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "add completion")
    libraryManager.addLibrary(with: MovieLibraryMetadata(name: "Library")) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertEqual(modelController.model!.libraries.count, 1)
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testUpdateLibrary() {
    let library = MovieLibraryMock()
    let modelController = MovieLibraryManagerModelControllerMock.load([library])
    let syncManager = SyncManagerMock()
    syncManager.whenSync { nil }
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

    XCTAssertTrue(result.isSuccess)
    XCTAssertEqual(result.value!.metadata.name, newName)
    XCTAssertEqual(modelController.model!.libraries.count, 1)
    XCTAssertEqual(modelController.model!.libraries.first!.value.metadata.name, newName)
    XCTAssertEqual(modelController.model!.libraryRecords.first!.value.name, newName)
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testUpdateLibraryWithConflict() {
    let localLibrary = MovieLibraryMock(metadata: MovieLibraryMetadata(name: "Local"))
    let remoteLibraryRecord = LibraryRecord(from: localLibrary.metadata)
    remoteLibraryRecord.name = "Remote"
    let modelController = MovieLibraryManagerModelControllerMock.load([localLibrary])
    let syncManager = SyncManagerMock()
    syncManager.whenSync {
      CloudKitError.conflict(serverRecord: remoteLibraryRecord.rawRecord)
    }
    syncManager.whenSync { nil }
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        syncManager: syncManager
    )

    var updatedMetadata = localLibrary.metadata
    let newName = "Updated"
    updatedMetadata.name = newName
    var result: Result<MovieLibrary, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "update completion")
    libraryManager.updateLibrary(with: updatedMetadata) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertEqual(result.value!.metadata.name, newName)
    XCTAssertEqual(modelController.model!.libraries.count, 1)
    XCTAssertEqual(modelController.model!.libraries.first!.value.metadata.name, newName)
    XCTAssertEqual(modelController.model!.libraryRecords.first!.value.name, newName)
    XCTAssertEqual(modelController.model!.libraryRecords.first!.value.id, remoteLibraryRecord.id)
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testRemoveExistingLibrary() {
    let library1 = MovieLibraryMock(metadata: MovieLibraryMetadata(name: "Library1"))
    let library2 = MovieLibraryMock(metadata: MovieLibraryMetadata(name: "Library2"))
    let modelController = MovieLibraryManagerModelControllerMock.load([library1, library2])
    let syncManager = SyncManagerMock()
    syncManager.whenDelete { nil }
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        syncManager: syncManager
    )

    var result: Result<Void, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "remove completion")
    libraryManager.removeLibrary(with: library1.metadata.id) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertTrue(library1.didCallCleanupForRemoval)
    XCTAssertEqual(modelController.model!.libraries.count, 1)
    XCTAssertEqual(modelController.model!.libraryRecords.first!.value.id, library2.metadata.id)
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testRemoveUnknownLibrary() {
    let modelController = MovieLibraryManagerModelControllerMock.load([])
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(modelController: modelController)

    var result: Result<Void, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "remove completion")
    libraryManager.removeLibrary(with: makeRecordID()) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertFalse(modelController.didCallPersist)
  }

  func testRemoveDeletedLibrary() {
    let library = MovieLibraryMock()
    let modelController = MovieLibraryManagerModelControllerMock.load([library])
    let syncManager = SyncManagerMock()
    syncManager.whenDelete { CloudKitError.itemNoLongerExists }
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        syncManager: syncManager
    )

    var result: Result<Void, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "remove completion")
    libraryManager.removeLibrary(with: library.metadata.id) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertTrue(modelController.model!.libraries.isEmpty)
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testRemoveLibraryWhileAlreadyRemoved() {
    let library = MovieLibraryMock()
    let modelController = MovieLibraryManagerModelControllerMock.load([library])
    let syncManager = SyncManagerMock()
    syncManager.whenDelete {
      modelController.model!.remove(library.metadata.id)
      return CloudKitError.itemNoLongerExists
    }
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        syncManager: syncManager
    )

    var result: Result<Void, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "remove completion")
    libraryManager.removeLibrary(with: library.metadata.id) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertTrue(modelController.model!.libraries.isEmpty)
    XCTAssertFalse(modelController.didCallPersist)
  }

  func testAcceptShareRejectsUsersShare() {
    let (_, sharedLibraryRecord, share) = SampleData.librarySharedByDefaultUser()
    let modelController = MovieLibraryManagerModelControllerMock.load([])
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController
    )
    let shareMetadata = CKShareMetadataMock(share: share, rootRecordID: sharedLibraryRecord.id)

    var result: Result<AcceptShareResult, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "accept completion")
    libraryManager.acceptCloudKitShare(with: shareMetadata) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    switch result.value! {
      case .aborted(.currentUserIsOwner): break
      default: XCTFail("\(result.value!) is not \(AcceptShareResult.aborted(.currentUserIsOwner))")
    }
    XCTAssertTrue(modelController.model!.libraries.isEmpty)
    XCTAssertFalse(modelController.didCallPersist)
  }

  func testAcceptShareRejectsAlreadyAcceptedShare() {
    let (_, sharedLibraryRecord, share) = SampleData.library(sharedBy: "User1")
    let library = MovieLibraryMock(metadata: MovieLibraryMetadata(from: sharedLibraryRecord))
    let modelController = MovieLibraryManagerModelControllerMock.load([library], [sharedLibraryRecord], [share])
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController
    )
    let shareMetadata = CKShareMetadataMock(share: share, rootRecordID: sharedLibraryRecord.id)

    var result: Result<AcceptShareResult, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "accept completion")
    libraryManager.acceptCloudKitShare(with: shareMetadata) {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    switch result.value! {
      case .aborted(.alreadyAccepted): break
      default: XCTFail("\(result.value!) is not \(AcceptShareResult.aborted(.alreadyAccepted))")
    }
    XCTAssertEqual(modelController.model!.libraries.count, 1)
    XCTAssertFalse(modelController.didCallPersist)
  }

  func testAcceptShare() {
    let (_, sharedLibraryRecord, share) = SampleData.library(sharedBy: "User1")
    let modelController = MovieLibraryManagerModelControllerMock.load([])
    let fetchManager = FetchManagerMock()
    fetchManager.whenFetchRecord { (sharedLibraryRecord.rawRecord, nil) }
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

    XCTAssertTrue(result.isSuccess)
    switch result.value! {
      case .accepted: break
      default: XCTFail("\(result.value!) is not \(AcceptShareResult.accepted)")
    }
    XCTAssertEqual(modelController.model!.libraries.count, 1)
    XCTAssertTrue(modelController.didCallPersist)
  }
}
