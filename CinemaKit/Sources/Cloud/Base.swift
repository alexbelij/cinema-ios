import CloudKit

protocol DeviceSyncable: Equatable {
  associatedtype CustomRecordType: RecordType

  var id: CKRecordID { get }

  init(from record: CustomRecordType)

  func setCustomFields(in record: CustomRecordType)
}

protocol RecordType: class {
  static var recordType: String { get }

  static func copyCustomFields(from source: CKRecord, to target: CKRecord)

  var rawRecord: CKRecord { get set }

  init(_ rawRecord: CKRecord)
}

extension RecordType {
  init(recordID: CKRecordID) {
    self.init(CKRecord(recordType: Self.recordType, recordID: recordID))
  }

  init<Element: DeviceSyncable>(from element: Element) where Element.CustomRecordType == Self {
    self.init(recordID: element.id)
    element.setCustomFields(in: self)
  }

  var id: CKRecordID {
    return rawRecord.recordID
  }
}
