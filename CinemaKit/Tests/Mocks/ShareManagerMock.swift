@testable import CinemaKit
import CloudKit

class ShareManagerMock: ShareManager {
  func saveShare(_ share: CKShare, with rootRecord: CKRecord, then completion: @escaping (CloudKitError?) -> Void) {
    fatalError("not implemented")
  }

  func acceptShare(with metadata: CKShareMetadata, then completion: @escaping (CloudKitError?) -> Void) {
    fatalError("not implemented")
  }

  func fetchShareMetadata(for shares: [CKShare],
                          then completion: @escaping ([CKShareMetadata]?, CloudKitError?) -> Void) {
    fatalError("not implemented")
  }
}
