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

  private var fetchRecordHandlers = [() -> (CKRecord?, CloudKitError?)]()

  func whenFetchRecord(_ handler: @escaping () -> (CKRecord?, CloudKitError?)) {
    fetchRecordHandlers.append(handler)
  }

  func fetchRecord(with recordID: CKRecordID,
                   in scope: CKDatabaseScope,
                   then completion: @escaping (CKRecord?, CloudKitError?) -> Void) {
    let tuple = fetchRecordHandlers.removeFirst()()
    completion(tuple.0, tuple.1)
  }
}
