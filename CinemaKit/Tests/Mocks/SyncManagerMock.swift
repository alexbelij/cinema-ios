@testable import CinemaKit
import CloudKit

class SyncManagerMock: SyncManager {
  private var syncHandlers = [() -> CloudKitError?]()

  func whenSync(_ handler: @escaping () -> CloudKitError?) {
    syncHandlers.append(handler)
  }

  func sync(_ record: CKRecord, in scope: CKDatabaseScope, then completion: @escaping (CloudKitError?) -> Void) {
    completion(syncHandlers.removeFirst()())
  }

  func syncAll(_ records: [CKRecord], in scope: CKDatabaseScope, then completion: @escaping (CloudKitError?) -> Void) {
    fatalError("not implemented")
  }

  private var deleteHandlers = [() -> CloudKitError?]()

  func whenDelete(_ handler: @escaping () -> CloudKitError?) {
    deleteHandlers.append(handler)
  }

  func delete(_ record: CKRecord, in scope: CKDatabaseScope, then completion: @escaping (CloudKitError?) -> Void) {
    completion(deleteHandlers.removeFirst()())
  }

  var silentlyDeletedRecordIDs = [CKRecordID]()

  func delete(_ recordIDs: [CKRecordID], in scope: CKDatabaseScope) {
    silentlyDeletedRecordIDs.append(contentsOf: recordIDs)
  }
}
