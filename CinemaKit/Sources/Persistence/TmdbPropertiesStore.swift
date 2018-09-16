import os.log

protocol TmdbPropertiesStore {
  func load() -> [TmdbIdentifier: Movie.TmdbProperties]?
  func save(_ properties: [TmdbIdentifier: Movie.TmdbProperties])
  func clear()
}

class FileBasedTmdbPropertiesStore: TmdbPropertiesStore {
  private static let logger = Logging.createLogger(category: "FileBasedTmdbPropertiesStore")

  private let fileURL: URL

  init(fileURL: URL) {
    self.fileURL = fileURL
  }

  func load() -> [TmdbIdentifier: Movie.TmdbProperties]? {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
    do {
      let urlData = try Data(contentsOf: fileURL)
      let decoder = JSONDecoder()
      let propertiesKeyedByInts = try decoder.decode([Int: Movie.TmdbProperties].self, from: urlData)
      let properties: [TmdbIdentifier: Movie.TmdbProperties]
          = Dictionary(uniqueKeysWithValues: propertiesKeyedByInts.map { (TmdbIdentifier(rawValue: $0.key), $0.value) })
      return properties
    } catch {
      os_log("data corrupted: %{public}@",
             log: FileBasedTmdbPropertiesStore.logger,
             type: .error,
             String(describing: error))
      clear()
      return nil
    }
  }

  func save(_ properties: [TmdbIdentifier: Movie.TmdbProperties]) {
    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      let propertiesKeyedByInts = Dictionary(uniqueKeysWithValues: properties.map { ($0.key.rawValue, $0.value) })
      let encodedData = try encoder.encode(propertiesKeyedByInts)
      try encodedData.write(to: fileURL)
    } catch {
      os_log("unable to save: %{public}@",
             log: FileBasedTmdbPropertiesStore.logger,
             type: .error,
             String(describing: error))
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
