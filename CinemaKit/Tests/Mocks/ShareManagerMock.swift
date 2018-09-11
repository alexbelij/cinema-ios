@testable import CinemaKit
import CloudKit

class ShareManagerMock: ShareManager {
  func saveShare(_ share: CKShare, with rootRecord: CKRecord, then completion: @escaping (CloudKitError?) -> Void) {
    fatalError("not implemented")
  }

  private var acceptShareHandlers = [() -> CloudKitError?]()

  func whenAcceptShare(_ handler: @escaping () -> CloudKitError?) {
    acceptShareHandlers.append(handler)
  }

  func acceptShare(with metadata: CKShareMetadataProtocol, then completion: @escaping (CloudKitError?) -> Void) {
    completion(acceptShareHandlers.removeFirst()())
  }

  private var fetchShareMetadataHandlers = [() -> ([CKShareMetadataProtocol]?, CloudKitError?)]()

  func whenFetchShareMetadata(_ handler: @escaping () -> ([CKShareMetadataProtocol]?, CloudKitError?)) {
    fetchShareMetadataHandlers.append(handler)
  }

  func fetchShareMetadata(for shares: [CKShare],
                          then completion: @escaping ([CKShareMetadataProtocol]?, CloudKitError?) -> Void) {
    let tuple = fetchShareMetadataHandlers.removeFirst()()
    completion(tuple.0, tuple.1)
  }
}

struct CKShareMetadataMock: CKShareMetadataProtocol {
  let share: CKShare
  let rootRecordID: CKRecordID
  let rootRecord: CKRecord?

  init(share: CKShare, rootRecordID: CKRecordID) {
    self.share = share
    self.rootRecordID = rootRecordID
    self.rootRecord = nil
  }

  init(share: CKShare, rootRecord: CKRecord) {
    self.share = share
    self.rootRecordID = rootRecord.recordID
    self.rootRecord = rootRecord
  }

  func asCKShareMetadata() -> CKShareMetadata {
    fatalError("mock can not be expressed as CKShareMetadata")
  }
}
