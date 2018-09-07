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
  private let fetchManager: FetchManager
  private let syncManager: SyncManager
  private let changesManager: ChangesManager
  private let shareManager: ShareManager
  private let libraryFactory: MovieLibraryFactory
  private var modelController: AnyModelController<MovieLibraryManagerModel, MovieLibraryManagerError>
  private let dataInvalidationFlag: LocalDataInvalidationFlag

  init<Controller: ModelController>(container: CKContainer,
                                    fetchManager: FetchManager,
                                    syncManager: SyncManager,
                                    changesManager: ChangesManager,
                                    shareManager: ShareManager,
                                    libraryFactory: MovieLibraryFactory,
                                    modelController: Controller,
                                    dataInvalidationFlag: LocalDataInvalidationFlag = LocalDataInvalidationFlag())
      where Controller.ModelType == MovieLibraryManagerModel, Controller.ErrorType == MovieLibraryManagerError {
    self.container = container
    self.fetchManager = fetchManager
    self.syncManager = syncManager
    self.changesManager = changesManager
    self.shareManager = shareManager
    self.libraryFactory = libraryFactory
    self.modelController = AnyModelController(modelController)
    self.dataInvalidationFlag = dataInvalidationFlag
  }
}

// MARK: - core functionality

extension DeviceSyncingLibraryManager {
  func fetchLibraries(then completion: @escaping (Result<[MovieLibrary], MovieLibraryManagerError>) -> Void) {
    modelController.access(onceLoaded: { model in
      completion(.success(Array(model.libraries.values)))
    }, whenUnableToLoad: { error in
      completion(.failure(error))
    })
  }

  func addLibrary(with metadata: MovieLibraryMetadata,
                  then completion: @escaping (Result<MovieLibrary, MovieLibraryManagerError>) -> Void) {
    let record = LibraryRecord(from: metadata)
    syncManager.sync(record.rawRecord, in: metadata.databaseScope) { error in
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
      modelController.access { model in
        let library = self.libraryFactory.makeLibrary(with: metadata)
        model.libraries[metadata.id] = library
        model.libraryRecords[metadata.id] = record
        self.modelController.persist()
        let changeSet = ChangeSet<CKRecordID, MovieLibrary>(insertions: [library])
        self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
        completion(.success(library))
      }
    }
  }

  func updateLibrary(with metadata: MovieLibraryMetadata,
                     then completion: @escaping (Result<MovieLibrary, MovieLibraryManagerError>) -> Void) {
    modelController.access(onceLoaded: { model in
      guard let record = model.libraryRecords[metadata.id] else {
        completion(.failure(.libraryDoesNotExist))
        return
      }
      metadata.setCustomFields(in: record)
      self.syncManager.sync(record.rawRecord, in: metadata.databaseScope) { error in
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
    modelController.access { model in
      if let error = error {
        switch error {
          case let .conflict(serverRecord):
            LibraryRecord.copyCustomFields(from: record.rawRecord, to: serverRecord)
            model.libraryRecords[metadata.id] = LibraryRecord(serverRecord)
            os_log("resolved library metadata record conflict", log: DeviceSyncingLibraryManager.logger, type: .default)
            self.updateLibrary(with: metadata, then: completion)
          case .itemNoLongerExists:
            if let removedLibrary = model.libraries.removeValue(forKey: metadata.id) {
              model.libraryRecords.removeValue(forKey: metadata.id)
              removedLibrary.cleanupForRemoval()
              let changeSet = ChangeSet<CKRecordID, MovieLibrary>(deletions: [metadata.id: removedLibrary])
              self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
            } else {
              // library has already been removed via changes
              assert(model.libraryRecords[metadata.id] == nil)
            }
            completion(.failure(.libraryDoesNotExist))
          case .userDeletedZone:
            completion(.failure(error.asMovieLibraryManagerError))
          case .notAuthenticated, .permissionFailure, .nonRecoverableError:
            // need to reset record (changed keys)
            self.modelController.requestReload()
            completion(.failure(error.asMovieLibraryManagerError))
          case .zoneNotFound:
            fatalError("should not occur: \(error)")
        }
      } else {
        let library = model.libraries[metadata.id]!
        library.metadata = metadata
        self.modelController.persist()
        let changeSet = ChangeSet<CKRecordID, MovieLibrary>(modifications: [library.metadata.id: library])
        self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
        completion(.success(library))
      }
    }
  }

  func removeLibrary(with id: CKRecordID, then completion: @escaping (Result<Void, MovieLibraryManagerError>) -> Void) {
    modelController.access(onceLoaded: { model in
      guard let record = model.libraryRecords[id] else {
        completion(.success(()))
        return
      }
      let library = model.libraries[id]!
      self.syncManager.delete(record.rawRecord, in: model.libraries[id]!.metadata.databaseScope) { error in
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
      modelController.access { model in
        model.libraries.removeValue(forKey: library.metadata.id)
        model.libraryRecords.removeValue(forKey: library.metadata.id)
        library.cleanupForRemoval()
        self.modelController.persist()
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
    modelController.access(onceLoaded: { model in
      var changeSet = ChangeSet<CKRecordID, MovieLibrary>()
      self.process(deletedSharedZoneIDs: changes.deletedSharedZoneIDs,
                   changeSet: &changeSet,
                   model: model)
      self.process(changedRecords: changes.changedRecords, changeSet: &changeSet, model: model)
      self.process(deletedRecordIDsAndTypes: changes.deletedRecordIDsAndTypes,
                   changeSet: &changeSet,
                   model: model)
      if changeSet.hasPublicChanges || changeSet.hasInternalChanges {
        self.modelController.persist()
      }
      if changeSet.hasPublicChanges {
        self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
      }
      for id in Set(model.libraries.keys) {
        model.libraries[id]!.processChanges(changes)
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
               model: MovieLibraryManagerModel) {
    for zoneID in deletedSharedZoneIDs {
      for removedLibrary in model.libraries.values.filter({ $0.metadata.id.zoneID == zoneID }) {
        let removedLibrary = model.libraries.removeValue(forKey: removedLibrary.metadata.id)!
        let record = model.libraryRecords.removeValue(forKey: removedLibrary.metadata.id)!
        model.shareRecords.removeValue(forKey: record.shareID!)
        removedLibrary.cleanupForRemoval()
        changeSet.deletions[removedLibrary.metadata.id] = removedLibrary
      }
    }
  }

  private func process(changedRecords: [CKRecord],
                       changeSet: inout ChangeSet<CKRecordID, MovieLibrary>,
                       model: MovieLibraryManagerModel) {
    var updatedMetadata = [CKRecordID: MovieLibraryMetadata]()
    for rawRecord in changedRecords where rawRecord.recordType == LibraryRecord.recordType {
      let record = LibraryRecord(rawRecord)
      model.libraryRecords[record.id] = record
      if let existingLibrary = model.libraries[record.id] {
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
        model.libraries[record.id] = newLibrary
        changeSet.insertions.append(newLibrary)
      }
    }
    for rawRecord in changedRecords where rawRecord.recordType == "cloudkit.share" {
      // swiftlint:disable:next force_cast
      let share = rawRecord as! CKShare
      model.shareRecords[share.recordID] = share
      if let (libraryID, _) =
      model.libraryRecords.first(where: { _, record in record.shareID == share.recordID }) {
        let library = model.libraries[libraryID]!
        var newMetadata = updatedMetadata[library.metadata.id] ?? library.metadata
        newMetadata.currentUserCanModify = share.currentUserParticipant?.permission == .readWrite
        updatedMetadata[newMetadata.id] = newMetadata
        changeSet.modifications[newMetadata.id] = library
      }
    }
    for (id, newMetadata) in updatedMetadata {
      model.libraries[id]!.metadata = newMetadata
    }
  }

  private func process(deletedRecordIDsAndTypes: [(CKRecordID, String)],
                       changeSet: inout ChangeSet<CKRecordID, MovieLibrary>,
                       model: MovieLibraryManagerModel) {
    for (recordID, recordType) in deletedRecordIDsAndTypes
        where recordType == LibraryRecord.recordType && model.libraries[recordID] != nil {
      let removedLibrary = model.libraries.removeValue(forKey: recordID)!
      model.libraryRecords.removeValue(forKey: recordID)
      removedLibrary.cleanupForRemoval()
      changeSet.deletions[removedLibrary.metadata.id] = removedLibrary
    }
    for (recordID, recordType) in deletedRecordIDsAndTypes where recordType == "cloudkit.share" {
      model.shareRecords.removeValue(forKey: recordID)
    }
  }
}

// MARK: - sharing

extension DeviceSyncingLibraryManager {
  func prepareCloudSharingController(
      forLibraryWith metadata: MovieLibraryMetadata,
      then completion: @escaping (Result<CloudSharingControllerParameters, MovieLibraryManagerError>) -> Void) {
    modelController.access(onceLoaded: { model in
      guard let library = model.libraries[metadata.id] else {
        completion(.failure(.libraryDoesNotExist))
        return
      }
      if metadata.isShared {
        guard let share = model.shareRecords[metadata.shareRecordID!] else {
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
    modelController.access { model in
      let rootRecord = model.libraryRecords[library.metadata.id]!
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
    modelController.access { model in
      if let error = error {
        switch error {
          case let .conflict(serverRecord):
            let libraryRecord = LibraryRecord(serverRecord)
            model.libraryRecords[library.metadata.id] = libraryRecord
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
        model.shareRecords[share.recordID] = share
        var newMetadata = MovieLibraryMetadata(from: model.libraryRecords[library.metadata.id]!,
                                               currentUserCanModify: true)
        newMetadata.shareRecordID = share.recordID
        library.metadata = newMetadata
        self.modelController.persist()
        let changeSet = ChangeSet<CKRecordID, MovieLibrary>(modifications: [library.metadata.id: library])
        self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
        completion(.success(share))
      }
    }
  }

  func acceptCloudKitShare(with shareMetadata: CKShareMetadata) {
    modelController.access(onceLoaded: { model in
      guard model.libraries[shareMetadata.rootRecordID] == nil else {
        os_log("already accepted share", log: DeviceSyncingLibraryManager.logger, type: .default)
        return
      }
      // swiftlint:disable:next force_cast
      let title = shareMetadata.share[CKShareTitleKey] as! String
      var didContinue = false
      let continuation = {
        if didContinue { return }
        didContinue = true
        self.shareManager.acceptShare(with: shareMetadata) { error in
          self.acceptShareCompletion(shareMetadata, error)
        }
      }
      self.delegates.invoke { $0.libraryManager(self, willAcceptSharedLibraryWith: title, continuation: continuation) }
    }, whenUnableToLoad: { error in
      os_log("unable to accept share, because libraries could not be loaded: %{public}@",
             log: DeviceSyncingLibraryManager.logger,
             type: .error,
             String(describing: error))
    })
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
      self.fetchManager.fetchRecord(with: shareMetadata.rootRecordID, in: .shared) { rootRecord, error in
        self.fetchRootRecordCompletion(shareMetadata, rootRecord, error)
      }
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
      modelController.access { model in
        let libraryRecord = LibraryRecord(rootRecord)
        let currentUserCanModify = shareMetadata.share.currentUserParticipant?.permission == .readWrite
        let metadata = MovieLibraryMetadata(from: libraryRecord, currentUserCanModify: currentUserCanModify)
        let library = self.libraryFactory.makeLibrary(with: metadata)
        model.libraries[libraryRecord.id] = library
        model.libraryRecords[libraryRecord.id] = libraryRecord
        model.shareRecords[shareMetadata.share.recordID] = shareMetadata.share
        self.modelController.persist()
        // swiftlint:disable:next force_cast
        let title = shareMetadata.share[CKShareTitleKey] as! String
        self.delegates.invoke { $0.libraryManager(self, didAcceptSharedLibrary: library, with: title) }
      }
    }
  }
}

extension DeviceSyncingLibraryManager: CloudSharingControllerCallback {
  func didStopSharingLibrary(with metadata: MovieLibraryMetadata) {
    modelController.access { model in
      guard let library = model.libraries[metadata.id] else {
        preconditionFailure("library has been removed while presenting sharing controller")
      }
      if library.metadata.isCurrentUserOwner {
        model.shareRecords.removeValue(forKey: library.metadata.shareRecordID!)
        library.metadata.shareRecordID = nil
        self.fetchManager.fetchRecord(with: library.metadata.id, in: .private) { rawRecord, error in
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
            self.modelController.access { model in
              let record = LibraryRecord(rawRecord)
              model.libraryRecords[record.id] = record
              library.metadata = MovieLibraryMetadata(from: record, currentUserCanModify: true)
              self.modelController.persist()
              let changeSet = ChangeSet<CKRecordID, MovieLibrary>(modifications: [library.metadata.id: library])
              self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
            }
          }
        }
      } else {
        model.libraries.removeValue(forKey: library.metadata.id)
        model.libraryRecords.removeValue(forKey: library.metadata.id)
        model.shareRecords.removeValue(forKey: library.metadata.shareRecordID!)
        library.cleanupForRemoval()
        self.modelController.persist()
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
    self.syncManager.sync(libraryRecord.rawRecord, in: .private) { error in
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
        self.modelController.access(onceLoaded: { model in
          let library: InternalMovieLibrary
          if model.libraries[metadata.id] == nil {
            // libraries were loaded from local cache which does not contains the new one yet
            library = self.libraryFactory.makeLibrary(with: metadata)
            model.libraries[metadata.id] = library
            model.libraryRecords[metadata.id] = libraryRecord
            self.modelController.persist()
          } else {
            // libraries have not been cached yet -> all fetched, including the new one
            library = model.libraries[metadata.id]!
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
