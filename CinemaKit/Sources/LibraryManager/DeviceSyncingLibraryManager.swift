import CloudKit
import Dispatch
import MobileCoreServices
import os.log
import UIKit

protocol MovieLibraryFactory {
  func makeLibrary(with metadata: MovieLibraryMetadata) -> InternalMovieLibrary
}

class DeviceSyncingLibraryManager: MovieLibraryManager {
  private static let logger = Logging.createLogger(category: "LibraryManager")

  let delegates = MulticastDelegate<MovieLibraryManagerDelegate>()
  private let container: CKContainer
  private let queueFactory: DatabaseOperationQueueFactory
  private let fetchManager: FetchManager
  private let syncManager: SyncManager
  private let subscriptionManager: SubscriptionManager
  private let changesManager: ChangesManager
  private let libraryFactory: MovieLibraryFactory
  private let localData: RecordData<MovieLibraryManagerDataObject, MovieLibraryManagerError>
  private let cacheInvalidationFlag: LocalCloudKitCacheInvalidationFlag

  init(container: CKContainer,
       queueFactory: DatabaseOperationQueueFactory,
       fetchManager: FetchManager,
       syncManager: SyncManager,
       subscriptionManager: SubscriptionManager,
       changesManager: ChangesManager,
       libraryFactory: MovieLibraryFactory,
       data: RecordData<MovieLibraryManagerDataObject, MovieLibraryManagerError>,
       cacheInvalidationFlag: LocalCloudKitCacheInvalidationFlag = LocalCloudKitCacheInvalidationFlag()) {
    self.container = container
    self.queueFactory = queueFactory
    self.fetchManager = fetchManager
    self.syncManager = syncManager
    self.subscriptionManager = subscriptionManager
    self.changesManager = changesManager
    self.libraryFactory = libraryFactory
    self.localData = data
    self.cacheInvalidationFlag = cacheInvalidationFlag
  }
}

// MARK: - core functionality

extension DeviceSyncingLibraryManager {
  func fetchLibraries(then completion: @escaping (Result<[MovieLibrary], MovieLibraryManagerError>) -> Void) {
    localData.access(onceLoaded: { data in
      completion(.success(Array(data.libraries.values)))
    }, whenUnableToLoad: { error in
      completion(.failure(error))
    })
  }

  func addLibrary(with metadata: MovieLibraryMetadata,
                  then completion: @escaping (Result<MovieLibrary, MovieLibraryManagerError>) -> Void) {
    let record = LibraryRecord(from: metadata)
    self.syncManager.sync(record.rawRecord, using: self.queueFactory.queue(withScope: .private)) { error in
      self.addCompletion(metadata, record, error, completion)
    }
  }

  private func addCompletion(_ metadata: MovieLibraryMetadata,
                             _ record: LibraryRecord,
                             _ error: CloudKitError?,
                             _ completion: @escaping (Result<MovieLibrary, MovieLibraryManagerError>) -> Void) {
    if let error = error {
      switch error {
        case .notAuthenticated, .userDeletedZone, .nonRecoverableError:
          completion(.failure(error.asMovieLibraryManagerError))
        case .conflict, .itemNoLongerExists, .zoneNotFound:
          fatalError("should not occur: \(error)")
      }
    } else {
      localData.access { data in
        let library = self.libraryFactory.makeLibrary(with: metadata)
        data.libraries[metadata.id] = library
        data.libraryRecords[metadata.id] = record
        self.localData.persist()
        let changeSet = ChangeSet<CKRecordID, MovieLibrary>(insertions: [library])
        self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
        completion(.success(library))
      }
    }
  }

  func updateLibrary(with metadata: MovieLibraryMetadata,
                     then completion: @escaping (Result<MovieLibrary, MovieLibraryManagerError>) -> Void) {
    localData.access(onceLoaded: { data in
      guard let record = data.libraryRecords[metadata.id] else {
        completion(.failure(.libraryDoesNotExist))
        return
      }
      metadata.setCustomFields(in: record)
      let queue = self.queueFactory.queue(withScope: .private)
      self.syncManager.sync(record.rawRecord, using: queue) { error in
        self.updateCompletion(metadata, record, error, completion)
      }
    }, whenUnableToLoad: { error in
      completion(.failure(error))
    })
  }

  private func updateCompletion(_ metadata: MovieLibraryMetadata,
                                _ record: LibraryRecord,
                                _ error: CloudKitError?,
                                _ completion: @escaping (Result<MovieLibrary, MovieLibraryManagerError>) -> Void) {
    localData.access { data in
      if let error = error {
        switch error {
          case let .conflict(serverRecord):
            LibraryRecord.copyCustomFields(from: record.rawRecord, to: serverRecord)
            data.libraryRecords[metadata.id] = LibraryRecord(serverRecord)
            os_log("resolved library metadata record conflict", log: DeviceSyncingLibraryManager.logger, type: .default)
            self.updateLibrary(with: metadata, then: completion)
          case .itemNoLongerExists:
            if let removedLibrary = data.libraries.removeValue(forKey: metadata.id) {
              data.libraryRecords.removeValue(forKey: metadata.id)
              removedLibrary.cleanupForRemoval()
              let changeSet = ChangeSet<CKRecordID, MovieLibrary>(deletions: [metadata.id: removedLibrary])
              self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
            } else {
              // library has already been removed via changes
              assert(data.libraryRecords[metadata.id] == nil)
            }
            completion(.failure(.libraryDoesNotExist))
          case .userDeletedZone:
            completion(.failure(error.asMovieLibraryManagerError))
          case .notAuthenticated, .nonRecoverableError:
            // reset record
            // TODO check if change tag has changed (serverRecordChanged)
            data.libraries[metadata.id]!.metadata.setCustomFields(in: record)
            completion(.failure(.nonRecoverableError))
          case .zoneNotFound:
            fatalError("should not occur: \(error)")
        }
      } else {
        let library = data.libraries[metadata.id]!
        library.metadata = metadata
        self.localData.persist()
        let changeSet = ChangeSet<CKRecordID, MovieLibrary>(modifications: [library.metadata.id: library])
        self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
        completion(.success(library))
      }
    }
  }

  func removeLibrary(with id: CKRecordID, then completion: @escaping (Result<Void, MovieLibraryManagerError>) -> Void) {
    // TODO add new library when only one left
    localData.access(onceLoaded: { data in
      guard let record = data.libraryRecords[id] else {
        completion(.success(()))
        return
      }
      let library = data.libraries[id]!
      let queue = self.queueFactory.queue(withScope: .private)
      self.syncManager.delete(record.rawRecord, using: queue) { error in
        self.removeCompletion(library, error, completion)
      }
    }, whenUnableToLoad: { error in
      completion(.failure(error))
    })
  }

  private func removeCompletion(_ library: InternalMovieLibrary,
                                _ error: CloudKitError?,
                                _ completion: @escaping (Result<Void, MovieLibraryManagerError>) -> Void) {
    if let error = error {
      switch error {
        case .itemNoLongerExists:
          completion(.success(()))
        case .notAuthenticated, .userDeletedZone, .nonRecoverableError:
          completion(.failure(error.asMovieLibraryManagerError))
        case .conflict, .zoneNotFound:
          fatalError("should not occur: \(error)")
      }
    } else {
      localData.access { data in
        data.libraries.removeValue(forKey: library.metadata.id)
        data.libraryRecords.removeValue(forKey: library.metadata.id)
        library.cleanupForRemoval()
        self.localData.persist()
        let changeSet = ChangeSet<CKRecordID, MovieLibrary>(deletions: [library.metadata.id: library])
        self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
        completion(.success(()))
      }
    }
  }
}

// MARK: - apply changes

extension DeviceSyncingLibraryManager {
  func fetchChanges(then completion: @escaping (UIBackgroundFetchResult) -> Void) {
    self.changesManager.fetchChanges { changes, error in
      if let error = error {
        switch error {
          case .userDeletedZone:
            // shouldCancelAllActions is not set to true, because otherwise
            // the controller level never gets an .userDeletedZone error
            os_log("unable to fetch changes: userDeletedZone", log: DeviceSyncingLibraryManager.logger, type: .error)
            completion(.failed)
          case .notAuthenticated, .nonRecoverableError:
            os_log("unable to fetch changes: %{public}@",
                   log: DeviceSyncingLibraryManager.logger,
                   type: .error,
                   String(describing: error))
            completion(.failed)
          case .conflict, .itemNoLongerExists, .zoneNotFound:
            fatalError("should not occur: \(error)")
        }
      } else if let changes = changes {
        if changes.hasChanges {
          self.processChanges(changes)
          completion(.newData)
        } else {
          completion(.noData)
        }
      }
    }
  }

  private func processChanges(_ changes: FetchedChanges) {
    localData.access(onceLoaded: { data in
      var changeSet = ChangeSet<CKRecordID, MovieLibrary>()
      self.process(changedRecords: changes.changedRecords, changeSet: &changeSet, data: data)
      self.process(deletedRecordIDsAndTypes: changes.deletedRecordIDsAndTypes,
                   changeSet: &changeSet,
                   data: data)
      if changeSet.hasPublicChanges || changeSet.hasInternalChanges {
        self.localData.persist()
      }
      if changeSet.hasPublicChanges {
        self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
      }
      for id in Set(data.libraries.keys) {
        data.libraries[id]!.processChanges(changes)
      }
    }, whenUnableToLoad: { error in
      os_log("unable to process changes, because loading failed: %{public}@",
             log: DeviceSyncingLibraryManager.logger,
             type: .default,
             String(describing: error))
    })
  }

  private func process(changedRecords: [CKRecord],
                       changeSet: inout ChangeSet<CKRecordID, MovieLibrary>,
                       data: MovieLibraryManagerDataObject) {
    var updatedMetadata = [CKRecordID: MovieLibraryMetadata]()
    for rawRecord in changedRecords where rawRecord.recordType == LibraryRecord.recordType {
      let record = LibraryRecord(rawRecord)
      data.libraryRecords[record.id] = record
      let newMetadata = MovieLibraryMetadata(from: record)
      if let existingLibrary = data.libraries[record.id] {
        if existingLibrary.metadata != newMetadata {
          updatedMetadata[newMetadata.id] = newMetadata
          existingLibrary.metadata = newMetadata
          changeSet.modifications[newMetadata.id] = existingLibrary
        }
      } else {
        let newLibrary = self.libraryFactory.makeLibrary(with: newMetadata)
        data.libraries[record.id] = newLibrary
        changeSet.insertions.append(newLibrary)
      }
    }
  }

  private func process(deletedRecordIDsAndTypes: [(CKRecordID, String)],
                       changeSet: inout ChangeSet<CKRecordID, MovieLibrary>,
                       data: MovieLibraryManagerDataObject) {
    for (recordID, recordType) in deletedRecordIDsAndTypes
        where recordType == LibraryRecord.recordType && data.libraries[recordID] != nil {
      let removedLibrary = data.libraries.removeValue(forKey: recordID)!
      data.libraryRecords.removeValue(forKey: recordID)
      changeSet.deletions[removedLibrary.metadata.id] = removedLibrary
    }
  }
}
