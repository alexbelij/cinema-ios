import CloudKit
import Dispatch
import os.log
import UIKit

protocol SubscriptionManager {
  func subscribeForChanges(then completion: @escaping (CloudKitError?) -> Void)
}

enum SubscriptionTarget: String, Codable {
  case deviceSyncZone
  case sharedDatabase

  var subscriptionID: String {
    switch self {
      case .deviceSyncZone: return "DeviceSyncZoneSubscriptionID"
      case .sharedDatabase: return "SharedDatabaseSubscriptionID"
    }
  }

  func makeSubscription() -> CKSubscription {
    let subscription: CKSubscription
    switch self {
      case .deviceSyncZone:
        subscription = CKRecordZoneSubscription(zoneID: deviceSyncZoneID, subscriptionID: subscriptionID)
      case .sharedDatabase:
        subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
    }
    let notificationInfo = CKSubscription.NotificationInfo()
    notificationInfo.shouldSendContentAvailable = true
    subscription.notificationInfo = notificationInfo
    return subscription
  }

  var scope: CKDatabase.Scope {
    switch self {
      case .deviceSyncZone: return .private
      case .sharedDatabase: return .shared
    }
  }
}

class DefaultSubscriptionManager: SubscriptionManager {
  private static let logger = Logging.createLogger(category: "SubscriptionManager")
  private let privateDatabaseOperationQueue: DatabaseOperationQueue
  private let sharedDatabaseOperationQueue: DatabaseOperationQueue
  private let subscriptionStore: SubscriptionStore
  private let dataInvalidationFlag: LocalDataInvalidationFlag

  init(privateDatabaseOperationQueue: DatabaseOperationQueue,
       sharedDatabaseOperationQueue: DatabaseOperationQueue,
       subscriptionStore: SubscriptionStore = FileBasedSubscriptionStore(),
       dataInvalidationFlag: LocalDataInvalidationFlag) {
    self.privateDatabaseOperationQueue = privateDatabaseOperationQueue
    self.sharedDatabaseOperationQueue = sharedDatabaseOperationQueue
    self.subscriptionStore = subscriptionStore
    self.dataInvalidationFlag = dataInvalidationFlag
  }

  private func databaseOperationQueue(for scope: CKDatabase.Scope) -> DatabaseOperationQueue {
  switch scope {
    case .private:
      return privateDatabaseOperationQueue
    case .shared:
      return sharedDatabaseOperationQueue
    case .public:
      fatalError("can not subscribe to public database")
  }
}

  func subscribeForChanges(then completion: @escaping (CloudKitError?) -> Void) {
    subscribeForChanges(for: .deviceSyncZone) { error in
      if let error = error {
        completion(error)
      } else {
        self.subscribeForChanges(for: .sharedDatabase, then: completion)
      }
    }
  }

  private func subscribeForChanges(for target: SubscriptionTarget,
                                   then completion: @escaping (CloudKitError?) -> Void) {
    if subscriptionStore.hasSubscribedTo(target) {
      completion(nil)
      return
    }
    fetchAllSubscriptions(in: target.scope, retryCount: defaultRetryCount) { subscriptions, error in
      if let error = error {
        os_log("already subscribed to %{public}@ (local)",
               log: DefaultSubscriptionManager.logger,
               type: .info,
               String(describing: target))
        completion(error)
      } else if let subscriptions = subscriptions {
        if subscriptions[target.subscriptionID] == nil {
          self.saveSubscription(target.makeSubscription(),
                                in: target.scope,
                                retryCount: defaultRetryCount) { error in
            if let error = error {
              completion(error)
            } else {
              self.subscriptionStore.setHasSubscribedTo(target)
              os_log("saved subscription for %{public}@",
                     log: DefaultSubscriptionManager.logger,
                     type: .info,
                     String(describing: target))
              completion(nil)
            }
          }
        } else {
          os_log("already subscribed to %{public}@ (remote)",
                 log: DefaultSubscriptionManager.logger,
                 type: .info,
                 String(describing: target))
          self.subscriptionStore.setHasSubscribedTo(target)
          completion(nil)
        }
      }
    }
  }

  private func fetchAllSubscriptions(
      in scope: CKDatabase.Scope,
      retryCount: Int,
      then completion: @escaping ([String: CKSubscription]?, CloudKitError?) -> Void) {
    let operation = CKFetchSubscriptionsOperation.fetchAllSubscriptionsOperation()
    operation.fetchSubscriptionCompletionBlock = { subscriptions, error in
      if let error = error {
        if let retryAfter = error.retryAfterSeconds, retryCount > 1 {
          os_log("retry fetchAllSubscriptions after %.1f seconds",
                 log: DefaultSubscriptionManager.logger,
                 type: .default,
                 retryAfter)
          DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(retryAfter)) {
            self.fetchAllSubscriptions(in: scope, retryCount: retryCount - 1, then: completion)
          }
          return
        }
        guard let ckerror = error as? CKError else {
          os_log("<fetchAllSubscriptions> unhandled error: %{public}@",
                 log: DefaultSubscriptionManager.logger,
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
          default:
            os_log("<fetchAllSubscriptions> unhandled CKError: %{public}@",
                   log: DefaultSubscriptionManager.logger,
                   type: .error,
                   String(describing: ckerror))
            completion(nil, .nonRecoverableError)
        }
      } else if let subscriptions = subscriptions {
        completion(subscriptions, nil)
      }
    }
    databaseOperationQueue(for: scope).add(operation)
  }

  private func saveSubscription(_ subscription: CKSubscription,
                                in scope: CKDatabase.Scope,
                                retryCount: Int,
                                then completion: @escaping (CloudKitError?) -> Void) {
    let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription],
                                                   subscriptionIDsToDelete: nil)
    operation.modifySubscriptionsCompletionBlock = { _, _, error in
      if let error = error?.singlePartialError(forKey: subscription.subscriptionID) {
        if let retryAfter = error.retryAfterSeconds, retryCount > 1 {
          os_log("retry saveSubscription after %.1f seconds",
                 log: DefaultSubscriptionManager.logger,
                 type: .default,
                 retryAfter)
          DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(retryAfter)) {
            self.saveSubscription(subscription, in: scope, retryCount: retryCount - 1, then: completion)
          }
          return
        }
        guard let ckerror = error as? CKError else {
          os_log("<saveSubscription> unhandled error: %{public}@",
                 log: DefaultSubscriptionManager.logger,
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
          case .networkFailure, .networkUnavailable, .requestRateLimited, .serviceUnavailable, .zoneBusy:
            completion(.nonRecoverableError)
          default:
            os_log("<saveSubscription> unhandled CKError: %{public}@",
                   log: DefaultSubscriptionManager.logger,
                   type: .error,
                   String(describing: ckerror))
            completion(.nonRecoverableError)
        }
      } else {
        completion(nil)
      }
    }
    databaseOperationQueue(for: scope).add(operation)
  }
}
