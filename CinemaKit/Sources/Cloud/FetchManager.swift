import CloudKit
import os.log

protocol FetchManager {
  func fetchZones(in scope: CKDatabase.Scope,
                  then completion: @escaping ([CKRecordZone.ID: CKRecordZone]?, CloudKitError?) -> Void)
  func fetch<CustomRecordType>(_ type: CustomRecordType.Type,
                               matching predicate: NSPredicate,
                               inZoneWithID zoneID: CKRecordZone.ID,
                               in scope: CKDatabase.Scope,
                               then completion: @escaping ([CustomRecordType]?, CloudKitError?) -> Void)
      where CustomRecordType: RecordType
  func fetchRecord(with recordID: CKRecord.ID,
                   in scope: CKDatabase.Scope,
                   then completion: @escaping (CKRecord?, CloudKitError?) -> Void)
}

extension FetchManager {
  func fetch<CustomRecordType>(_ type: CustomRecordType.Type,
                               inZoneWithID zoneID: CKRecordZone.ID,
                               in scope: CKDatabase.Scope,
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
       dataInvalidationFlag: LocalDataInvalidationFlag) {
    self.privateDatabaseOperationQueue = privateDatabaseOperationQueue
    self.sharedDatabaseOperationQueue = sharedDatabaseOperationQueue
    self.dataInvalidationFlag = dataInvalidationFlag
  }

  private func databaseOperationQueue(for scope: CKDatabase.Scope) -> DatabaseOperationQueue {
    switch scope {
      case .private:
        return privateDatabaseOperationQueue
      case .shared:
        return sharedDatabaseOperationQueue
      case .public:
        fatalError("can not fetch from public database")
    }
  }

  func fetchZones(in scope: CKDatabase.Scope,
                  then completion: @escaping ([CKRecordZone.ID: CKRecordZone]?, CloudKitError?) -> Void) {
    self.fetchZones(in: scope, retryCount: defaultRetryCount, then: completion)
  }

  private func fetchZones(in scope: CKDatabase.Scope,
                          retryCount: Int,
                          then completion: @escaping ([CKRecordZone.ID: CKRecordZone]?, CloudKitError?) -> Void) {
    let operation = CKFetchRecordZonesOperation.fetchAllRecordZonesOperation()
    operation.fetchRecordZonesCompletionBlock = { zones, error in
      if let error = error {
        if let retryAfter = error.retryAfterSeconds, retryCount > 1 {
          os_log("retry fetchZones after %.1f seconds", log: DefaultFetchManager.logger, type: .default, retryAfter)
          DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(retryAfter)) {
            self.fetchZones(in: scope, retryCount: retryCount - 1, then: completion)
          }
          return
        }
        switch error.ckerrorCode {
          case .notAuthenticated?:
            completion(nil, .notAuthenticated)
          default:
            os_log("<fetchZones> unhandled error: %{public}@",
                   log: DefaultFetchManager.logger,
                   type: .error,
                   String(describing: error))
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
                               inZoneWithID zoneID: CKRecordZone.ID,
                               in scope: CKDatabase.Scope,
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
                     inZoneWithID zoneID: CKRecordZone.ID,
                     into accumulator: [CKRecord],
                     in scope: CKDatabase.Scope,
                     retryCount: Int,
                     then completion: @escaping ([CKRecord]?, CloudKitError?) -> Void) {
    operation.zoneID = zoneID
    var fetchedRecords = [CKRecord]()
    operation.recordFetchedBlock = { record in fetchedRecords.append(record) }
    operation.queryCompletionBlock = { cursor, error in
      if let error = error {
        if let retryAfter = error.retryAfterSeconds, retryCount > 1 {
          os_log("retry fetch after %.1f seconds", log: DefaultFetchManager.logger, type: .default, retryAfter)
          DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(retryAfter)) {
            self.fetch(with: operation,
                       inZoneWithID: zoneID,
                       into: accumulator,
                       in: scope,
                       retryCount: retryCount - 1,
                       then: completion)
          }
          return
        }
        switch error.ckerrorCode {
          case .notAuthenticated?:
            completion(nil, .notAuthenticated)
          case .zoneNotFound?:
            completion(nil, .zoneNotFound)
          case .userDeletedZone?:
            self.dataInvalidationFlag.set()
            completion(nil, .userDeletedZone)
          default:
            os_log("<fetchAll> unhandled error: %{public}@",
                   log: DefaultFetchManager.logger,
                   type: .error,
                   String(describing: error))
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

  func fetchRecord(with recordID: CKRecord.ID,
                   in scope: CKDatabase.Scope,
                   then completion: @escaping (CKRecord?, CloudKitError?) -> Void) {
    fetchRecord(with: recordID, in: scope, retryCount: defaultRetryCount, then: completion)
  }

  private func fetchRecord(with recordID: CKRecord.ID,
                           in scope: CKDatabase.Scope,
                           retryCount: Int,
                           then completion: @escaping (CKRecord?, CloudKitError?) -> Void) {
    let operation = CKFetchRecordsOperation(recordIDs: [recordID])
    operation.fetchRecordsCompletionBlock = { records, error in
      if let error = error?.singlePartialError(forKey: recordID) {
        if let retryAfter = error.retryAfterSeconds, retryCount > 1 {
          os_log("retry fetchRecord after %.1f seconds",
                 log: DefaultFetchManager.logger,
                 type: .default,
                 retryAfter)
          DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(retryAfter)) {
            self.fetchRecord(with: recordID,
                             in: scope,
                             retryCount: retryCount - 1,
                             then: completion)
          }
          return
        }
        switch error.ckerrorCode {
          case .notAuthenticated?:
            completion(nil, .notAuthenticated)
          case .zoneNotFound?:
            completion(nil, .zoneNotFound)
          case .unknownItem?:
            completion(nil, .itemNoLongerExists)
          default:
            os_log("<fetchRecord> unhandled error: %{public}@",
                   log: DefaultFetchManager.logger,
                   type: .error,
                   String(describing: error))
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
