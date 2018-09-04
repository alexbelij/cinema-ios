import CloudKit
import os.log

protocol FetchManager {
  func fetchZones(using queue: DatabaseOperationQueue,
                  then completion: @escaping ([CKRecordZoneID: CKRecordZone]?, CloudKitError?) -> Void)
  func fetch<CustomRecordType>(_ type: CustomRecordType.Type,
                               matching predicate: NSPredicate,
                               inZoneWithID zoneID: CKRecordZoneID,
                               using queue: DatabaseOperationQueue,
                               then completion: @escaping ([CustomRecordType]?, CloudKitError?) -> Void)
      where CustomRecordType: RecordType
  func fetchRecord(with recordID: CKRecordID,
                   using queue: DatabaseOperationQueue,
                   then completion: @escaping (CKRecord?, CloudKitError?) -> Void)
}

extension FetchManager {
  func fetch<CustomRecordType>(_ type: CustomRecordType.Type,
                               inZoneWithID zoneID: CKRecordZoneID,
                               using queue: DatabaseOperationQueue,
                               then completion: @escaping ([CustomRecordType]?, CloudKitError?) -> Void)
      where CustomRecordType: RecordType {
    fetch(type,
          matching: NSPredicate(value: true),
          inZoneWithID: zoneID,
          using: queue,
          then: completion)
  }
}

class DefaultFetchManager: FetchManager {
  private static let logger = Logging.createLogger(category: "FetchManager")

  private let cacheInvalidationFlag: LocalCloudKitCacheInvalidationFlag

  init(cacheInvalidationFlag: LocalCloudKitCacheInvalidationFlag = LocalCloudKitCacheInvalidationFlag()) {
    self.cacheInvalidationFlag = cacheInvalidationFlag
  }

  func fetchZones(using queue: DatabaseOperationQueue,
                  then completion: @escaping ([CKRecordZoneID: CKRecordZone]?, CloudKitError?) -> Void) {
    self.fetchZones(using: queue, retryCount: defaultRetryCount, then: completion)
  }

  private func fetchZones(using queue: DatabaseOperationQueue,
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
            self.fetchZones(using: queue, retryCount: retryCount - 1, then: completion)
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
    queue.add(operation)
  }

  func fetch<CustomRecordType>(_ type: CustomRecordType.Type,
                               matching predicate: NSPredicate = NSPredicate(value: true),
                               inZoneWithID zoneID: CKRecordZoneID,
                               using queue: DatabaseOperationQueue,
                               then completion: @escaping ([CustomRecordType]?, CloudKitError?) -> Void)
      where CustomRecordType: RecordType {
    fetch(type,
          matching: predicate,
          inZoneWithID: zoneID,
          using: queue,
          retryCount: defaultRetryCount,
          then: completion)
  }

  private func fetch<CustomRecordType>(_ type: CustomRecordType.Type,
                                       matching predicate: NSPredicate,
                                       inZoneWithID zoneID: CKRecordZoneID,
                                       using queue: DatabaseOperationQueue,
                                       retryCount: Int,
                                       then completion: @escaping ([CustomRecordType]?, CloudKitError?) -> Void)
      where CustomRecordType: RecordType {
    os_log("creating query operation for %{public}@",
           log: DefaultFetchManager.logger,
           type: .default,
           String(describing: type))
    let query = CKQuery(recordType: type.recordType, predicate: predicate)
    let operation = CKQueryOperation(query: query)
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
            self.fetch(type,
                       matching: predicate,
                       inZoneWithID: zoneID,
                       using: queue,
                       retryCount: retryCount - 1,
                       then: completion)
          }
        } else if ckerror.code == CKError.Code.notAuthenticated {
          completion(nil, .notAuthenticated)
        } else if ckerror.code == CKError.Code.zoneNotFound {
          completion(nil, .zoneNotFound)
        } else if ckerror.code == CKError.Code.userDeletedZone {
          self.cacheInvalidationFlag.set()
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
      } else {
        os_log("fetched %d %{public}@ records",
               log: DefaultFetchManager.logger,
               type: .debug,
               fetchedRecords.count,
               String(describing: type))
        completion(fetchedRecords.map(CustomRecordType.init), nil)
      }
    }
    queue.add(operation)
  }

  func fetchRecord(with recordID: CKRecordID,
                   using queue: DatabaseOperationQueue,
                   then completion: @escaping (CKRecord?, CloudKitError?) -> Void) {
    fetchRecord(with: recordID, using: queue, retryCount: defaultRetryCount, then: completion)
  }

  private func fetchRecord(with recordID: CKRecordID,
                           using queue: DatabaseOperationQueue,
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
                             using: queue,
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
    queue.add(operation)
  }
}
