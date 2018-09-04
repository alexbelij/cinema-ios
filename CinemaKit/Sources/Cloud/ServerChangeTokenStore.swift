import CloudKit
import os.log

protocol ServerChangeTokenStore {
  func get(for zoneID: CKRecordZoneID) -> CKServerChangeToken?
  func set(_ token: CKServerChangeToken?, for zoneID: CKRecordZoneID)
}

private extension CKRecordZoneID {
  var serverChangeTokenKey: String {
    return "\(ownerName)|\(zoneName)"
  }
}

class FileBasedServerChangeTokenStore: ServerChangeTokenStore {
  static let fileURL = directoryUrl(for: .applicationSupportDirectory)
      .appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)
      .appendingPathComponent("ServerChangeTokens.plist")
  private static let logger = Logging.createLogger(category: "ServerChangeTokenStore")

  private var tokens: [String: Data]

  init() {
    if FileManager.default.fileExists(atPath: FileBasedServerChangeTokenStore.fileURL.path) {
      do {
        let data = try Data(contentsOf: FileBasedServerChangeTokenStore.fileURL)
        let decoder = PropertyListDecoder()
        tokens = try decoder.decode([String: Data].self, from: data)
      } catch {
        os_log("unable to load data: %{public}@",
               log: FileBasedServerChangeTokenStore.logger,
               type: .fault,
               String(describing: error))
        fatalError("unable to load data")
      }
    } else {
      tokens = [:]
    }
  }

  func get(for zoneID: CKRecordZoneID) -> CKServerChangeToken? {
    return get(for: zoneID.serverChangeTokenKey)
  }

  func set(_ token: CKServerChangeToken?, for zoneID: CKRecordZoneID) {
    set(token, for: zoneID.serverChangeTokenKey)
  }

  private func get(for key: String) -> CKServerChangeToken? {
    guard let changeTokenData = tokens[key],
          let changeToken = NSKeyedUnarchiver.unarchiveObject(with: changeTokenData) as? CKServerChangeToken else {
      return nil
    }
    return changeToken
  }

  private func set(_ token: CKServerChangeToken?, for key: String) {
    if let newToken = token {
      let data = NSKeyedArchiver.archivedData(withRootObject: newToken)
      tokens[key] = data
    } else {
      tokens.removeValue(forKey: key)
    }
    writeToDisk()
  }

  private func writeToDisk() {
    do {
      let encoder = PropertyListEncoder()
      let data = try encoder.encode(tokens)
      FileManager.default.createFile(atPath: FileBasedServerChangeTokenStore.fileURL.path, contents: data)
    } catch {
      os_log("unable to store data: %{public}@",
             log: FileBasedServerChangeTokenStore.logger,
             type: .fault,
             String(describing: error))
      fatalError("unable to store data")
    }
  }
}