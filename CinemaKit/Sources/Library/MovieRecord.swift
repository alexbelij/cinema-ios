import CloudKit

class MovieRecord: RecordType {
  static let recordType: String = "Movies"

  static func copyCustomFields(from source: CKRecord, to target: CKRecord) {
    target["tmdbID"] = source["tmdbID"]
    target["title"] = source["title"]
    target["subtitle"] = source["subtitle"]
    target["diskType"] = source["diskType"]
    target["library"] = source["library"]
  }

  var rawRecord: CKRecord

  // swiftlint:disable force_cast

  var tmdbID: Int {
    get {
      return rawRecord[#function] as! Int
    }
    set {
      rawRecord[#function] = newValue as CKRecordValue
    }
  }
  var title: String {
    get {
      return rawRecord[#function] as! String
    }
    set {
      rawRecord[#function] = newValue as CKRecordValue
    }
  }
  var subtitle: String? {
    get {
      return rawRecord[#function] as? String
    }
    set {
      rawRecord[#function] = newValue as CKRecordValue?
    }
  }
  var diskType: String {
    get {
      return rawRecord[#function] as! String
    }
    set {
      rawRecord[#function] = newValue as CKRecordValue
    }
  }
  var library: CKReference {
    get {
      return rawRecord[#function] as! CKReference
    }
    set {
      rawRecord[#function] = newValue
      rawRecord.setParent(newValue.recordID)
    }
  }

  // swiftlint:enable force_cast

  required init(_ record: CKRecord) {
    rawRecord = record
  }
}

extension MovieRecord {
  static func queryPredicate(forMoviesInLibraryWithID id: CKRecordID) -> NSPredicate {
    let reference = CKReference(recordID: id, action: .deleteSelf)
    return NSPredicate(format: "library == %@", reference)
  }
}
