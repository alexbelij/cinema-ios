import CloudKit

class MovieRecord: RecordType {
  static let recordType: CKRecord.RecordType = "Movies"

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
      rawRecord[#function] = newValue
    }
  }
  var title: String {
    get {
      return rawRecord[#function] as! String
    }
    set {
      rawRecord[#function] = newValue
    }
  }
  var subtitle: String? {
    get {
      return rawRecord[#function] as? String
    }
    set {
      rawRecord[#function] = newValue
    }
  }
  var diskType: String {
    get {
      return rawRecord[#function] as! String
    }
    set {
      rawRecord[#function] = newValue
    }
  }
  var library: CKRecord.Reference {
    get {
      return rawRecord[#function] as! CKRecord.Reference
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
  static func queryPredicate(forMoviesInLibraryWithID id: CKRecord.ID) -> NSPredicate {
    let reference = CKRecord.Reference(recordID: id, action: .deleteSelf)
    return NSPredicate(format: "library == %@", reference)
  }
}
