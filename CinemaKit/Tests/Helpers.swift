@testable import CinemaKit
import CloudKit
import XCTest

func makeRecordID() -> CKRecordID {
  return CKRecordID(recordName: UUID().uuidString, zoneID: deviceSyncZoneID)
}

final class SampleData {
  private init() {
  }

  static func librarySharedByDefaultUser() -> (LibraryRecord, LibraryRecord, CKShare) {
    return library(sharedInZoneWith: deviceSyncZoneID)
  }

  static func library(sharedBy ownerName: String) -> (LibraryRecord, LibraryRecord, CKShare) {
    return library(sharedInZoneWith: CKRecordZoneID(zoneName: deviceSyncZoneID.zoneName, ownerName: ownerName))
  }

  private static func library(sharedInZoneWith zoneID: CKRecordZoneID) -> (LibraryRecord, LibraryRecord, CKShare) {
    let libraryID = CKRecordID(recordName: UUID().uuidString, zoneID: zoneID)
    let privateLibraryRecord = LibraryRecord(from: MovieLibraryMetadata(id: libraryID, name: libraryID.recordName))
    let sharedRecord = privateLibraryRecord.rawRecord.copy() as! CKRecord
    let share = CKShare(rootRecord: sharedRecord, shareID: CKRecordID(recordName: UUID().uuidString, zoneID: zoneID))
    share[CKShareTitleKey] = "Title" as CKRecordValue
    share[CKShareTypeKey] = "Type" as CKRecordValue
    return (privateLibraryRecord, LibraryRecord(sharedRecord), share)
  }
}
