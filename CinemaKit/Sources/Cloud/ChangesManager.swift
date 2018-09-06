import CloudKit
import os.log

struct FetchedChanges {
  let deletedSharedZoneIDs: [CKRecordZoneID]
  let changedRecords: [CKRecord]
  let deletedRecordIDsAndTypes: [(CKRecordID, String)]

  var hasChanges: Bool {
    return !(deletedSharedZoneIDs.isEmpty && changedRecords.isEmpty && deletedRecordIDsAndTypes.isEmpty)
  }
}

protocol ChangesManager {
  func fetchChanges(then completion: @escaping (FetchedChanges?, CloudKitError?) -> Void)
}

class DefaultChangesManager: ChangesManager {
  private static let logger = Logging.createLogger(category: "ChangesManager")
  private let privateDatabaseOperationQueue: DatabaseOperationQueue
  private let sharedDatabaseOperationQueue: DatabaseOperationQueue
  private let serverChangeTokenStore: ServerChangeTokenStore
  private let dataInvalidationFlag: LocalDataInvalidationFlag

  init(privateDatabaseOperationQueue: DatabaseOperationQueue,
       sharedDatabaseOperationQueue: DatabaseOperationQueue,
       serverChangeTokenStore: ServerChangeTokenStore = FileBasedServerChangeTokenStore(),
       dataInvalidationFlag: LocalDataInvalidationFlag = LocalDataInvalidationFlag()) {
    self.privateDatabaseOperationQueue = privateDatabaseOperationQueue
    self.sharedDatabaseOperationQueue = sharedDatabaseOperationQueue
    self.serverChangeTokenStore = serverChangeTokenStore
    self.dataInvalidationFlag = dataInvalidationFlag
  }

  func fetchChanges(then completion: @escaping (FetchedChanges?, CloudKitError?) -> Void) {
    fetchChangesInSharedDatabase(retryCount: defaultRetryCount) { changes, error in
      if let error = error {
        completion(nil, error)
      } else if let (changedZoneIDs, deletedZoneIDs) = changes {
        var changedRecords = [CKRecord]()
        var deletedRecordIDsAndTypes = [(CKRecordID, String)]()
        var errors = [CloudKitError]()
        let group = DispatchGroup()
        if !changedZoneIDs.isEmpty {
          group.enter()
          self.fetchChangesInZones(withIDs: changedZoneIDs,
                                   using: self.sharedDatabaseOperationQueue) { changes, error in
            if let error = error {
              errors.append(error)
            } else if let changes = changes {
              changedRecords.append(contentsOf: changes.0)
              deletedRecordIDsAndTypes.append(contentsOf: changes.1)
            }
            group.leave()
          }
        }
        group.enter()
        self.fetchChangesInZones(withIDs: [deviceSyncZoneID],
                                 using: self.privateDatabaseOperationQueue) { changes, error in
          if let error = error {
            errors.append(error)
          } else if let changes = changes {
            changedRecords.append(contentsOf: changes.0)
            deletedRecordIDsAndTypes.append(contentsOf: changes.1)
          }
          group.leave()
        }
        group.notify(queue: DispatchQueue.global()) {
          if errors.isEmpty {
            let changes = FetchedChanges(deletedSharedZoneIDs: deletedZoneIDs,
                                         changedRecords: changedRecords,
                                         deletedRecordIDsAndTypes: deletedRecordIDsAndTypes)
            completion(changes, nil)
          } else {
            completion(nil, errors.first)
          }
        }
      }
    }
  }

  private func fetchChangesInSharedDatabase(
      retryCount: Int,
      then completion: @escaping (([CKRecordZoneID], [CKRecordZoneID])?, CloudKitError?) -> Void) {
    os_log("creating fetch database changes operation for shared database",
           log: DefaultChangesManager.logger,
           type: .default)
    let previousChangeToken = serverChangeTokenStore.get(for: .shared)
    let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: previousChangeToken)

    // collect changes and deletions
    var changedZoneIDs = [CKRecordZoneID]()
    operation.recordZoneWithIDChangedBlock = { zoneID in changedZoneIDs.append(zoneID) }
    var deletedZoneIDs = [CKRecordZoneID]()
    operation.recordZoneWithIDWasDeletedBlock = { zoneID in deletedZoneIDs.append(zoneID) }

    // handle result
    operation.fetchDatabaseChangesCompletionBlock = { newChangeToken, _, error in
      if let error = error {
        guard let ckerror = error as? CKError else {
          os_log("<fetchChangesForDatabase> unhandled error: %{public}@",
                 log: DefaultChangesManager.logger,
                 type: .error,
                 String(describing: error))
          completion(nil, .nonRecoverableError)
          return
        }
        if ckerror.code == CKError.Code.changeTokenExpired {
          self.dataInvalidationFlag.set()
        } else if ckerror.code == CKError.Code.notAuthenticated {
          completion(nil, .notAuthenticated)
        } else if ckerror.code == CKError.Code.networkFailure
                  || ckerror.code == CKError.Code.networkUnavailable
                  || ckerror.code == CKError.Code.requestRateLimited
                  || ckerror.code == CKError.Code.serviceUnavailable
                  || ckerror.code == CKError.Code.zoneBusy {
          completion(nil, .nonRecoverableError)
        } else {
          os_log("<fetchChangesForDatabase> unhandled CKError: %{public}@",
                 log: DefaultChangesManager.logger,
                 type: .error,
                 String(describing: ckerror))
          completion(nil, .nonRecoverableError)
        }
      } else {
        if let newChangeToken = newChangeToken, newChangeToken != previousChangeToken {
          self.serverChangeTokenStore.set(newChangeToken, for: .shared)
        }
        os_log("fetched %d changed and %d deleted zones in shared database",
               log: DefaultChangesManager.logger,
               type: .debug,
               changedZoneIDs.count,
               deletedZoneIDs.count)
        completion((changedZoneIDs, deletedZoneIDs), nil)
      }
    }
    sharedDatabaseOperationQueue.add(operation)
  }

  private func fetchChangesInZones(
      withIDs zoneIDs: [CKRecordZoneID],
      using queue: DatabaseOperationQueue,
      then completion: @escaping (([CKRecord], [(CKRecordID, String)])?, CloudKitError?) -> Void) {
    os_log("creating fetch record zone changes operation for [%@]",
           log: DefaultChangesManager.logger,
           type: .default,
           zoneIDs.map { $0.logDescription }.joined(separator: ", "))
    let options = Dictionary(uniqueKeysWithValues: zoneIDs.map { zoneID in
      let fetchOptions = CKFetchRecordZoneChangesOptions()
      fetchOptions.previousServerChangeToken = serverChangeTokenStore.get(for: zoneID)
      return (zoneID, fetchOptions)
    }) as [CKRecordZoneID: CKFetchRecordZoneChangesOptions]
    let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIDs, optionsByRecordZoneID: options)

    // collect changes and deletions
    var changedRecords = [CKRecord]()
    operation.recordChangedBlock = { changedRecords.append($0) }
    var deletedRecordIDsAndTypes = [(CKRecordID, String)]()
    operation.recordWithIDWasDeletedBlock = { deletedRecordIDsAndTypes.append(($0, $1)) }

    // handle result
    var newChangeTokens = [CKRecordZoneID: CKServerChangeToken]()
    operation.recordZoneFetchCompletionBlock = { zoneID, newChangeToken, _, _, error in
      if let error = error {
        guard let ckerror = error as? CKError else { return }
        if ckerror.code == CKError.Code.changeTokenExpired
           || ckerror.code == CKError.Code.userDeletedZone {
          self.dataInvalidationFlag.set()
        }
      } else {
        if let newChangeToken = newChangeToken, newChangeToken != options[zoneID]!.previousServerChangeToken {
          newChangeTokens[zoneID] = newChangeToken
        }
        os_log("fetched %d changed and %d deleted records for %@",
               log: DefaultChangesManager.logger,
               type: .debug,
               changedRecords.count,
               deletedRecordIDsAndTypes.count,
               zoneID.logDescription)
      }
    }
    operation.fetchRecordZoneChangesCompletionBlock = { error in
      if let error = error {
        if self.dataInvalidationFlag.isSet {
          completion(nil, .userDeletedZone)
          return
        }
        guard let ckerror = error as? CKError else {
          os_log("<fetchChangesInZones> unhandled error: %{public}@",
                 log: DefaultChangesManager.logger,
                 type: .error,
                 String(describing: error))
          completion(nil, .nonRecoverableError)
          return
        }
        if ckerror.code == CKError.Code.notAuthenticated {
          completion(nil, .notAuthenticated)
        }
        if ckerror.code == CKError.Code.networkFailure
           || ckerror.code == CKError.Code.networkUnavailable
           || ckerror.code == CKError.Code.requestRateLimited
           || ckerror.code == CKError.Code.serviceUnavailable
           || ckerror.code == CKError.Code.zoneBusy {
          completion(nil, .nonRecoverableError)
        } else {
          os_log("<fetchChangesInZones> unhandled CKError: %{public}@",
                 log: DefaultChangesManager.logger,
                 type: .error,
                 String(describing: ckerror))
          completion(nil, .nonRecoverableError)
        }
      } else {
        for (zoneID, newChangeToken) in newChangeTokens {
          self.serverChangeTokenStore.set(newChangeToken, for: zoneID)
        }
        completion((changedRecords, deletedRecordIDsAndTypes), nil)
      }
    }
    queue.add(operation)
  }
}

extension CKDatabaseScope: CustomStringConvertible {
  public var description: String {
    switch self {
      case .public: return "public"
      case .private: return "private"
      case .shared: return "shared"
    }
  }
}

extension CKRecordZoneID {
  var logDescription: String {
    return "<\(ownerName),\(zoneName)>"
  }
}
