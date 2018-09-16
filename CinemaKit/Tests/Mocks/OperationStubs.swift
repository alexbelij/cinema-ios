import CloudKit

class QueryOperationStub {
  private var calls = [(String?) -> ([CKRecord]?, Error?)]()
  fileprivate var callCount: Int?

  @discardableResult
  func then(_ block: @escaping (String?) -> ([CKRecord]?, Error?)) -> Self {
    guard callCount == nil else { fatalError("stub has already been used") }
    calls.append(block)
    return self
  }

  @discardableResult
  func thenFail(with error: Error) -> Self {
    guard callCount == nil else { fatalError("stub has already been used") }
    calls.append { _ in (nil, error) }
    return self
  }

  @discardableResult
  func thenSucceed(with records: [CKRecord]) -> Self {
    guard callCount == nil else { fatalError("stub has already been used") }
    calls.append { _ in (records, nil) }
    return self
  }

  func call(with operation: CKQueryOperation) {
    if callCount == nil {
      callCount = calls.count
    }
    guard !calls.isEmpty else {
      if callCount == 0 {
        fatalError("CKQueryOperation is not configured for any calls")
      } else {
        fatalError("CKQueryOperation is only configured for \(callCount!) calls")
      }
    }
    let result = calls.removeFirst()(operation.query?.recordType)
    if let records = result.0 {
      for record in records {
        operation.recordFetchedBlock?(record)
      }
    }
    operation.queryCompletionBlock!(nil, result.1)
  }
}

class FetchSubscriptionsStub {
  private var calls = [([String]?) -> ([String: CKSubscription]?, Error?)]()
  fileprivate var callCount: Int?

  @discardableResult
  func then(_ block: @escaping ([String]?) -> ([String: CKSubscription]?, Error?)) -> Self {
    guard callCount == nil else { fatalError("stub has already been used") }
    calls.append(block)
    return self
  }

  @discardableResult
  func thenFail(with error: Error) -> Self {
    guard callCount == nil else { fatalError("stub has already been used") }
    calls.append { _ in (nil, error) }
    return self
  }

  @discardableResult
  func thenSucceedWithNone() -> Self {
    guard callCount == nil else { fatalError("stub has already been used") }
    calls.append { _ in ([:], nil) }
    return self
  }

  func call(with operation: CKFetchSubscriptionsOperation) {
    if callCount == nil {
      callCount = calls.count
    }
    guard !calls.isEmpty else {
      if callCount == 0 {
        fatalError("CKFetchSubscriptionsOperation is not configured for any calls")
      } else {
        fatalError("CKFetchSubscriptionsOperation is only configured for \(callCount!) calls")
      }
    }
    let result = calls.removeFirst()(operation.subscriptionIDs)
    operation.fetchSubscriptionCompletionBlock!(result.0, result.1)
  }
}

class ModifyOperationStub<Operation, Param1, Param2> {
  fileprivate var calls = [(Param1?, Param2?) -> (Param1?, Param2?, Error?)]()
  private var callCount: Int?

  @discardableResult
  func then(_ block: @escaping (Param1?, Param2?) -> (Param1?, Param2?, Error?)) -> Self {
    guard callCount == nil else { fatalError("stub has already been used") }
    calls.append(block)
    return self
  }

  @discardableResult
  func thenFail(with error: Error) -> Self {
    guard callCount == nil else { fatalError("stub has already been used") }
    calls.append { _, _ in (nil, nil, error) }
    return self
  }

  @discardableResult
  func thenSucceed() -> Self {
    guard callCount == nil else { fatalError("stub has already been used") }
    calls.append { ($0, $1, nil) }
    return self
  }

  func call(with operation: Operation) {
    if callCount == nil {
      callCount = calls.count
    }
    guard !calls.isEmpty else {
      if callCount == 0 {
        fatalError("\(Operation.self) is not configured for any calls")
      } else {
        fatalError("\(Operation.self) is only configured for \(callCount!) calls")
      }
    }
    process(calls.removeFirst(), with: operation)
  }

  func process(_ call: (Param1?, Param2?) -> (Param1?, Param2?, Error?), with operation: Operation) {
    fatalError("subclasses should override this method")
  }
}

class ModifySubscriptionsStub: ModifyOperationStub<CKModifySubscriptionsOperation, [CKSubscription], [String]> {
  override func process(_ call: ([CKSubscription]?, [String]?) -> ([CKSubscription]?, [String]?, Error?),
                        with operation: CKModifySubscriptionsOperation) {
    let result = call(operation.subscriptionsToSave, operation.subscriptionIDsToDelete)
    operation.modifySubscriptionsCompletionBlock!(result.0, result.1, result.2)
  }
}

class ModifyRecordZonesStub: ModifyOperationStub<CKModifyRecordZonesOperation, [CKRecordZone], [CKRecordZone.ID]> {
  override func process(_ call: ([CKRecordZone]?, [CKRecordZone.ID]?) -> ([CKRecordZone]?, [CKRecordZone.ID]?, Error?),
                        with operation: CKModifyRecordZonesOperation) {
    let result = call(operation.recordZonesToSave, operation.recordZoneIDsToDelete)
    operation.modifyRecordZonesCompletionBlock!(result.0, result.1, result.2)
  }
}

class ModifyRecordsStub: ModifyOperationStub<CKModifyRecordsOperation, [CKRecord], [CKRecord.ID]> {
  override func process(_ call: ([CKRecord]?, [CKRecord.ID]?) -> ([CKRecord]?, [CKRecord.ID]?, Error?),
                        with operation: CKModifyRecordsOperation) {
    guard operation.perRecordProgressBlock == nil else {
      fatalError("mocking perRecordProgressBlock is not implemented")
    }
    guard operation.perRecordCompletionBlock == nil else {
      fatalError("mocking perRecordCompletionBlock is not implemented")
    }
    let result = call(operation.recordsToSave, operation.recordIDsToDelete)
    operation.modifyRecordsCompletionBlock!(result.0, result.1, result.2)
  }
}
