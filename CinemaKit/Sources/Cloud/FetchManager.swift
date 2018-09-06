import CloudKit
import os.log

protocol FetchManager {
  func fetchZones(in scope: CKDatabaseScope,
                  then completion: @escaping ([CKRecordZoneID: CKRecordZone]?, CloudKitError?) -> Void)
  func fetch<CustomRecordType>(_ type: CustomRecordType.Type,
                               matching predicate: NSPredicate,
                               inZoneWithID zoneID: CKRecordZoneID,
                               in scope: CKDatabaseScope,
                               then completion: @escaping ([CustomRecordType]?, CloudKitError?) -> Void)
      where CustomRecordType: RecordType
  func fetchRecord(with recordID: CKRecordID,
                   in scope: CKDatabaseScope,
                   then completion: @escaping (CKRecord?, CloudKitError?) -> Void)
}

extension FetchManager {
  func fetch<CustomRecordType>(_ type: CustomRecordType.Type,
                               inZoneWithID zoneID: CKRecordZoneID,
                               in scope: CKDatabaseScope,
                               then completion: @escaping ([CustomRecordType]?, CloudKitError?) -> Void)
      where CustomRecordType: RecordType {
    fetch(type,
          matching: NSPredicate(value: true),
          inZoneWithID: zoneID,
          in: scope,
          then: completion)
  }
}

class DefaultFetchManager: FetchManager {
  private static let logger = Logging.createLogger(category: "FetchManager")

  private let privateDatabaseOperationQueue: DatabaseOperationQueue
  private let sharedDatabaseOperationQueue: DatabaseOperationQueue
  private let dataInvalidationFlag: LocalDataInvalidationFlag

  init(privateDatabaseOperationQueue: DatabaseOperationQueue,
       sharedDatabaseOperationQueue: DatabaseOperationQueue,
       dataInvalidationFlag: LocalDataInvalidationFlag = LocalDataInvalidationFlag()) {
    self.privateDatabaseOperationQueue = privateDatabaseOperationQueue
    self.sharedDatabaseOperationQueue = sharedDatabaseOperationQueue
    self.dataInvalidationFlag = dataInvalidationFlag
  }

  private func databaseOperationQueue(for scope: CKDatabaseScope) -> DatabaseOperationQueue {
    switch scope {
      case .private:
        return privateDatabaseOperationQueue
      case .shared:
        return sharedDatabaseOperationQueue
      case .public:
        fatalError("can not fetch from public database")
    }
  }

  func fetchZones(in scope: CKDatabaseScope,
                  then completion: @escaping ([CKRecordZoneID: CKRecordZone]?, CloudKitError?) -> Void) {
    self.fetchZones(in: scope, retryCount: defaultRetryCount, then: completion)
  }

  private func fetchZones(in scope: CKDatabaseScope,
                          retryCount: Int,
                          then completion: @escaping ([CKRecordZoneID: CKRecordZone]?, CloudKitError?) -> Void) {
    let operation = CKFetchRecordZonesOperation.fetchAllRecordZonesOperation()
    operation.fetchRecordZonesCompletionBlock = { zones, error in
      if let error = error {
        guard let ckerror = error as? CKError else {
          os_log("<fetchZones> unhandled error: %{public}@",
                 log: DefaultFetchManager.logger,
                 type: .error,
                 String(describing: error))
          completion(nil, .nonRecoverableError)
          return
        }
        if retryCount > 1, let retryAfter = ckerror.retryAfterSeconds?.rounded(.up) {
          os_log("retry fetchZones after %.1f seconds", log: DefaultFetchManager.logger, type: .default, retryAfter)
          DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(Int(retryAfter))) {
            self.fetchZones(in: scope, retryCount: retryCount - 1, then: completion)
          }
        } else if ckerror.code == CKError.Code.notAuthenticated {
          completion(nil, .notAuthenticated)
        } else if ckerror.code == CKError.Code.networkFailure
                  || ckerror.code == CKError.Code.networkUnavailable
                  || ckerror.code == CKError.Code.requestRateLimited
                  || ckerror.code == CKError.Code.serviceUnavailable
                  || ckerror.code == CKError.Code.zoneBusy {
          completion(nil, .nonRecoverableError)
        } else {
          os_log("<fetchZones> unhandled CKError: %{public}@",
                 log: DefaultFetchManager.logger,
                 type: .error,
                 String(describing: ckerror))
          completion(nil, .nonRecoverableError)
        }
      } else if let zones = zones {
        os_log("fetched %d zones",
               log: DefaultFetchManager.logger,
               type: .debug,
               zones.count)
        completion(zones, nil)
      }
    }
    databaseOperationQueue(for: scope).add(operation)
  }

  func fetch<CustomRecordType>(_ type: CustomRecordType.Type,
                               matching predicate: NSPredicate = NSPredicate(value: true),
                               inZoneWithID zoneID: CKRecordZoneID,
                               in scope: CKDatabaseScope,
                               then completion: @escaping ([CustomRecordType]?, CloudKitError?) -> Void)
      where CustomRecordType: RecordType {
    os_log("creating query operation for %{public}@",
           log: DefaultFetchManager.logger,
           type: .default,
           String(describing: type))
    let query = CKQuery(recordType: type.recordType, predicate: predicate)
    fetch(with: CKQueryOperation(query: query),
          inZoneWithID: zoneID,
          into: [],
          in: scope,
          retryCount: defaultRetryCount) { records, error in
      if let error = error {
        completion(nil, error)
      } else if let records = records {
        completion(records.map(CustomRecordType.init), nil)
      }
    }
  }

  private func fetch(with operation: CKQueryOperation,
                     inZoneWithID zoneID: CKRecordZoneID,
                     into accumulator: [CKRecord],
                     in scope: CKDatabaseScope,
                     retryCount: Int,
                     then completion: @escaping ([CKRecord]?, CloudKitError?) -> Void) {
    operation.zoneID = zoneID
    var fetchedRecords = [CKRecord]()
    operation.recordFetchedBlock = { record in fetchedRecords.append(record) }
    operation.queryCompletionBlock = { cursor, error in
      if let error = error {
        guard let ckerror = error as? CKError else {
          os_log("<fetchAll> unhandled error: %{public}@",
                 log: DefaultFetchManager.logger,
                 type: .error,
                 String(describing: error))
          completion(nil, .nonRecoverableError)
          return
        }
        if retryCount > 1, let retryAfter = ckerror.retryAfterSeconds?.rounded(.up) {
          os_log("retry fetch after %.1f seconds", log: DefaultFetchManager.logger, type: .default, retryAfter)
          DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(Int(retryAfter))) {
            self.fetch(with: operation,
                       inZoneWithID: zoneID,
                       into: accumulator,
                       in: scope,
                       retryCount: retryCount - 1,
                       then: completion)
          }
        } else if ckerror.code == CKError.Code.notAuthenticated {
          completion(nil, .notAuthenticated)
        } else if ckerror.code == CKError.Code.zoneNotFound {
          completion(nil, .zoneNotFound)
        } else if ckerror.code == CKError.Code.userDeletedZone {
          self.dataInvalidationFlag.set()
          completion(nil, .userDeletedZone)
        } else if ckerror.code == CKError.Code.networkFailure
                  || ckerror.code == CKError.Code.networkUnavailable
                  || ckerror.code == CKError.Code.requestRateLimited
                  || ckerror.code == CKError.Code.serviceUnavailable
                  || ckerror.code == CKError.Code.zoneBusy {
          completion(nil, .nonRecoverableError)
        } else {
          os_log("<fetchAll> unhandled CKError: %{public}@",
                 log: DefaultFetchManager.logger,
                 type: .error,
                 String(describing: ckerror))
          completion(nil, .nonRecoverableError)
        }
      } else if let cursor = cursor {
        os_log("fetched %d records but still some left",
               log: DefaultFetchManager.logger,
               type: .debug,
               fetchedRecords.count)
        let nextOperation = CKQueryOperation(cursor: cursor)
        nextOperation.zoneID = zoneID
        self.fetch(with: nextOperation,
                   inZoneWithID: zoneID,
                   into: accumulator + fetchedRecords,
                   in: scope,
                   retryCount: defaultRetryCount,
                   then: completion)
      } else {
        os_log("fetched %d records",
               log: DefaultFetchManager.logger,
               type: .debug,
               fetchedRecords.count)
        completion(accumulator + fetchedRecords, nil)
      }
    }
    databaseOperationQueue(for: scope).add(operation)
  }

  func fetchRecord(with recordID: CKRecordID,
                   in scope: CKDatabaseScope,
                   then completion: @escaping (CKRecord?, CloudKitError?) -> Void) {
    fetchRecord(with: recordID, in: scope, retryCount: defaultRetryCount, then: completion)
  }

  private func fetchRecord(with recordID: CKRecordID,
                           in scope: CKDatabaseScope,
                           retryCount: Int,
                           then completion: @escaping (CKRecord?, CloudKitError?) -> Void) {
    let operation = CKFetchRecordsOperation(recordIDs: [recordID])
    operation.fetchRecordsCompletionBlock = { records, error in
      if let error = error?.singlePartialError(forKey: recordID) {
        guard let ckerror = error as? CKError else {
          os_log("<fetchRecord> unhandled error: %{public}@",
                 log: DefaultFetchManager.logger,
                 type: .error,
                 String(describing: error))
          completion(nil, .nonRecoverableError)
          return
        }
        if retryCount > 1, let retryAfter = ckerror.retryAfterSeconds?.rounded(.up) {
          os_log("retry fetchRecord after %.1f seconds",
                 log: DefaultFetchManager.logger,
                 type: .default,
                 retryAfter)
          DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(Int(retryAfter))) {
            self.fetchRecord(with: recordID,
                             in: scope,
                             retryCount: retryCount - 1,
                             then: completion)
          }
        } else if ckerror.code == CKError.Code.notAuthenticated {
          completion(nil, .notAuthenticated)
        } else if ckerror.code == CKError.Code.zoneNotFound {
          completion(nil, .zoneNotFound)
        } else if ckerror.code == CKError.Code.unknownItem {
          completion(nil, .itemNoLongerExists)
        } else if ckerror.code == CKError.Code.networkFailure
                  || ckerror.code == CKError.Code.networkUnavailable
                  || ckerror.code == CKError.Code.requestRateLimited
                  || ckerror.code == CKError.Code.serviceUnavailable
                  || ckerror.code == CKError.Code.zoneBusy {
          completion(nil, .nonRecoverableError)
        } else {
          os_log("<fetchRecord> unhandled CKError: %{public}@",
                 log: DefaultFetchManager.logger,
                 type: .error,
                 String(describing: ckerror))
          completion(nil, .nonRecoverableError)
        }
      } else if let records = records {
        completion(records[recordID], nil)
      } else {
        fatalError("both records and error were nil")
      }
    }
    databaseOperationQueue(for: scope).add(operation)
  }
}
