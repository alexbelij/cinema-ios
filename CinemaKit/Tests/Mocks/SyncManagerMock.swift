@testable import CinemaKit
import CloudKit

class SyncManagerMock: SyncManager {
  private var syncHandlers = [() -> CloudKitError?]()

  func whenSync(_ handler: @escaping () -> CloudKitError?) {
    syncHandlers.append(handler)
  }

  func sync(_ record: CKRecord, in scope: CKDatabase.Scope, then completion: @escaping (CloudKitError?) -> Void) {
    completion(syncHandlers.removeFirst()())
  }

  func syncAll(_ records: [CKRecord], in scope: CKDatabase.Scope, then completion: @escaping (CloudKitError?) -> Void) {
    fatalError("not implemented")
  }

  private var deleteHandlers = [() -> CloudKitError?]()

  func whenDelete(_ handler: @escaping () -> CloudKitError?) {
    deleteHandlers.append(handler)
  }

  func delete(_ record: CKRecord, in scope: CKDatabase.Scope, then completion: @escaping (CloudKitError?) -> Void) {
    completion(deleteHandlers.removeFirst()())
  }

  var silentlyDeletedRecordIDs = [CKRecord.ID]()

  func delete(_ recordIDs: [CKRecord.ID], in scope: CKDatabase.Scope) {
    silentlyDeletedRecordIDs.append(contentsOf: recordIDs)
  }
}
