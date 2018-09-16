@testable import CinemaKit
import CloudKit

class FetchManagerMock: FetchManager {
  func fetchZones(in scope: CKDatabase.Scope,
                  then completion: @escaping ([CKRecordZone.ID: CKRecordZone]?, CloudKitError?) -> Void) {
    fatalError("not implemented")
  }

  func fetch<CustomRecordType>(
      _ type: CustomRecordType.Type,
      matching predicate: NSPredicate,
      inZoneWithID zoneID: CKRecordZone.ID,
      in scope: CKDatabase.Scope,
      then completion: @escaping ([CustomRecordType]?, CloudKitError?) -> Void) where CustomRecordType: RecordType {
    fatalError("not implemented")
  }

  private var fetchRecordHandlers = [() -> (CKRecord?, CloudKitError?)]()

  func whenFetchRecord(_ handler: @escaping () -> (CKRecord?, CloudKitError?)) {
    fetchRecordHandlers.append(handler)
  }

  func fetchRecord(with recordID: CKRecord.ID,
                   in scope: CKDatabase.Scope,
                   then completion: @escaping (CKRecord?, CloudKitError?) -> Void) {
    let tuple = fetchRecordHandlers.removeFirst()()
    completion(tuple.0, tuple.1)
  }
}
