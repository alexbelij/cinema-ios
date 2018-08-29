import CloudKit
import os.log

protocol ShareManager {
  func saveShare(_ share: CKShare,
                 with rootRecord: CKRecord,
                 then completion: @escaping (CloudKitError?) -> Void)
  func acceptShare(with metadata: CKShareMetadata, then completion: @escaping (CloudKitError?) -> Void)
}

class DefaultShareManager: ShareManager {
  private static let logger = Logging.createLogger(category: "ShareManager")
  private let generalOperationQueue: GeneralOperationQueue
  private let queueFactory: DatabaseOperationQueueFactory
  private let cacheInvalidationFlag: LocalCloudKitCacheInvalidationFlag

  init(generalOperationQueue: GeneralOperationQueue,
       queueFactory: DatabaseOperationQueueFactory,
       cacheInvalidationFlag: LocalCloudKitCacheInvalidationFlag = LocalCloudKitCacheInvalidationFlag()) {
    self.generalOperationQueue = generalOperationQueue
    self.queueFactory = queueFactory
    self.cacheInvalidationFlag = cacheInvalidationFlag
  }

  func saveShare(_ share: CKShare,
                 with rootRecord: CKRecord,
                 then completion: @escaping (CloudKitError?) -> Void) {
    saveShare(share, with: rootRecord, retryCount: defaultRetryCount, then: completion)
  }

  func saveShare(_ share: CKShare,
                 with rootRecord: CKRecord,
                 retryCount: Int,
                 then completion: @escaping (CloudKitError?) -> Void) {
    let operation = CKModifyRecordsOperation(recordsToSave: [share, rootRecord], recordIDsToDelete: [])
    operation.modifyRecordsCompletionBlock = { _, _, error in
      // if there is a partial error, then it is the root record which caused it
      if let error = error?.singlePartialError(forKey: rootRecord.recordID) {
        guard let ckerror = error as? CKError else {
          os_log("<saveShare> unhandled error: %{public}@",
                 log: DefaultShareManager.logger,
                 type: .error,
                 String(describing: error))
          completion(.nonRecoverableError)
          return
        }
        if retryCount > 1, let retryAfter = ckerror.retryAfterSeconds?.rounded(.up) {
          os_log("retry sync after %.1f seconds", log: DefaultShareManager.logger, type: .default, retryAfter)
          DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(Int(retryAfter))) {
            self.saveShare(share, with: rootRecord, retryCount: retryCount - 1, then: completion)
          }
        } else if ckerror.code == CKError.Code.serverRecordChanged {
          completion(.conflict(serverRecord: ckerror.serverRecord!))
        } else if ckerror.code == CKError.Code.notAuthenticated {
          completion(.notAuthenticated)
        } else if ckerror.code == CKError.Code.userDeletedZone {
          self.cacheInvalidationFlag.set()
          completion(.userDeletedZone)
        } else if ckerror.code == CKError.Code.networkFailure
                  || ckerror.code == CKError.Code.networkUnavailable
                  || ckerror.code == CKError.Code.requestRateLimited
                  || ckerror.code == CKError.Code.serviceUnavailable
                  || ckerror.code == CKError.Code.zoneBusy {
          completion(.nonRecoverableError)
        } else {
          os_log("<saveShare> unhandled CKError: %{public}@",
                 log: DefaultShareManager.logger,
                 type: .error,
                 String(describing: ckerror))
          completion(.nonRecoverableError)
        }
      } else {
        completion(nil)
      }
    }
    queueFactory.queue(withScope: .private).add(operation)
  }

  func acceptShare(with metadata: CKShareMetadata, then completion: @escaping (CloudKitError?) -> Void) {
    acceptShare(with: metadata, retryCount: defaultRetryCount, then: completion)
  }

  private func acceptShare(with metadata: CKShareMetadata,
                           retryCount: Int,
                           then completion: @escaping (CloudKitError?) -> Void) {
    let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
    operation.perShareCompletionBlock = { _, share, error in
      if let error = error {
        guard let ckerror = error as? CKError else {
          os_log("<acceptCloudKitShare> unhandled error: %{public}@",
                 log: DefaultShareManager.logger,
                 type: .error,
                 String(describing: error))
          completion(.nonRecoverableError)
          return
        }
        if retryCount > 1, let retryAfter = ckerror.retryAfterSeconds?.rounded(.up) {
          os_log("retry accept share after %.1f seconds",
                 log: DefaultShareManager.logger,
                 type: .default,
                 retryAfter)
          DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(Int(retryAfter))) {
            self.acceptShare(with: metadata,
                             retryCount: retryCount - 1,
                             then: completion)
          }
        } else if ckerror.code == CKError.Code.notAuthenticated {
          completion(.notAuthenticated)
        } else if ckerror.code == CKError.Code.invalidArguments {
          os_log("owner tried to accept share -> ignore", log: DefaultShareManager.logger, type: .default)
        } else if ckerror.code == CKError.Code.unknownItem {
          completion(.itemNoLongerExists)
        } else if ckerror.code == CKError.Code.networkFailure
                  || ckerror.code == CKError.Code.networkUnavailable
                  || ckerror.code == CKError.Code.requestRateLimited
                  || ckerror.code == CKError.Code.serviceUnavailable
                  || ckerror.code == CKError.Code.zoneBusy {
          completion(.nonRecoverableError)
        } else {
          os_log("<acceptCloudKitShare> unhandled CKError: %{public}@",
                 log: DefaultShareManager.logger,
                 type: .error,
                 String(describing: ckerror))
          completion(.nonRecoverableError)
        }
      } else {
        completion(nil)
      }
    }
    generalOperationQueue.add(operation)
  }
}
