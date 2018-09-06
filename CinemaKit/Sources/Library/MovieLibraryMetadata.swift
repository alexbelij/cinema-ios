import CloudKit

public struct MovieLibraryMetadata: DeviceSyncable {
  public let id: CKRecordID
  public var name: String
  public internal(set) var shareRecordID: CKRecordID?
  public internal(set) var currentUserCanModify: Bool

  init(from record: LibraryRecord, currentUserCanModify: Bool) {
    self.id = record.id
    self.name = record.name
    self.shareRecordID = record.shareID
    self.currentUserCanModify = currentUserCanModify
  }

  public init(name: String) {
    self.id = CKRecordID(recordName: UUID().uuidString, zoneID: deviceSyncZoneID)
    self.name = name
    self.shareRecordID = nil
    self.currentUserCanModify = true
  }

  public var isShared: Bool {
    return shareRecordID != nil
  }

  public var isCurrentUserOwner: Bool {
    guard let shareRecordID = shareRecordID else { return true }
    return shareRecordID.zoneID.ownerName == CKCurrentUserDefaultName
  }

  func setCustomFields(in record: LibraryRecord) {
    precondition(record.id == id)
    record.name = name
  }
}

extension MovieLibraryMetadata {
  var databaseScope: CKDatabaseScope {
    return isCurrentUserOwner ? .private : .shared
  }
}
