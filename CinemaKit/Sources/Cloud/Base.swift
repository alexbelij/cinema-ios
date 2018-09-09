import CloudKit

protocol DeviceSyncable: Equatable {
  associatedtype CustomRecordType: RecordType

  var id: CKRecordID { get }

  // conforming types should have an initializer of the form
  // init(from record: CustomRecordType, <custom properties>...)

  func setCustomFields(in record: CustomRecordType)
}

protocol RecordType: class {
  static var recordType: String { get }

  static func copyCustomFields(from source: CKRecord, to target: CKRecord)

  var rawRecord: CKRecord { get set }

  init(_ rawRecord: CKRecord)
}

extension RecordType {
  init(recordID: CKRecordID) {
    self.init(CKRecord(recordType: Self.recordType, recordID: recordID))
  }

  init<Element: DeviceSyncable>(from element: Element) where Element.CustomRecordType == Self {
    self.init(recordID: element.id)
    element.setCustomFields(in: self)
  }

  var id: CKRecordID {
    return rawRecord.recordID
  }

  var shareID: CKRecordID? {
    return rawRecord.share?.recordID
  }
}

protocol GeneralOperationQueue {
  func add(_ operation: CKOperation)
}

extension CKContainer: GeneralOperationQueue {
}

protocol DatabaseOperationQueue {
  func add(_ operation: CKDatabaseOperation)
}

extension CKDatabase: DatabaseOperationQueue {
}

extension Error {
  func singlePartialError(forKey key: Any) -> Error {
    guard let ckerror = self as? CKError else { return self }
    guard let partialErrorInfo = ckerror.userInfo[CKPartialErrorsByItemIDKey] as? NSDictionary else { return self }
    // swiftlint:disable:next force_cast
    return (partialErrorInfo[key] as! NSError) as Error
  }
}

public enum CloudKitError: Error {
  case conflict(serverRecord: CKRecord)
  case itemNoLongerExists
  case notAuthenticated
  case zoneNotFound
  case userDeletedZone
  case permissionFailure
  case nonRecoverableError
}

public enum ApplicationWideEvent {
  public static let userInfoKey = "ApplicationWideEventUserInfoKey"

  case notAuthenticated
  case userDeletedZone
  case shouldFetchChanges

  public var notification: Notification {
    let userInfo: [AnyHashable: Any] = [ApplicationWideEvent.userInfoKey: self]
    return Notification(name: .applicationWideEventDidOccur, object: nil, userInfo: userInfo)
  }
}

extension Notification.Name {
  public static let applicationWideEventDidOccur = Notification.Name("applicationWideEventDidOccur")
}
