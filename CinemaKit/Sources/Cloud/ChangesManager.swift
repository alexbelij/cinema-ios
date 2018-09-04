import CloudKit
import os.log

struct FetchedChanges {
  let changedRecords: [CKRecord]
  let deletedRecordIDsAndTypes: [(CKRecordID, String)]

  var hasChanges: Bool {
    return !(changedRecords.isEmpty && deletedRecordIDsAndTypes.isEmpty)
  }
}

protocol ChangesManager {
  func fetchChanges(then completion: @escaping (FetchedChanges?, CloudKitError?) -> Void)
}

class DefaultChangesManager: ChangesManager {
  private static let logger = Logging.createLogger(category: "ChangesManager")
  private let queueFactory: DatabaseOperationQueueFactory
  private let serverChangeTokenStore: ServerChangeTokenStore
  private let cacheInvalidationFlag: LocalCloudKitCacheInvalidationFlag

  init(queueFactory: DatabaseOperationQueueFactory,
       serverChangeTokenStore: ServerChangeTokenStore = FileBasedServerChangeTokenStore(),
       cacheInvalidationFlag: LocalCloudKitCacheInvalidationFlag = LocalCloudKitCacheInvalidationFlag()) {
    self.queueFactory = queueFactory
    self.serverChangeTokenStore = serverChangeTokenStore
    self.cacheInvalidationFlag = cacheInvalidationFlag
  }

  func fetchChanges(then completion: @escaping (FetchedChanges?, CloudKitError?) -> Void) {
    self.fetchChangesInZones(withIDs: [deviceSyncZoneID],
                             using: self.queueFactory.queue(withScope: .private)) { changes, error in
      if let error = error {
        completion(nil, error)
      } else if let changes = changes {
        completion(FetchedChanges(changedRecords: changes.0, deletedRecordIDsAndTypes: changes.1), nil)
      }
    }
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
          self.cacheInvalidationFlag.set()
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
        if self.cacheInvalidationFlag.isSet {
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
