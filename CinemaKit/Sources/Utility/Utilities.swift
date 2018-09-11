import CloudKit
import Foundation

func directoryUrl(for directory: FileManager.SearchPathDirectory) -> URL {
  return FileManager.default.urls(for: directory, in: .userDomainMask).first!
}

extension CKShare {
  static let recordType = "cloudkit.share"
}

extension CKShareMetadata {
  var title: String? {
    return share[CKShareTitleKey] as? String
  }
}
