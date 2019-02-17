import CloudKit
import Dispatch
import os.log

protocol SyncManager {
  func sync(_ record: CKRecord,
            in scope: CKDatabase.Scope,
            then completion: @escaping (CloudKitError?) -> Void)
  func syncAll(_ records: [CKRecord],
               in scope: CKDatabase.Scope,
               then completion: @escaping (CloudKitError?) -> Void)
  func delete(_ record: CKRecord,
              in scope: CKDatabase.Scope,
              then completion: @escaping (CloudKitError?) -> Void)
  func delete(_ recordIDs: [CKRecord.ID], in scope: CKDatabase.Scope)
}

class DefaultSyncManager: SyncManager {
  private static let logger = Logging.createLogger(category: "SyncManager")

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
        fatalError("can not sync in public database")
    }
  }

  func sync(_ record: CKRecord, in scope: CKDatabase.Scope, then completion: @escaping (CloudKitError?) -> Void) {
    sync(record, in: scope, retryCount: defaultRetryCount, then: completion)
  }

  private func sync(_ record: CKRecord,
                    in scope: CKDatabase.Scope,
                    retryCount: Int,
                    then completion: @escaping (CloudKitError?) -> Void) {
    os_log("creating modify records operation to save %{public}@",
           log: DefaultSyncManager.logger,
           type: .default,
           record.recordType)
    let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
    operation.modifyRecordsCompletionBlock = { _, _, error in
      if let error = error?.singlePartialError(forKey: record.recordID) {
        if let retryAfter = error.retryAfterSeconds, retryCount > 1 {
          os_log("retry sync after %.1f seconds", log: DefaultSyncManager.logger, type: .default, retryAfter)
          DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(retryAfter)) {
            self.sync(record, in: scope, retryCount: retryCount - 1, then: completion)
          }
          return
        }
        switch error.ckerrorCode {
          case .notAuthenticated?:
            completion(.notAuthenticated)
          case .userDeletedZone?:
            self.dataInvalidationFlag.set()
            completion(.userDeletedZone)
          case .serverRecordChanged?:
            // swiftlint:disable:next force_cast
            completion(.conflict(serverRecord: (error as! CKError).serverRecord!))
          case .unknownItem?:
            completion(.itemNoLongerExists)
          case .permissionFailure?:
            completion(.permissionFailure)
          default:
            os_log("<sync> unhandled error: %{public}@",
                   log: DefaultSyncManager.logger,
                   type: .error,
                   String(describing: error))
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
    databaseOperationQueue(for: scope).add(operation)
  }

  func syncAll(_ records: [CKRecord], in scope: CKDatabase.Scope, then completion: @escaping (CloudKitError?) -> Void) {
    let batchSize = 300
    var recordsToProcess = records
    let numberOfRecordsToProcess: Int = recordsToProcess.count
    os_log("need to sync %d records -> %d requests",
           log: DefaultSyncManager.logger,
           type: .default,
           numberOfRecordsToProcess,
           Int(ceil(Double(numberOfRecordsToProcess) / Double(batchSize))))
    let group = DispatchGroup()
    var errors = [CloudKitError]()
    var startIndex = 0
    var endIndex = min(numberOfRecordsToProcess, batchSize) - 1
    while startIndex < numberOfRecordsToProcess {
      os_log("syncing batch (%d through %d)", log: DefaultSyncManager.logger, type: .default, startIndex, endIndex)
      group.enter()
      let batch = Array(recordsToProcess[startIndex...endIndex])
      syncAll(batch, in: scope, retryCount: defaultRetryCount) { error in
        if let error = error {
          errors.append(error)
        }
        group.leave()
      }
      startIndex = endIndex + 1
      endIndex = min(numberOfRecordsToProcess, endIndex + batchSize)
    }
    group.notify(queue: DispatchQueue.global()) {
      completion(errors.first)
    }
  }

  private func syncAll(_ records: [CKRecord],
                       in scope: CKDatabase.Scope,
                       retryCount: Int,
                       then completion: @escaping (CloudKitError?) -> Void) {
    os_log("creating modify records operation to batch save %d records",
           log: DefaultSyncManager.logger,
           type: .default,
           records.count)
    let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
    operation.modifyRecordsCompletionBlock = { _, _, error in
      if let error = error {
        if let retryAfter = error.retryAfterSeconds, retryCount > 1 {
          os_log("retry sync after %.1f seconds", log: DefaultSyncManager.logger, type: .default, retryAfter)
          DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(retryAfter)) {
            self.syncAll(records, in: scope, retryCount: retryCount - 1, then: completion)
          }
          return
        }
        switch error.ckerrorCode {
          case .notAuthenticated?:
            completion(.notAuthenticated)
          case .userDeletedZone?:
            self.dataInvalidationFlag.set()
            completion(.userDeletedZone)
          case .partialFailure?:
            os_log("<syncAll> partial error: %{public}@",
                   log: DefaultSyncManager.logger,
                   type: .error,
                   // swiftlint:disable:next force_cast
                   String(describing: (error as! CKError).partialErrorsByItemID))
            completion(.nonRecoverableError)
          default:
            os_log("<syncAll> unhandled error: %{public}@",
                   log: DefaultSyncManager.logger,
                   type: .error,
                   String(describing: error))
            completion(.nonRecoverableError)
        }
      } else {
        os_log("pushed %d record",
               log: DefaultSyncManager.logger,
               type: .debug,
               records.count)
        completion(nil)
      }
    }
    databaseOperationQueue(for: scope).add(operation)
  }

  func delete(_ record: CKRecord, in scope: CKDatabase.Scope, then completion: @escaping (CloudKitError?) -> Void) {
    delete(record, in: scope, retryCount: defaultRetryCount, then: completion)
  }

  private func delete(_ record: CKRecord,
                      in scope: CKDatabase.Scope,
                      retryCount: Int,
                      then completion: @escaping (CloudKitError?) -> Void) {
    os_log("creating modify records operation to delete %{public}@",
           log: DefaultSyncManager.logger,
           type: .default,
           record.recordType)
    let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [record.recordID])
    operation.modifyRecordsCompletionBlock = { _, _, error in
      if let error = error?.singlePartialError(forKey: record.recordID) {
        if let retryAfter = error.retryAfterSeconds, retryCount > 1 {
          os_log("retry delete after %.1f seconds", log: DefaultSyncManager.logger, type: .default, retryAfter)
          DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(retryAfter)) {
            self.delete(record, in: scope, retryCount: retryCount - 1, then: completion)
          }
          return
        }
        switch error.ckerrorCode {
          case .notAuthenticated?:
            completion(.notAuthenticated)
          case .userDeletedZone?:
            self.dataInvalidationFlag.set()
            completion(.userDeletedZone)
          case .unknownItem?:
            completion(nil)
          case .permissionFailure?:
            completion(.permissionFailure)
          default:
            os_log("<delete> unhandled error: %{public}@",
                   log: DefaultSyncManager.logger,
                   type: .error,
                   String(describing: error))
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
    databaseOperationQueue(for: scope).add(operation)
  }

  func delete(_ recordIDs: [CKRecord.ID], in scope: CKDatabase.Scope) {
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
    databaseOperationQueue(for: scope).add(operation)
  }
}
