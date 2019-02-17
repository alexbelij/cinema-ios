import CloudKit
import os.log

protocol ShareManager {
  func saveShare(_ share: CKShare,
                 with rootRecord: CKRecord,
                 then completion: @escaping (CloudKitError?) -> Void)
  func acceptShare(with metadata: CKShareMetadataProtocol, then completion: @escaping (CloudKitError?) -> Void)
  func fetchShareMetadata(for shares: [CKShare],
                          then completion: @escaping ([CKShareMetadataProtocol]?, CloudKitError?) -> Void)
}

class DefaultShareManager: ShareManager {
  private static let logger = Logging.createLogger(category: "ShareManager")
  private let generalOperationQueue: GeneralOperationQueue
  private let privateDatabaseOperationQueue: DatabaseOperationQueue
  private let dataInvalidationFlag: LocalDataInvalidationFlag

  init(generalOperationQueue: GeneralOperationQueue,
       privateDatabaseOperationQueue: DatabaseOperationQueue,
       dataInvalidationFlag: LocalDataInvalidationFlag) {
    self.generalOperationQueue = generalOperationQueue
    self.privateDatabaseOperationQueue = privateDatabaseOperationQueue
    self.dataInvalidationFlag = dataInvalidationFlag
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
        if let retryAfter = error.retryAfterSeconds, retryCount > 1 {
          os_log("retry sync after %.1f seconds", log: DefaultShareManager.logger, type: .default, retryAfter)
          DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(retryAfter)) {
            self.saveShare(share, with: rootRecord, retryCount: retryCount - 1, then: completion)
          }
          return
        }
        guard let ckerror = error as? CKError else {
          os_log("<saveShare> unhandled error: %{public}@",
                 log: DefaultShareManager.logger,
                 type: .error,
                 String(describing: error))
          completion(.nonRecoverableError)
          return
        }
        switch ckerror.code {
          case .notAuthenticated:
            completion(.notAuthenticated)
          case .userDeletedZone:
            self.dataInvalidationFlag.set()
            completion(.userDeletedZone)
          case .serverRecordChanged:
            completion(.conflict(serverRecord: ckerror.serverRecord!))
          case .networkFailure, .networkUnavailable, .requestRateLimited, .serviceUnavailable, .zoneBusy:
            completion(.nonRecoverableError)
          default:
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
    privateDatabaseOperationQueue.add(operation)
  }

  func acceptShare(with metadata: CKShareMetadataProtocol, then completion: @escaping (CloudKitError?) -> Void) {
    acceptShare(with: metadata.asCKShareMetadata(), retryCount: defaultRetryCount, then: completion)
  }

  private func acceptShare(with metadata: CKShare.Metadata,
                           retryCount: Int,
                           then completion: @escaping (CloudKitError?) -> Void) {
    let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
    operation.perShareCompletionBlock = { _, share, error in
      if let error = error {
        if let retryAfter = error.retryAfterSeconds, retryCount > 1 {
          os_log("retry accept share after %.1f seconds",
                 log: DefaultShareManager.logger,
                 type: .default,
                 retryAfter)
          DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(retryAfter)) {
            self.acceptShare(with: metadata,
                             retryCount: retryCount - 1,
                             then: completion)
          }
          return
        }
        guard let ckerror = error as? CKError else {
          os_log("<acceptCloudKitShare> unhandled error: %{public}@",
                 log: DefaultShareManager.logger,
                 type: .error,
                 String(describing: error))
          completion(.nonRecoverableError)
          return
        }
        switch ckerror.code {
          case .notAuthenticated:
            completion(.notAuthenticated)
          case .unknownItem:
            completion(.itemNoLongerExists)
          case .networkFailure, .networkUnavailable, .requestRateLimited, .serviceUnavailable, .zoneBusy:
            completion(.nonRecoverableError)
          default:
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

  func fetchShareMetadata(for shares: [CKShare],
                          then completion: @escaping ([CKShareMetadataProtocol]?, CloudKitError?) -> Void) {
    fetchShareMetadata(for: shares, retryCount: defaultRetryCount, then: completion)
  }

  func fetchShareMetadata(for shares: [CKShare],
                          retryCount: Int,
                          then completion: @escaping ([CKShareMetadataProtocol]?, CloudKitError?) -> Void) {
    let operation = CKFetchShareMetadataOperation(shareURLs: shares.compactMap { $0.url })
    operation.shouldFetchRootRecord = true

    var shareMetadatas = [CKShare.Metadata]()
    var unhandledErrorOccurred = false
    operation.perShareMetadataBlock = { _, shareMetadata, error in
      if let error = error {
        guard let ckerror = error as? CKError else { return }
        if ckerror.code != CKError.Code.unknownItem {
          unhandledErrorOccurred = true
        }
      } else if let shareMetadata = shareMetadata {
        shareMetadatas.append(shareMetadata)
      }
    }
    operation.fetchShareMetadataCompletionBlock = { error in
      if let error = error {
        guard let ckerror = error as? CKError else {
          os_log("<fetchShareMetadata> unhandled error: %{public}@",
                 log: DefaultShareManager.logger,
                 type: .error,
                 String(describing: error))
          completion(nil, .nonRecoverableError)
          return
        }
        switch ckerror.code {
          case .notAuthenticated:
            completion(nil, .notAuthenticated)
          case .networkFailure, .networkUnavailable, .requestRateLimited, .serviceUnavailable, .zoneBusy:
            completion(nil, .nonRecoverableError)
          case .partialFailure where !unhandledErrorOccurred:
            completion(shareMetadatas, nil)
          default:
            os_log("<fetchShareMetadata> unhandled CKError: %{public}@",
                   log: DefaultShareManager.logger,
                   type: .error,
                   String(describing: ckerror))
            completion(nil, .nonRecoverableError)
        }
      } else {
        completion(shareMetadatas, nil)
      }
    }
    generalOperationQueue.add(operation)
  }
}
