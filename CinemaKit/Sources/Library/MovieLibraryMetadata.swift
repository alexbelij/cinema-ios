import CloudKit

public struct MovieLibraryMetadata: DeviceSyncable {
  public let id: CKRecord.ID
  public var name: String
  public internal(set) var shareRecordID: CKRecord.ID?
  public internal(set) var currentUserCanModify: Bool

  init(from record: LibraryRecord, _ share: CKShare? = nil) {
    self.id = record.id
    self.name = record.name
    self.shareRecordID = record.shareID
    if let share = share {
      precondition(record.shareID == share.recordID)
      self.currentUserCanModify = share.currentUserParticipant?.permission == .readWrite
    } else {
      self.currentUserCanModify = true
    }
  }

  public init(name: String) {
    self.init(id: CKRecord.ID(recordName: UUID().uuidString, zoneID: deviceSyncZoneID), name: name)
  }

  init(id: CKRecord.ID, name: String) {
    self.id = id
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
  var databaseScope: CKDatabase.Scope {
    return isCurrentUserOwner ? .private : .shared
  }
}
