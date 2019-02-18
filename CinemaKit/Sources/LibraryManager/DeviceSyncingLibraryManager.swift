import CloudKit
import Dispatch
import MobileCoreServices
import os.log
import UIKit

protocol MovieLibraryFactory {
  func makeLibrary(with metadata: MovieLibraryMetadata) -> InternalMovieLibrary
}

protocol CKContainerProvider {
  var container: CKContainer { get }
}

class DeviceSyncingLibraryManager: InternalMovieLibraryManager {
  private static let logger = Logging.createLogger(category: "LibraryManager")

  let delegates = MulticastDelegate<MovieLibraryManagerDelegate>()
  private let containerProvider: CKContainerProvider
  private let fetchManager: FetchManager
  private let syncManager: SyncManager
  private let changesManager: ChangesManager
  private let shareManager: ShareManager
  private let libraryFactory: MovieLibraryFactory
  private var modelController: AnyModelController<MovieLibraryManagerModel, MovieLibraryManagerError>
  private let dataInvalidationFlag: LocalDataInvalidationFlag
  private let errorReporter: ErrorReporter

  init<Controller: ModelController>(containerProvider: CKContainerProvider,
                                    fetchManager: FetchManager,
                                    syncManager: SyncManager,
                                    changesManager: ChangesManager,
                                    shareManager: ShareManager,
                                    libraryFactory: MovieLibraryFactory,
                                    modelController: Controller,
                                    dataInvalidationFlag: LocalDataInvalidationFlag,
                                    errorReporter: ErrorReporter)
      where Controller.ModelType == MovieLibraryManagerModel, Controller.ErrorType == MovieLibraryManagerError {
    self.containerProvider = containerProvider
    self.fetchManager = fetchManager
    self.syncManager = syncManager
    self.changesManager = changesManager
    self.shareManager = shareManager
    self.libraryFactory = libraryFactory
    self.modelController = AnyModelController(modelController)
    self.dataInvalidationFlag = dataInvalidationFlag
    self.errorReporter = errorReporter
  }
}

// MARK: - core functionality

extension DeviceSyncingLibraryManager {
  func fetchLibraries(then completion: @escaping (Result<[MovieLibrary], MovieLibraryManagerError>) -> Void) {
    modelController.access(onceLoaded: { model in
      completion(.success(model.allLibraries))
    }, whenUnableToLoad: { error in
      completion(.failure(error))
    })
  }

  func addLibrary(with metadata: MovieLibraryMetadata,
                  then completion: @escaping (Result<MovieLibrary, MovieLibraryManagerError>) -> Void) {
    modelController.access(onceLoaded: { _ in
      let record = LibraryRecord(from: metadata)
      self.syncManager.sync(record.rawRecord, in: metadata.databaseScope) { error in
        self.addCompletion(metadata, record, error, completion)
      }
    }, whenUnableToLoad: { error in
      completion(.failure(error))
    })
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
        model.add(library, with: record)
        self.modelController.persist()
        let changeSet = ChangeSet<CKRecord.ID, MovieLibrary>(insertions: [library])
        self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
        completion(.success(library))
      }
    }
  }

  func updateLibrary(with metadata: MovieLibraryMetadata,
                     then completion: @escaping (Result<MovieLibrary, MovieLibraryManagerError>) -> Void) {
    modelController.access(onceLoaded: { model in
      guard let record = model.record(for: metadata.id) else {
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
            model.update(LibraryRecord(serverRecord))
            os_log("resolved library metadata record conflict", log: DeviceSyncingLibraryManager.logger, type: .default)
            self.updateLibrary(with: metadata, then: completion)
          case .itemNoLongerExists:
            if let library = model.remove(metadata.id) {
              self.modelController.persist()
              let changeSet = ChangeSet<CKRecord.ID, MovieLibrary>(deletions: [metadata.id: library])
              self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
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
        let library = model.library(for: metadata.id)!
        model.update(record)
        self.modelController.persist()
        let changeSet = ChangeSet<CKRecord.ID, MovieLibrary>(modifications: [library.metadata.id: library])
        self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
        completion(.success(library))
      }
    }
  }

  func removeLibrary(with id: CKRecord.ID,
                     then completion: @escaping (Result<Void, MovieLibraryManagerError>) -> Void) {
    modelController.access(onceLoaded: { model in
      guard let record = model.record(for: id) else {
        completion(.success(()))
        return
      }
      let library = model.library(for: id)!
      self.syncManager.delete(record.rawRecord, in: library.metadata.databaseScope) { error in
        self.removeCompletion(library, error, completion)
      }
    }, whenUnableToLoad: { error in
      completion(.failure(error))
    })
  }

  private func removeCompletion(_ library: InternalMovieLibrary,
                                _ error: CloudKitError?,
                                _ completion: @escaping (Result<Void, MovieLibraryManagerError>) -> Void) {
    modelController.access { model in
      if let error = error {
        switch error {
          case .itemNoLongerExists:
            if model.remove(library.metadata.id) != nil {
              self.modelController.persist()
              let changeSet = ChangeSet<CKRecord.ID, MovieLibrary>(deletions: [library.metadata.id: library])
              self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
            }
            completion(.success(()))
          case .notAuthenticated, .userDeletedZone, .permissionFailure, .nonRecoverableError:
            completion(.failure(error.asMovieLibraryManagerError))
          case .conflict, .zoneNotFound:
            fatalError("should not occur: \(error)")
        }
      } else {
        model.remove(library.metadata.id)
        self.modelController.persist()
        let changeSet = ChangeSet<CKRecord.ID, MovieLibrary>(deletions: [library.metadata.id: library])
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
          case .notAuthenticated, .userDeletedZone, .nonRecoverableError:
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
      var changeSet = ChangeSet<CKRecord.ID, MovieLibrary>()
      self.process(deletedSharedZoneIDs: changes.deletedSharedZoneIDs,
                   changeSet: &changeSet,
                   model: model)
      let sharesToFetchMetadata = self.process(changedRecords: changes.changedRecords,
                                               changeSet: &changeSet,
                                               model: model)
      self.process(deletedRecordIDsAndTypes: changes.deletedRecordIDsAndTypes,
                   changeSet: &changeSet,
                   model: model)
      if !sharesToFetchMetadata.isEmpty {
        self.fetchLibraries(for: sharesToFetchMetadata)
      }
      if changeSet.hasPublicChanges || changeSet.hasInternalChanges {
        self.modelController.persist()
      }
      if changeSet.hasPublicChanges {
        self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
      }
      model.allLibraries.forEach { $0.processChanges(changes) }
    }, whenUnableToLoad: { error in
      self.errorReporter.report(error)
      self.dataInvalidationFlag.set()
    })
  }

  private func fetchLibraries(for shares: [CKShare]) {
    shareManager.fetchShareMetadata(for: shares) { shareMetadatas, error in
      if let error = error {
        switch error {
          case .notAuthenticated, .nonRecoverableError:
            self.errorReporter.report(error)
            self.dataInvalidationFlag.set()
          case .conflict, .userDeletedZone, .permissionFailure, .zoneNotFound, .itemNoLongerExists:
            fatalError("should not occur: \(error)")
        }
      } else if let shareMetadatas = shareMetadatas {
        self.modelController.access { model in
          for shareMetadata in shareMetadatas {
            let libraryRecord = LibraryRecord(shareMetadata.rootRecord!)
            let metadata = MovieLibraryMetadata(from: libraryRecord, shareMetadata.share)
            let library = self.libraryFactory.makeLibrary(with: metadata)
            model.add(library, with: libraryRecord, shareMetadata.share)
            let title: String = shareMetadata.share[CKShare.SystemFieldKey.title]!
            self.delegates.invoke { $0.libraryManager(self, didAcceptSharedLibrary: library, with: title) }
          }
          self.modelController.persist()
        }
      }
    }
  }

  private func process(deletedSharedZoneIDs: [CKRecordZone.ID],
                       changeSet: inout ChangeSet<CKRecord.ID, MovieLibrary>,
                       model: MovieLibraryManagerModel) {
    for zoneID in deletedSharedZoneIDs {
      let deletedLibraries = model.allLibraries.filter { $0.metadata.id.zoneID == zoneID }
      for library in deletedLibraries {
        model.remove(library.metadata.id)
        changeSet.deletions[library.metadata.id] = library
      }
    }
  }

  private func process(changedRecords: [CKRecord],
                       changeSet: inout ChangeSet<CKRecord.ID, MovieLibrary>,
                       model: MovieLibraryManagerModel) -> [CKShare] {
    let libraryRecords = changedRecords.filter { $0.recordType == LibraryRecord.recordType }.map { LibraryRecord($0) }
    var shares = Dictionary(uniqueKeysWithValues: changedRecords.filter { $0.recordType == CKShare.SystemType.share }
                                                                // swiftlint:disable:next force_cast
                                                                .map { ($0.recordID, $0 as! CKShare) })
    for record in libraryRecords {
      if let existingLibrary = model.library(for: record.id) {
        let oldMetadata = existingLibrary.metadata
        if let shareRecordID = record.shareID, let share = shares[shareRecordID] {
          model.setShare(share, with: record)
          shares.removeValue(forKey: shareRecordID)
        } else {
          model.update(record)
        }
        if oldMetadata != existingLibrary.metadata {
          changeSet.modifications[existingLibrary.metadata.id] = existingLibrary
        }
      } else {
        let newLibrary: InternalMovieLibrary
        if let shareRecordID = record.shareID, let share = shares[shareRecordID] {
          let metadata = MovieLibraryMetadata(from: record, share)
          newLibrary = self.libraryFactory.makeLibrary(with: metadata)
          model.add(newLibrary, with: record, share)
          shares.removeValue(forKey: shareRecordID)
        } else {
          let metadata = MovieLibraryMetadata(from: record)
          newLibrary = self.libraryFactory.makeLibrary(with: metadata)
          model.add(newLibrary, with: record)
        }
        changeSet.insertions.append(newLibrary)
      }
    }
    var sharesToFetchMetadata = [CKShare]()
    for (_, share) in shares {
      if let library = model.library(withShareRecordID: share.recordID) {
        model.updateShare(share)
        changeSet.modifications[library.metadata.id] = library
      } else {
        sharesToFetchMetadata.append(share)
      }
    }
    return sharesToFetchMetadata
  }

  private func process(deletedRecordIDsAndTypes: [(CKRecord.ID, CKRecord.RecordType)],
                       changeSet: inout ChangeSet<CKRecord.ID, MovieLibrary>,
                       model: MovieLibraryManagerModel) {
    for (recordID, recordType) in deletedRecordIDsAndTypes where recordType == LibraryRecord.recordType {
      if let library = model.remove(recordID) {
        changeSet.deletions[library.metadata.id] = library
      }
    }
  }
}

// MARK: - sharing

extension DeviceSyncingLibraryManager {
  func prepareCloudSharingController(
      forLibraryWith metadata: MovieLibraryMetadata,
      then completion: @escaping (Result<CloudSharingControllerParameters, MovieLibraryManagerError>) -> Void) {
    modelController.access(onceLoaded: { model in
      guard let library = model.library(for: metadata.id) else {
        completion(.failure(.libraryDoesNotExist))
        return
      }
      if metadata.isShared {
        guard let share = model.share(for: metadata) else {
          preconditionFailure("share should have been already fetched")
        }
        completion(.success(.hasBeenShared(share, self.containerProvider.container, self)))
      } else {
        let preparationHandler = { sharingCompletion in
          self.prepareShare(for: library) { result in
            switch result {
              case let .failure(error):
                sharingCompletion(nil, nil, error)
              case let .success(share):
                sharingCompletion(share, self.containerProvider.container, nil)
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
      let rootRecord = model.record(for: library.metadata.id)!
      let share = CKShare(rootRecord: rootRecord.rawRecord)
      share.publicPermission = .none
      share[CKShare.SystemFieldKey.title] = library.metadata.name
      share[CKShare.SystemFieldKey.shareType] = (kUTTypeDatabase as String)
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
            model.update(libraryRecord)
            share[CKShare.SystemFieldKey.title] = libraryRecord.name
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
        model.setShare(share, with: rootRecord)
        self.modelController.persist()
        let changeSet = ChangeSet<CKRecord.ID, MovieLibrary>(modifications: [library.metadata.id: library])
        self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
        completion(.success(share))
      }
    }
  }

  func acceptCloudKitShare(with shareMetadata: CKShareMetadataProtocol,
                           then completion: @escaping (Result<AcceptShareResult, MovieLibraryManagerError>) -> Void) {
    let title: String = shareMetadata.share[CKShare.SystemFieldKey.title]!
    modelController.access(onceLoaded: { model in
      if shareMetadata.rootRecordID.zoneID == deviceSyncZoneID {
        self.delegates.invoke {
          $0.libraryManager(self, didFailToAcceptSharedLibraryWith: title, reason: .currentUserIsOwner)
        }
        completion(.success(.aborted(.currentUserIsOwner)))
        return
      }
      guard model.library(for: shareMetadata.rootRecordID) == nil else {
        self.delegates.invoke {
          $0.libraryManager(self, didFailToAcceptSharedLibraryWith: title, reason: .alreadyAccepted)
        }
        completion(.success(.aborted(.alreadyAccepted)))
        return
      }
      self.delegates.invoke { $0.libraryManager(self, willAcceptSharedLibraryWith: title) }
      self.shareManager.acceptShare(with: shareMetadata) { error in
        self.acceptShareCompletion(shareMetadata, error) { result in
          if let error = result.error {
            self.errorReporter.report(error)
            self.delegates.invoke {
              $0.libraryManager(self, didFailToAcceptSharedLibraryWith: title, reason: .error)
            }
          }
          completion(result)
        }
      }
    }, whenUnableToLoad: { error in
      self.errorReporter.report(error)
      self.delegates.invoke {
        $0.libraryManager(self, didFailToAcceptSharedLibraryWith: title, reason: .error)
      }
      completion(.failure(error))
    })
  }

  private func acceptShareCompletion(
      _ shareMetadata: CKShareMetadataProtocol,
      _ error: CloudKitError?,
      _ completion: @escaping (Result<AcceptShareResult, MovieLibraryManagerError>) -> Void) {
    if let error = error {
      switch error {
        case .itemNoLongerExists:
          os_log("owner stopped sharing", log: DeviceSyncingLibraryManager.logger, type: .default)
          completion(.failure(.libraryDoesNotExist))
        case .notAuthenticated, .userDeletedZone, .nonRecoverableError:
          completion(.failure(error.asMovieLibraryManagerError))
        case .conflict, .permissionFailure, .zoneNotFound:
          fatalError("should not occur: \(error)")
      }
    } else {
      self.fetchManager.fetchRecord(with: shareMetadata.rootRecordID, in: .shared) { rootRecord, error in
        self.fetchRootRecordCompletion(shareMetadata, rootRecord, error, completion)
      }
    }
  }

  private func fetchRootRecordCompletion(
      _ shareMetadata: CKShareMetadataProtocol,
      _ rootRecord: CKRecord?,
      _ error: CloudKitError?,
      _ completion: @escaping (Result<AcceptShareResult, MovieLibraryManagerError>) -> Void) {
    if let error = error {
      switch error {
        case .zoneNotFound, .itemNoLongerExists:
          os_log("owner stopped sharing record", log: DeviceSyncingLibraryManager.logger, type: .default)
          completion(.failure(.libraryDoesNotExist))
        case .notAuthenticated, .nonRecoverableError:
          completion(.failure(error.asMovieLibraryManagerError))
        case .conflict, .userDeletedZone, .permissionFailure:
          fatalError("should not occur: \(error)")
      }
    } else if let rootRecord = rootRecord {
      modelController.access { model in
        let libraryRecord = LibraryRecord(rootRecord)
        let metadata = MovieLibraryMetadata(from: libraryRecord, shareMetadata.share)
        let library = self.libraryFactory.makeLibrary(with: metadata)
        model.add(library, with: libraryRecord, shareMetadata.share)
        self.modelController.persist()
        let title: String = shareMetadata.share[CKShare.SystemFieldKey.title]!
        self.delegates.invoke { $0.libraryManager(self, didAcceptSharedLibrary: library, with: title) }
        completion(.success(.accepted))
      }
    }
  }
}

extension DeviceSyncingLibraryManager: CloudSharingControllerCallback {
  func didStopSharingLibrary(with metadata: MovieLibraryMetadata) {
    modelController.access { model in
      guard let library = model.library(for: metadata.id) else {
        preconditionFailure("library has been removed while presenting sharing controller")
      }
      if library.metadata.isCurrentUserOwner {
        self.fetchManager.fetchRecord(with: library.metadata.id, in: .private) { rawRecord, error in
          if let error = error {
            switch error {
              case .nonRecoverableError:
                self.dataInvalidationFlag.set()
              case .notAuthenticated, .userDeletedZone, .itemNoLongerExists, .zoneNotFound, .conflict,
                   .permissionFailure:
                fatalError("should not occur: \(error)")
            }
          } else if let rawRecord = rawRecord {
            self.modelController.access { model in
              model.setShare(nil, with: LibraryRecord(rawRecord))
              self.modelController.persist()
              let changeSet = ChangeSet<CKRecord.ID, MovieLibrary>(modifications: [library.metadata.id: library])
              self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
            }
          }
        }
      } else {
        model.remove(library.metadata.id)
        self.modelController.persist()
        let changeSet = ChangeSet<CKRecord.ID, MovieLibrary>(deletions: [library.metadata.id: library])
        self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
      }
    }
  }
}

// MARK: - migration

extension DeviceSyncingLibraryManager {
  func migrateLegacyLibrary(with name: String, at url: URL, then completion: @escaping (Bool) -> Void) {
    let metadata = MovieLibraryMetadata(name: name)
    let libraryRecord = LibraryRecord(from: metadata)
    self.syncManager.sync(libraryRecord.rawRecord, in: .private) { error in
      if let error = error {
        switch error {
          case .notAuthenticated, .userDeletedZone, .nonRecoverableError:
            completion(false)
          case .conflict, .itemNoLongerExists, .zoneNotFound, .permissionFailure:
            fatalError("should not occur: \(error)")
        }
      } else {
        self.modelController.access(onceLoaded: { model in
          let library: InternalMovieLibrary
          if let fetchedLibrary = model.library(for: metadata.id) {
            // libraries have not been cached yet -> all fetched, including the new one
            library = fetchedLibrary
          } else {
            // libraries were loaded from local cache which does not contains the new one yet
            library = self.libraryFactory.makeLibrary(with: metadata)
            model.add(library, with: libraryRecord)
            self.modelController.persist()
          }
          library.migrateMovies(from: url) { success in
            let changeSet = ChangeSet<CKRecord.ID, MovieLibrary>(insertions: [library])
            self.delegates.invoke { $0.libraryManager(self, didUpdateLibraries: changeSet) }
            completion(success)
          }
        }, whenUnableToLoad: { error in
          self.errorReporter.report(error)
          completion(false)
        })
      }
    }
  }
}
