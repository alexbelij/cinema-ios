@testable import CinemaKit
import CloudKit

extension DeviceSyncingLibraryManager {
  static func makeForTesting(
      modelController: MovieLibraryManagerModelControllerMock = .load([]),
      fetchManager: FetchManager = FetchManagerMock(),
      syncManager: SyncManager = SyncManagerMock(),
      changesManager: ChangesManager = ChangesManagerMock.trap(),
      shareManager: ShareManager = ShareManagerMock(),
      dataInvalidationFlag: LocalDataInvalidationFlag = LocalDataInvalidationFlag.makeForTesting())
          -> DeviceSyncingLibraryManager {
    return DeviceSyncingLibraryManager(containerProvider: TestCKContainerProvider(),
                                       fetchManager: fetchManager,
                                       syncManager: syncManager,
                                       changesManager: changesManager,
                                       shareManager: shareManager,
                                       libraryFactory: MockMovieLibraryFactory(),
                                       modelController: modelController,
                                       dataInvalidationFlag: dataInvalidationFlag)
  }
}

extension LocalDataInvalidationFlag {
  static func makeForTesting() -> LocalDataInvalidationFlag {
    return LocalDataInvalidationFlag(userDefaults: StandardUserDefaults(dataStore: UserDefaultsDataStoreMock()))
  }
}

class MockMovieLibraryFactory: MovieLibraryFactory {
  func makeLibrary(with metadata: MovieLibraryMetadata) -> InternalMovieLibrary {
    return MovieLibraryMock(metadata: metadata)
  }
}

class TestCKContainerProvider: CKContainerProvider {
  var container: CKContainer {
    fatalError("can not use container during tests")
  }
}
