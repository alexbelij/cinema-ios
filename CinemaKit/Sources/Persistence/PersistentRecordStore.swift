import CloudKit

protocol PersistentRecordStore {
  func loadRecords(asCKShare: Bool) -> [CKRecord]?
  func save(_ records: [CKRecord])
  func clear()
}

extension PersistentRecordStore {
  func loadRecords() -> [CKRecord]? {
    return loadRecords(asCKShare: false)
  }
}

extension PersistentRecordStore {
  func save<CustomRecordType: RecordType>(_ records: [CustomRecordType]) {
    save(records.map { $0.rawRecord })
  }
}

class FileBasedRecordStore: PersistentRecordStore {
  private let fileURL: URL
  private let errorReporter: ErrorReporter

  init(fileURL: URL, errorReporter: ErrorReporter = LoggingErrorReporter.shared) {
    self.fileURL = fileURL
    self.errorReporter = errorReporter
  }

  func loadRecords(asCKShare: Bool) -> [CKRecord]? {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
    do {
      let urlData = try Data(contentsOf: fileURL)
      let decoder = PropertyListDecoder()
      return try decoder.decode([Data].self, from: urlData).map {
        let coder = NSKeyedUnarchiver(forReadingWith: $0)
        coder.requiresSecureCoding = true
        let record: CKRecord
        if asCKShare {
          record = CKShare(coder: coder)
        } else {
          record = CKRecord(coder: coder)!
        }
        coder.finishDecoding()
        return record
      }
    } catch {
      errorReporter.report(error)
      clear()
      return nil
    }
  }

  func save(_ records: [CKRecord]) {
    let data: [Data] = records.map {
      let data = NSMutableData()
      let coder = NSKeyedArchiver(forWritingWith: data)
      coder.requiresSecureCoding = true
      $0.encode(with: coder)
      coder.finishEncoding()
      return data as Data
    }
    do {
      let encoder = PropertyListEncoder()
      let encodedData = try encoder.encode(data)
      try encodedData.write(to: fileURL)
    } catch {
      errorReporter.report(error)
      clear()
    }
  }

  func clear() {
    if FileManager.default.fileExists(atPath: fileURL.path) {
      // swiftlint:disable:next force_try
      try! FileManager.default.removeItem(at: fileURL)
    }
  }
}
