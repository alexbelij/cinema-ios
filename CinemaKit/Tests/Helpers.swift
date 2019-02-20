@testable import CinemaKit
import CloudKit
import XCTest

// swiftlint:disable large_tuple

func makeRecordID() -> CKRecord.ID {
  return CKRecord.ID(recordName: UUID().uuidString, zoneID: deviceSyncZoneID)
}

final class SampleData {
  private init() {
  }

  static func librarySharedByDefaultUser() -> (LibraryRecord, LibraryRecord, CKShare) {
    return library(sharedInZoneWith: deviceSyncZoneID)
  }

  static func library(sharedBy ownerName: String) -> (LibraryRecord, LibraryRecord, CKShare) {
    return library(sharedInZoneWith: CKRecordZone.ID(zoneName: deviceSyncZoneID.zoneName, ownerName: ownerName))
  }

  private static func library(sharedInZoneWith zoneID: CKRecordZone.ID) -> (LibraryRecord, LibraryRecord, CKShare) {
    let libraryID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
    let privateLibraryRecord = LibraryRecord(from: MovieLibraryMetadata(id: libraryID, name: libraryID.recordName))
    let sharedRecord = privateLibraryRecord.rawRecord.copy() as! CKRecord
    let share = CKShare(rootRecord: sharedRecord, shareID: CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID))
    share[CKShare.SystemFieldKey.title] = "Title"
    share[CKShare.SystemFieldKey.shareType] = "Type"
    return (privateLibraryRecord, LibraryRecord(sharedRecord), share)
  }
}
