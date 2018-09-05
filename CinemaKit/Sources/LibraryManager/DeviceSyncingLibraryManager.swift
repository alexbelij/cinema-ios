import CloudKit
import Dispatch
import MobileCoreServices
import os.log
import UIKit

protocol MovieLibraryFactory {
  func makeLibrary(with metadata: MovieLibraryMetadata) -> InternalMovieLibrary
}

class DeviceSyncingLibraryManager: InternalMovieLibraryManager {
  private static let logger = Logging.createLogger(category: "LibraryManager")

  let delegates = MulticastDelegate<MovieLibraryManagerDelegate>()
  private let container: CKContainer
  private let queueFactory: DatabaseOperationQueueFactory
  private let fetchManager: FetchManager
  private let syncManager: SyncManager
  private let changesManager: ChangesManager
  private let shareManager: ShareManager
  private let libraryFactory: MovieLibraryFactory
  private let localData: LazyData<MovieLibraryManagerDataObject, MovieLibraryManagerError>
  private let dataInvalidationFlag: LocalDataInvalidationFlag

  init(container: CKContainer,
       queueFactory: DatabaseOperationQueueFactory,
       fetchManager: FetchManager,
       syncManager: SyncManager,
       changesManager: ChangesManager,
       shareManager: ShareManager,
       libraryFactory: MovieLibraryFactory,
       data: LazyData<MovieLibraryManagerDataObject, MovieLibraryManagerError>,
       dataInvalidationFlag: LocalDataInvalidationFlag = LocalDataInvalidationFlag()) {
    self.container = container
    self.queueFactory = queueFactory
    self.fetchManager = fetchManager
    self.syncManager = syncManager
    self.changesManager = changesManager
    self.shareManager = shareManager
    self.libraryFactory = libraryFactory
    self.localData = data
    self.dataInvalidationFlag = dataInvalidationFlag
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
        case .conflict, .itemNoLongerExists, .zoneNotFound, .permissionFailure:
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
      let scope = metadata.isCurrentUserOwner ? CKDatabaseScope.private : CKDatabaseScope.shared
      let queue = self.queueFactory.queue(withScope: scope)
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
          case .notAuthenticated, .permissionFailure, .nonRecoverableError:
            // need to reset record (changed keys)
            self.localData.requestReload()
            completion(.failure(error.asMovieLibraryManagerError))
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
    localData.access(onceLoaded: { data in
      guard let record = data.libraryRecords[id] else {
        completion(.success(()))
        return
      }
      let library = data.libraries[id]!
      let scope = data.libraries[id]!.metadata.isCurrentUserOwner ? CKDatabaseScope.private : CKDatabaseScope.shared
      let queue = self.queueFactory.queue(withScope: scope)
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
        case .notAuthenticated, .userDeletedZone, .permissionFailure, .nonRecoverableError:
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
  func fetchChanges(then completion: @escaping (Result<Bool, MovieLibraryManagerError>) -> Void) {
    self.changesManager.fetchChanges { changes, error in
      if let error = error {
        switch error {
          case .userDeletedZone:
            completion(.failure(.globalError(.userDeletedZone)))
          case .notAuthenticated, .nonRecoverableError:
            completion(.failure(error.asMovieLibraryManagerError))
          case .conflict, .itemNoLongerExists, .zoneNotFound, .permissionFailure:
            fatalError("should not occur: \(error)")
        }
      } else if let changes = changes {
        if changes.hasChanges {
          self.processChanges(changes)
          completion(.success(true))
        } else {
          completion(.success(false))
        }
      }
    }
  }

  private func processChanges(_ changes: FetchedChanges) {
    localData.access(onceLoaded: { data in
      var changeSet = ChangeSet<CKRecordID, MovieLibrary>()
      self.process(deletedSharedZoneIDs: changes.deletedSharedZoneIDs,
                   changeSet: &changeSet,
                   data: data)
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
             type: .error,
             String(describing: error))
    })
  }

  func process(deletedSharedZoneIDs: [CKRecordZoneID],
               changeSet: inout ChangeSet<CKRecordID, MovieLibrary>,
               data: MovieLibraryManagerDataObject) {
    for zoneID in deletedSharedZoneIDs {
      for removedLibrary in data.libraries.values.filter({ $0.metadata.id.zoneID == zoneID }) {
        data.libraries.removeValue(forKey: removedLibrary.metadata.id)
        data.libraryRecords.removeValue(forKey: removedLibrary.metadata.id)
        changeSet.deletions[removedLibrary.metadata.id] = removedLibrary
      }
    }
  }

  private func process(changedRecords: [CKRecord],
                       changeSet: inout ChangeSet<CKRecordID, MovieLibrary>,
                       data: MovieLibraryManagerDataObject) {
    var updatedMetadata = [CKRecordID: MovieLibraryMetadata]()
    for rawRecord in changedRecords where rawRecord.recordType == LibraryRecord.recordType {
      let record = LibraryRecord(rawRecord)
      data.libraryRecords[record.id] = record
      if let existingLibrary = data.libraries[record.id] {
        let newMetadata = MovieLibraryMetadata(from: record,
                                               currentUserCanModify: existingLibrary.metadata.currentUserCanModify)
        if existingLibrary.metadata != newMetadata {
          updatedMetadata[newMetadata.id] = newMetadata
          changeSet.modifications[newMetadata.id] = existingLibrary
        }
      } else {
        let isCurrentUserOwner = record.id.zoneID.ownerName == CKCurrentUserDefaultName
        let newMetadata = MovieLibraryMetadata(from: record, currentUserCanModify: isCurrentUserOwner)
        let newLibrary = self.libraryFactory.makeLibrary(with: newMetadata)
        data.libraries[record.id] = newLibrary
        changeSet.insertions.append(newLibrary)
      }
    }
    for rawRecord in changedRecords where rawRecord.recordType == "cloudkit.share" {
      // swiftlint:disable:next force_cast
      let share = rawRecord as! CKShare
      data.shareRecords[share.recordID] = share
      if let (libraryID, _) =
      data.libraryRecords.first(where: { _, record in record.shareID == share.recordID }) {
        let library = data.libraries[libraryID]!
        var newMetadata = updatedMetadata[library.metadata.id] ?? library.metadata
        newMetadata.currentUserCanModify = share.currentUserParticipant?.permission == .readWrite
        updatedMetadata[newMetadata.id] = newMetadata
        changeSet.modifications[newMetadata.id] = library
      }
    }
    for (id, newMetadata) in updatedMetadata {
      data.libraries[id]!.metadata = newMetadata
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
    for (recordID, recordType) in deletedRecordIDsAndTypes where recordType == "cloudkit.share" {
      data.shareRecords.removeValue(forKey: recordID)
    }
  }
}

// MARK: - sharing

extension DeviceSyncingLibraryManager {
  func prepareCloudSharingController(
      forLibraryWith metadata: MovieLibraryMetadata,
      then completion: @escaping (Result<CloudSharingControllerParameters, MovieLibraryManagerError>) -> Void) {
    localData.access(onceLoaded: { data in
      guard let library = data.libraries[metadata.id] else {
        completion(.failure(.libraryDoesNotExist))
        return
      }
      if metadata.isShared {
        guard let share = data.shareRecords[metadata.shareRecordID!] else {
          fatalError("share should have been already fetched")
        }
        completion(.success(.hasBeenShared(share, self.container, self)))
      } else {
        let preparationHandler = { sharingCompletion in
          self.prepareShare(for: library) { result in
            switch result {
              case let .failure(error):
                sharingCompletion(nil, nil, error)
              case let .success(share):
                sharingCompletion(share, self.container, nil)
            }
          }
        } as (@escaping (CKShare?, CKContainer?, Error?) -> Void) -> Void
        completion(.success(.hasNotBeenShared(preparationHandler, self)))
      }
    }, whenUnableToLoad: { error in
      completion(.failure(error))
    })
  }

  private func prepareShare(for library: InternalMovieLibrary,
                            then completion: @escaping (Result<CKShare, MovieLibraryManagerError>) -> Void) {
    localData.access { data in
      let rootRecord = data.libraryRecords[library.metadata.id]!
      let share = CKShare(rootRecord: rootRecord.rawRecord)
      share.publicPermission = .none
      share[CKShareTitleKey] = library.metadata.name as CKRecordValue
      share[CKShareTypeKey] = (kUTTypeDatabase as String) as CKRecordValue
      self.shareManager.saveShare(share, with: rootRecord.rawRecord) { error in
        self.prepareShareCompletion(library, share, rootRecord, error, completion)
      }
    }
  }

  private func prepareShareCompletion(
      _ library: InternalMovieLibrary,
      _ share: CKShare,
      _ rootRecord: LibraryRecord,
      _ error: CloudKitError?,
      _ completion: @escaping (Result<CKShare, MovieLibraryManagerError>) -> Void) {
    localData.access { data in
      if let error = error {
        switch error {
          case let .conflict(serverRecord):
            let libraryRecord = LibraryRecord(serverRecord)
            data.libraryRecords[library.metadata.id] = libraryRecord
            share[CKShareTitleKey] = libraryRecord.name as CKRecordValue
            os_log("using updated library record for share", log: DeviceSyncingLibraryManager.logger, type: .default)
            self.shareManager.saveShare(share, with: serverRecord) { error in
              self.prepareShareCompletion(library, share, libraryRecord, error, completion)
            }
          case .notAuthenticated, .userDeletedZone, .itemNoLongerExists, .nonRecoverableError:
            completion(.failure(error.asMovieLibraryManagerError))
          case .zoneNotFound, .permissionFailure:
            fatalError("should not occur: \(error)")
        }
      } else {
        data.shareRecords[share.recordID] = share
        var newMetadata = MovieLibraryMetadata(from: data.libraryRecords[library.metadata.id]!,
                                               currentUserCanModify: true)
        newMetadata.shareRecordID = share.recordID
        library.metadata = newMetadata
        self.localData.persist()
        let changeSet = ChangeSet<CKRecordID, MovieLibrary>(modifications: [library.metadata.id: library])
        self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
        completion(.success(share))
      }
    }
  }

  func acceptCloudKitShare(with shareMetadata: CKShareMetadata) {
    shareManager.acceptShare(with: shareMetadata) { error in
      self.acceptShareCompletion(shareMetadata, error)
    }
  }

  private func acceptShareCompletion(_ shareMetadata: CKShareMetadata, _ error: CloudKitError?) {
    if let error = error {
      switch error {
        case .itemNoLongerExists:
          os_log("owner stopped sharing", log: DeviceSyncingLibraryManager.logger, type: .default)
        case .notAuthenticated, .zoneNotFound, .userDeletedZone, .nonRecoverableError:
          os_log("unable to accept share %{public}@",
                 log: DeviceSyncingLibraryManager.logger,
                 type: .error,
                 String(describing: error))
        case .conflict, .permissionFailure:
          fatalError("should not occur: \(error)")
      }
    } else {
      localData.access(onceLoaded: { data in
        guard data.libraries[shareMetadata.rootRecordID] == nil else {
          os_log("already fetched shared library", log: DeviceSyncingLibraryManager.logger, type: .default)
          return
        }
        self.fetchManager.fetchRecord(with: shareMetadata.rootRecordID,
                                      using: self.queueFactory.queue(withScope: .shared)) { rootRecord, error in
          self.fetchRootRecordCompletion(shareMetadata, rootRecord, error)
        }
      }, whenUnableToLoad: { error in
        os_log("accepted share, but could not load libraries: %{public}@",
               log: DeviceSyncingLibraryManager.logger,
               type: .error,
               String(describing: error))
      })
    }
  }

  private func fetchRootRecordCompletion(_ shareMetadata: CKShareMetadata,
                                         _ rootRecord: CKRecord?,
                                         _ error: CloudKitError?) {
    if let error = error {
      switch error {
        case .zoneNotFound, .itemNoLongerExists:
          os_log("owner stopped sharing record", log: DeviceSyncingLibraryManager.logger, type: .default)
        case .notAuthenticated, .nonRecoverableError:
          os_log("unable to fetch shared record %{public}@",
                 log: DeviceSyncingLibraryManager.logger,
                 type: .error,
                 String(describing: error))
        case .conflict, .userDeletedZone, .permissionFailure:
          fatalError("should not occur: \(error)")
      }
    } else if let rootRecord = rootRecord {
      localData.access { data in
        let libraryRecord = LibraryRecord(rootRecord)
        let currentUserCanModify = shareMetadata.share.currentUserParticipant?.permission == .readWrite
        let metadata = MovieLibraryMetadata(from: libraryRecord, currentUserCanModify: currentUserCanModify)
        let library = self.libraryFactory.makeLibrary(with: metadata)
        data.libraries[libraryRecord.id] = library
        data.libraryRecords[libraryRecord.id] = libraryRecord
        data.shareRecords[shareMetadata.share.recordID] = shareMetadata.share
        self.localData.persist()
        let changeSet = ChangeSet<CKRecordID, MovieLibrary>(insertions: [library])
        self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
      }
    }
  }
}

extension DeviceSyncingLibraryManager: CloudSharingControllerCallback {
  func didStopSharingLibrary(with metadata: MovieLibraryMetadata) {
    localData.access { data in
      guard let library = data.libraries[metadata.id] else {
        preconditionFailure("library has been removed while presenting sharing controller")
      }
      if library.metadata.isCurrentUserOwner {
        data.shareRecords.removeValue(forKey: library.metadata.shareRecordID!)
        library.metadata.shareRecordID = nil
        self.fetchManager.fetchRecord(with: library.metadata.id,
                                      using: self.queueFactory.queue(withScope: .private)) { rawRecord, error in
          if let error = error {
            switch error {
              case .nonRecoverableError:
                self.dataInvalidationFlag.set()
                os_log("unable to fetch record after sharing stopped: %{public}@",
                       log: DeviceSyncingLibraryManager.logger,
                       type: .error,
                       String(describing: error))
              case .notAuthenticated, .userDeletedZone, .itemNoLongerExists, .zoneNotFound, .conflict,
                   .permissionFailure:
                fatalError("should not occur: \(error)")
            }
          } else if let rawRecord = rawRecord {
            self.localData.access { data in
              let record = LibraryRecord(rawRecord)
              data.libraryRecords[record.id] = record
              library.metadata = MovieLibraryMetadata(from: record, currentUserCanModify: true)
              self.localData.persist()
              let changeSet = ChangeSet<CKRecordID, MovieLibrary>(modifications: [library.metadata.id: library])
              self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
            }
          }
        }
      } else {
        data.libraries.removeValue(forKey: library.metadata.id)
        data.libraryRecords.removeValue(forKey: library.metadata.id)
        data.shareRecords.removeValue(forKey: library.metadata.shareRecordID!)
        library.cleanupForRemoval()
        self.localData.persist()
        let changeSet = ChangeSet<CKRecordID, MovieLibrary>(deletions: [library.metadata.id: library])
        self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
      }
    }
  }
}

extension DeviceSyncingLibraryManager {
  func migrateLegacyLibrary(with name: String, at url: URL, then completion: @escaping (Bool) -> Void) {
    let metadata = MovieLibraryMetadata(name: name)
    let libraryRecord = LibraryRecord(from: metadata)
    self.syncManager.sync(libraryRecord.rawRecord, using: self.queueFactory.queue(withScope: .private)) { error in
      if let error = error {
        switch error {
          case .notAuthenticated, .userDeletedZone, .nonRecoverableError:
            os_log("unable to add library record for migration: %{public}@",
                   log: DeviceSyncingLibraryManager.logger,
                   type: .error,
                   String(describing: error))
            completion(false)
          case .conflict, .itemNoLongerExists, .zoneNotFound, .permissionFailure:
            fatalError("should not occur: \(error)")
        }
      } else {
        self.localData.access(onceLoaded: { data in
          let library: InternalMovieLibrary
          if data.libraries[metadata.id] == nil {
            // libraries were loaded from local cache which does not contains the new one yet
            library = self.libraryFactory.makeLibrary(with: metadata)
            data.libraries[metadata.id] = library
            data.libraryRecords[metadata.id] = libraryRecord
            self.localData.persist()
          } else {
            // libraries have not been cached yet -> all fetched, including the new one
            library = data.libraries[metadata.id]!
          }
          library.migrateMovies(from: url) { success in
            let changeSet = ChangeSet<CKRecordID, MovieLibrary>(insertions: [library])
            self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
            completion(success)
          }
        }, whenUnableToLoad: { error in
          os_log("unable to add library: %{public}@",
                 log: DeviceSyncingLibraryManager.logger,
                 type: .error,
                 String(describing: error))
          completion(false)
        })
      }
    }
  }
}
