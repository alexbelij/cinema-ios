import CloudKit

let deviceSyncZoneID = CKRecordZoneID(zoneName: "deviceSyncZone", ownerName: CKCurrentUserDefaultName)

let defaultRetryCount = 2

enum CloudTarget: String, Codable {
  case deviceSyncZone
  case sharedDatabase
}
