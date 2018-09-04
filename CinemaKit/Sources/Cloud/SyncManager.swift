import CloudKit
import os.log

protocol SyncManager {
  func sync(_ record: CKRecord,
            using queue: DatabaseOperationQueue,
            then completion: @escaping (CloudKitError?) -> Void)
  func delete(_ record: CKRecord,
              using queue: DatabaseOperationQueue,
              then completion: @escaping (CloudKitError?) -> Void)
  func delete(_ recordIDs: [CKRecordID], using queue: DatabaseOperationQueue)
}

class DefaultSyncManager: SyncManager {
  private static let logger = Logging.createLogger(category: "SyncManager")

  private let cacheInvalidationFlag: LocalCloudKitCacheInvalidationFlag

  init(cacheInvalidationFlag: LocalCloudKitCacheInvalidationFlag = LocalCloudKitCacheInvalidationFlag()) {
    self.cacheInvalidationFlag = cacheInvalidationFlag
  }

  func sync(_ record: CKRecord,
            using queue: DatabaseOperationQueue,
            then completion: @escaping (CloudKitError?) -> Void) {
    sync(record, using: queue, retryCount: defaultRetryCount, then: completion)
  }

  private func sync(_ record: CKRecord,
                    using queue: DatabaseOperationQueue,
                    retryCount: Int,
                    then completion: @escaping (CloudKitError?) -> Void) {
    os_log("creating modify records operation to save %{public}@",
           log: DefaultSyncManager.logger,
           type: .default,
           record.recordType)
    let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
    operation.modifyRecordsCompletionBlock = { _, _, error in
      if let error = error?.singlePartialError(forKey: record.recordID) {
        guard let ckerror = error as? CKError else {
          os_log("<sync> unhandled error: %{public}@",
                 log: DefaultSyncManager.logger,
                 type: .error,
                 String(describing: error))
          completion(.nonRecoverableError)
          return
        }
        if retryCount > 1, let retryAfter = ckerror.retryAfterSeconds?.rounded(.up) {
          os_log("retry sync after %.1f seconds", log: DefaultSyncManager.logger, type: .default, retryAfter)
          DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(Int(retryAfter))) {
            self.sync(record, using: queue, retryCount: retryCount - 1, then: completion)
          }
        } else if ckerror.code == CKError.Code.notAuthenticated {
          completion(.notAuthenticated)
        } else if ckerror.code == CKError.Code.userDeletedZone {
          self.cacheInvalidationFlag.set()
          completion(.userDeletedZone)
        } else if ckerror.code == CKError.Code.serverRecordChanged {
          completion(.conflict(serverRecord: ckerror.serverRecord!))
        } else if ckerror.code == CKError.Code.unknownItem {
          completion(.itemNoLongerExists)
        } else if ckerror.code == CKError.Code.networkFailure
                  || ckerror.code == CKError.Code.networkUnavailable
                  || ckerror.code == CKError.Code.requestRateLimited
                  || ckerror.code == CKError.Code.serviceUnavailable
                  || ckerror.code == CKError.Code.zoneBusy {
          completion(.nonRecoverableError)
        } else {
          os_log("<sync> unhandled CKError: %{public}@",
                 log: DefaultSyncManager.logger,
                 type: .error,
                 String(describing: ckerror))
          completion(.nonRecoverableError)
        }
      } else {
        os_log("pushed %{public}@ record",
               log: DefaultSyncManager.logger,
               type: .debug,
               record.recordType)
        completion(nil)
      }
    }
    queue.add(operation)
  }

  func delete(_ record: CKRecord,
              using queue: DatabaseOperationQueue,
              then completion: @escaping (CloudKitError?) -> Void) {
    delete(record, using: queue, retryCount: defaultRetryCount, then: completion)
  }

  private func delete(_ record: CKRecord,
                      using queue: DatabaseOperationQueue,
                      retryCount: Int,
                      then completion: @escaping (CloudKitError?) -> Void) {
    os_log("creating modify records operation to delete %{public}@",
           log: DefaultSyncManager.logger,
           type: .default,
           record.recordType)
    let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [record.recordID])
    operation.modifyRecordsCompletionBlock = { _, _, error in
      if let error = error?.singlePartialError(forKey: record.recordID) {
        guard let ckerror = error as? CKError else {
          os_log("<delete> unhandled error: %{public}@",
                 log: DefaultSyncManager.logger,
                 type: .error,
                 String(describing: error))
          completion(.nonRecoverableError)
          return
        }
        if retryCount > 1, let retryAfter = ckerror.retryAfterSeconds?.rounded(.up) {
          os_log("retry delete after %.1f seconds", log: DefaultSyncManager.logger, type: .default, retryAfter)
          DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(Int(retryAfter))) {
            self.delete(record, using: queue, retryCount: retryCount - 1, then: completion)
          }
        } else if ckerror.code == CKError.Code.notAuthenticated {
          completion(.notAuthenticated)
        } else if ckerror.code == CKError.Code.userDeletedZone {
          self.cacheInvalidationFlag.set()
          completion(.userDeletedZone)
        } else if ckerror.code == CKError.Code.unknownItem {
          completion(nil)
        } else if ckerror.code == CKError.Code.networkFailure
                  || ckerror.code == CKError.Code.networkUnavailable
                  || ckerror.code == CKError.Code.requestRateLimited
                  || ckerror.code == CKError.Code.serviceUnavailable
                  || ckerror.code == CKError.Code.zoneBusy {
          completion(.nonRecoverableError)
        } else {
          os_log("<delete> unhandled CKError: %{public}@",
                 log: DefaultSyncManager.logger,
                 type: .error,
                 String(describing: ckerror))
          completion(.nonRecoverableError)
        }
      } else {
        os_log("deleted %{public}@ record",
               log: DefaultSyncManager.logger,
               type: .debug,
               record.recordType)
        completion(nil)
      }
    }
    queue.add(operation)
  }

  func delete(_ recordIDs: [CKRecordID], using queue: DatabaseOperationQueue) {
    os_log("creating modify records operation to delete %d records (no callback)",
           log: DefaultSyncManager.logger,
           type: .default,
           recordIDs.count)
    let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
    operation.modifyRecordsCompletionBlock = { _, _, error in
      if let error = error {
        os_log("batch delete failed: %{public}@",
               log: DefaultSyncManager.logger,
               type: .error,
               String(describing: error))
      } else {
        os_log("deleted %d record",
               log: DefaultSyncManager.logger,
               type: .debug,
               recordIDs.count)
      }
    }
    queue.add(operation)
  }
}
