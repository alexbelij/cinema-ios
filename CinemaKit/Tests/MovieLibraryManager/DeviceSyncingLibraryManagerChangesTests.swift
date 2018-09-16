@testable import CinemaKit
import CloudKit
import XCTest

class DeviceSyncingLibraryManagerChangesTests: XCTestCase {
  func testProcessEmptyChanges() {
    let library = MovieLibraryMock()
    let modelController = MovieLibraryManagerModelControllerMock.load([library])
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        changesManager: ChangesManagerMock.fetch(FetchedChanges())
    )

    var result: Result<Bool, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "fetch changes completion")
    libraryManager.fetchChanges {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertFalse(result.value!)
    XCTAssertFalse(modelController.didCallPersist)
    XCTAssertFalse(library.didCallProcessChanges)
  }

  func testFetchChangesButUnableToLoad() {
    let changes = FetchedChanges(changedRecords: [LibraryRecord(from: MovieLibraryMetadata(name: "Library")).rawRecord])
    let userDefaults = UserDefaultsMock()
    let dataInvalidationFlag = LocalDataInvalidationFlag(userDefaults: userDefaults)
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: MovieLibraryManagerModelControllerMock.fail(with: .nonRecoverableError),
        changesManager: ChangesManagerMock.fetch(changes),
        dataInvalidationFlag: dataInvalidationFlag
    )

    var result: Result<Bool, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "fetch changes completion")
    libraryManager.fetchChanges {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertTrue(result.value!)
    XCTAssertTrue(dataInvalidationFlag.isSet)
  }

  func testFetchChangesForwardsToLibraries() {
    let library = MovieLibraryMock()
    let modelController = MovieLibraryManagerModelControllerMock.load([library])
    let newLibraryRecord = LibraryRecord(from: MovieLibraryMetadata(name: "Private"))
    let changes = FetchedChanges(changedRecords: [newLibraryRecord.rawRecord])
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        changesManager: ChangesManagerMock.fetch(changes)
    )

    var result: Result<Bool, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "fetch changes completion")
    libraryManager.fetchChanges {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertTrue(library.didCallProcessChanges)
  }

  func testProcessChangesAddsPrivateLibrary() {
    let modelController = MovieLibraryManagerModelControllerMock.load([])
    let newLibraryRecord = LibraryRecord(from: MovieLibraryMetadata(name: "Private"))
    let changes = FetchedChanges(changedRecords: [newLibraryRecord.rawRecord])
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        changesManager: ChangesManagerMock.fetch(changes)
    )

    var result: Result<Bool, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "fetch changes completion")
    libraryManager.fetchChanges {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertTrue(result.value!)
    XCTAssertNotNil(modelController.model!.libraries[newLibraryRecord.id])
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testFetchChangesUpdatesPrivateLibrary() {
    let library = MovieLibraryMock(metadata: MovieLibraryMetadata(name: "Private"))
    let modelController = MovieLibraryManagerModelControllerMock.load([library])
    let updatedLibraryRecord = LibraryRecord(from: library.metadata)
    updatedLibraryRecord.name = "Updated"
    let changes = FetchedChanges(changedRecords: [updatedLibraryRecord.rawRecord])
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        changesManager: ChangesManagerMock.fetch(changes)
    )

    var result: Result<Bool, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "fetch changes completion")
    libraryManager.fetchChanges {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertTrue(result.value!)
    XCTAssertEqual(modelController.model!.libraries[updatedLibraryRecord.id]!.metadata.name, "Updated")
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testFetchChangesRemovedPrivateLibrary() {
    let library = MovieLibraryMock(metadata: MovieLibraryMetadata(name: "Private"))
    let modelController = MovieLibraryManagerModelControllerMock.load([library])
    let changes = FetchedChanges(deletedRecordIDsAndTypes: [(library.metadata.id, LibraryRecord.recordType)])
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        changesManager: ChangesManagerMock.fetch(changes)
    )

    var result: Result<Bool, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "fetch changes completion")
    libraryManager.fetchChanges {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertTrue(result.value!)
    XCTAssertNil(modelController.model!.libraries[library.metadata.id])
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testProcessChangesAfterUserSharedLibrary() {
    let (privateLibraryRecord, sharedLibraryRecord, share) = SampleData.librarySharedByDefaultUser()
    let library = MovieLibraryMock(metadata: MovieLibraryMetadata(from: privateLibraryRecord))
    let modelController = MovieLibraryManagerModelControllerMock.load([library])
    let changes = FetchedChanges(changedRecords: [sharedLibraryRecord.rawRecord, share])
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        changesManager: ChangesManagerMock.fetch(changes)
    )

    var result: Result<Bool, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "fetch changes completion")
    libraryManager.fetchChanges {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertTrue(result.value!)
    XCTAssertTrue(library.metadata.isShared)
    let shareID = modelController.model!.libraryRecords[library.metadata.id]!.shareID
    XCTAssertNotNil(shareID)
    XCTAssertNotNil(modelController.model!.shareRecords[shareID!])
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testProcessChangesAfterUserStopSharingLibrary() {
    let (privateLibraryRecord, sharedLibraryRecord, share) = SampleData.librarySharedByDefaultUser()
    let library = MovieLibraryMock(metadata: MovieLibraryMetadata(from: sharedLibraryRecord))
    let modelController = MovieLibraryManagerModelControllerMock.load([library], [sharedLibraryRecord], [share])
    let changes = FetchedChanges(changedRecords: [privateLibraryRecord.rawRecord],
                                 deletedRecordIDsAndTypes: [(share.recordID, CKRecord.SystemType.share)])
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        changesManager: ChangesManagerMock.fetch(changes)
    )

    var result: Result<Bool, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "fetch changes completion")
    libraryManager.fetchChanges {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertTrue(result.value!)
    XCTAssertFalse(library.metadata.isShared)
    XCTAssertNil(modelController.model!.libraryRecords[library.metadata.id]!.shareID)
    XCTAssertTrue(modelController.model!.shareRecords.isEmpty)
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testFetchChangesAddsSharedLibrary() {
    let (_, sharedLibraryRecord, share) = SampleData.librarySharedByDefaultUser()
    let modelController = MovieLibraryManagerModelControllerMock.load([])
    let changes = FetchedChanges(changedRecords: [sharedLibraryRecord.rawRecord, share])
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        changesManager: ChangesManagerMock.fetch(changes)
    )

    var result: Result<Bool, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "fetch changes completion")
    libraryManager.fetchChanges {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertTrue(result.value!)
    XCTAssertNotNil(modelController.model!.libraries[sharedLibraryRecord.id])
    XCTAssertNotNil(modelController.model!.shareRecords[share.recordID])
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testFetchChangesUpdatesSharedLibrary() {
    let (_, sharedLibraryRecord, share) = SampleData.librarySharedByDefaultUser()
    let library = MovieLibraryMock(metadata: MovieLibraryMetadata(from: sharedLibraryRecord))
    let modelController = MovieLibraryManagerModelControllerMock.load([library], [sharedLibraryRecord], [share])
    // swiftlint:disable:next force_cast
    let updatedLibraryRecord = LibraryRecord(sharedLibraryRecord.rawRecord.copy() as! CKRecord)
    updatedLibraryRecord.name = "Updated"
    let changes = FetchedChanges(changedRecords: [updatedLibraryRecord.rawRecord])
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        changesManager: ChangesManagerMock.fetch(changes)
    )

    var result: Result<Bool, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "fetch changes completion")
    libraryManager.fetchChanges {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertTrue(result.value!)
    XCTAssertEqual(library.metadata.name, "Updated")
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testFetchChangesUpdatesShare() {
    let (_, sharedLibraryRecord, share) = SampleData.librarySharedByDefaultUser()
    let library = MovieLibraryMock(metadata: MovieLibraryMetadata(from: sharedLibraryRecord))
    let modelController = MovieLibraryManagerModelControllerMock.load([library], [sharedLibraryRecord], [share])
    // swiftlint:disable:next force_cast
    let updatedShareRecord = share.copy() as! CKShare
    updatedShareRecord[CKShare.SystemFieldKey.title] = "Updated"
    let changes = FetchedChanges(changedRecords: [updatedShareRecord])
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        changesManager: ChangesManagerMock.fetch(changes)
    )

    var result: Result<Bool, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "fetch changes completion")
    libraryManager.fetchChanges {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertTrue(result.value!)
    // swiftlint:disable:next force_cast
    XCTAssertEqual(modelController.model!.shareRecords.first!.value[CKShare.SystemFieldKey.title] as! String, "Updated")
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testFetchChangesWhenUserDeletesSharedLibrary() {
    let (_, sharedLibraryRecord, share) = SampleData.librarySharedByDefaultUser()
    let library = MovieLibraryMock(metadata: MovieLibraryMetadata(from: sharedLibraryRecord))
    let modelController = MovieLibraryManagerModelControllerMock.load([library], [sharedLibraryRecord], [share])
    let changes = FetchedChanges(deletedRecordIDsAndTypes: [(sharedLibraryRecord.id, LibraryRecord.recordType),
                                                            (share.recordID, CKRecord.SystemType.share)])
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        changesManager: ChangesManagerMock.fetch(changes)
    )

    var result: Result<Bool, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "fetch changes completion")
    libraryManager.fetchChanges {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertTrue(result.value!)
    XCTAssertTrue(modelController.model!.libraries.isEmpty)
    XCTAssertTrue(modelController.model!.shareRecords.isEmpty)
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testFetchChangesWhenSharedLibraryHasBeenDeleted() {
    let (_, sharedLibraryRecord, share) = SampleData.librarySharedByDefaultUser()
    let library = MovieLibraryMock(metadata: MovieLibraryMetadata(from: sharedLibraryRecord))
    let modelController = MovieLibraryManagerModelControllerMock.load([library], [sharedLibraryRecord], [share])
    let changes = FetchedChanges(deletedSharedZoneIDs: [sharedLibraryRecord.id.zoneID])
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        changesManager: ChangesManagerMock.fetch(changes)
    )

    var result: Result<Bool, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "fetch changes completion")
    libraryManager.fetchChanges {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertTrue(result.value!)
    XCTAssertTrue(modelController.model!.libraries.isEmpty)
    XCTAssertTrue(modelController.model!.shareRecords.isEmpty)
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testFetchChangesWhenSharedLibraryHasBeenDeletedButAnotherLibraryIsLeftInZone() {
    let (_, sharedLibraryRecord1, share1) = SampleData.librarySharedByDefaultUser()
    let (_, sharedLibraryRecord2, share2) = SampleData.librarySharedByDefaultUser()
    let library1 = MovieLibraryMock(metadata: MovieLibraryMetadata(from: sharedLibraryRecord1))
    let library2 = MovieLibraryMock(metadata: MovieLibraryMetadata(from: sharedLibraryRecord2))
    let modelController = MovieLibraryManagerModelControllerMock.load([library1, library2],
                                                                      [sharedLibraryRecord1, sharedLibraryRecord2],
                                                                      [share1, share2])
    let changes = FetchedChanges(deletedRecordIDsAndTypes: [(sharedLibraryRecord1.id, LibraryRecord.recordType),
                                                            (share1.recordID, CKRecord.SystemType.share)])
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        changesManager: ChangesManagerMock.fetch(changes)
    )

    var result: Result<Bool, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "fetch changes completion")
    libraryManager.fetchChanges {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertTrue(result.value!)
    XCTAssertEqual(modelController.model!.libraries.count, 1)
    XCTAssertEqual(modelController.model!.shareRecords.count, 1)
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testFetchChangesWhenUserDidNotAcceptShareLocally() {
    let (_, sharedLibraryRecord, share) = SampleData.librarySharedByDefaultUser()
    let modelController = MovieLibraryManagerModelControllerMock.load([])
    let shareManager = ShareManagerMock()
    shareManager.whenFetchShareMetadata {
      ([CKShareMetadataMock(share: share, rootRecord: sharedLibraryRecord.rawRecord)], nil)
    }
    let changes = FetchedChanges(changedRecords: [share])
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        changesManager: ChangesManagerMock.fetch(changes),
        shareManager: shareManager
    )

    var result: Result<Bool, MovieLibraryManagerError>!
    let expectation = self.expectation(description: "fetch changes completion")
    libraryManager.fetchChanges {
      result = $0
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(result.isSuccess)
    XCTAssertTrue(result.value!)
    XCTAssertEqual(modelController.model!.libraries.count, 1)
    XCTAssertEqual(modelController.model!.shareRecords.count, 1)
    XCTAssertTrue(modelController.didCallPersist)
  }

  func testFetchChangesWhenUserDidNotAcceptShareLocallyButFetchFails() {
    let (_, _, share) = SampleData.librarySharedByDefaultUser()
    let modelController = MovieLibraryManagerModelControllerMock.load([])
    let shareManager = ShareManagerMock()
    shareManager.whenFetchShareMetadata { (nil, CloudKitError.nonRecoverableError) }
    let changes = FetchedChanges(changedRecords: [share])
    let userDefaults = UserDefaultsMock()
    let dataInvalidationFlag = LocalDataInvalidationFlag(userDefaults: userDefaults)
    let libraryManager = DeviceSyncingLibraryManager.makeForTesting(
        modelController: modelController,
        changesManager: ChangesManagerMock.fetch(changes),
        shareManager: shareManager,
        dataInvalidationFlag: dataInvalidationFlag
    )

    let expectation = self.expectation(description: "fetch changes completion")
    libraryManager.fetchChanges { _ in
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)

    XCTAssertTrue(dataInvalidationFlag.isSet)
  }
}
