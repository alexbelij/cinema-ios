@testable import CinemaKit
import CloudKit

class FetchManagerMock: FetchManager {
  func fetchZones(in scope: CKDatabaseScope,
                  then completion: @escaping ([CKRecordZoneID: CKRecordZone]?, CloudKitError?) -> Void) {
    fatalError("not implemented")
  }

  func fetch<CustomRecordType>(
      _ type: CustomRecordType.Type,
      matching predicate: NSPredicate,
      inZoneWithID zoneID: CKRecordZoneID,
      in scope: CKDatabaseScope,
      then completion: @escaping ([CustomRecordType]?, CloudKitError?) -> Void) where CustomRecordType: RecordType {
    fatalError("not implemented")
  }

  func fetchRecord(with recordID: CKRecordID,
                   in scope: CKDatabaseScope,
                   then completion: @escaping (CKRecord?, CloudKitError?) -> Void) {
    fatalError("not implemented")
  }
}
