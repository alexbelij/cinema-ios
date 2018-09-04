import CloudKit

public struct MovieLibraryMetadata: DeviceSyncable {
  public let id: CKRecordID
  public var name: String

  init(from record: LibraryRecord) {
    self.id = record.id
    self.name = record.name
  }

  public init(name: String) {
    self.id = CKRecordID(recordName: UUID().uuidString, zoneID: deviceSyncZoneID)
    self.name = name
  }

  func setCustomFields(in record: LibraryRecord) {
    precondition(record.id == id)
    record.name = name
  }
}
