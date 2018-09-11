@testable import CinemaKit
import CloudKit

class ShareManagerMock: ShareManager {
  func saveShare(_ share: CKShare, with rootRecord: CKRecord, then completion: @escaping (CloudKitError?) -> Void) {
    fatalError("not implemented")
  }

  func acceptShare(with metadata: CKShareMetadataProtocol, then completion: @escaping (CloudKitError?) -> Void) {
    fatalError("not implemented")
  }

  func fetchShareMetadata(for shares: [CKShare],
                          then completion: @escaping ([CKShareMetadataProtocol]?, CloudKitError?) -> Void) {
    fatalError("not implemented")
  }
}
