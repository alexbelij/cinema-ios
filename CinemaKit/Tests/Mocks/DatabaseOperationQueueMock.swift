@testable import CinemaKit
import CloudKit
import XCTest

class DatabaseOperationQueueMock: DatabaseOperationQueue {
  lazy var whenFetchSubscriptions = FetchSubscriptionsStub()
  lazy var whenModifySubscriptions = ModifySubscriptionsStub()
  lazy var whenModifyRecordZones = ModifyRecordZonesStub()
  lazy var whenModifyRecords = ModifyRecordsStub()
  lazy var whenQueryOperation = QueryOperationStub()

  func add(_ operation: CKDatabaseOperation) {
    if let fetchSubscriptions = operation as? CKFetchSubscriptionsOperation {
      whenFetchSubscriptions.call(with: fetchSubscriptions)
    } else if let modifySubscription = operation as? CKModifySubscriptionsOperation {
      whenModifySubscriptions.call(with: modifySubscription)
    } else if let modifyRecordZones = operation as? CKModifyRecordZonesOperation {
      whenModifyRecordZones.call(with: modifyRecordZones)
    } else if let modifyRecords = operation as? CKModifyRecordsOperation {
      whenModifyRecords.call(with: modifyRecords)
    } else if let queryOperation = operation as? CKQueryOperation {
      whenQueryOperation.call(with: queryOperation)
    } else {
      fatalError("unexpected operation type \(type(of: operation))")
    }
  }
}
