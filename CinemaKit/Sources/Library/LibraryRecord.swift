import CloudKit

class LibraryRecord: RecordType {
  static let recordType: String = "Libraries"

  static func copyCustomFields(from source: CKRecord, to target: CKRecord) {
    target["name"] = source["name"]
  }

  var rawRecord: CKRecord

  // swiftlint:disable force_cast

  var name: String {
    get {
      return rawRecord[#function] as! String
    }
    set {
      rawRecord[#function] = newValue as CKRecordValue
    }
  }

  // swiftlint:enable force_cast

  required init(_ record: CKRecord) {
    rawRecord = record
  }
}
