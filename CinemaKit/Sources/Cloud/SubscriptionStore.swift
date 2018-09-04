import CloudKit
import os.log

protocol SubscriptionStore {
  func hasSubscribedTo(_ target: CloudTarget) -> Bool
  func setHasSubscribedTo(_ target: CloudTarget)
}

class FileBasedSubscriptionStore: SubscriptionStore {
  static let fileURL = directoryUrl(for: .applicationSupportDirectory)
      .appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)
      .appendingPathComponent("Subscriptions.plist")
  private static let logger = Logging.createLogger(category: "SubscriptionStore")

  private var targets: Set<CloudTarget>

  init() {
    if FileManager.default.fileExists(atPath: FileBasedSubscriptionStore.fileURL.path) {
      do {
        let data = try Data(contentsOf: FileBasedSubscriptionStore.fileURL)
        let decoder = PropertyListDecoder()
        targets = Set(try decoder.decode([CloudTarget].self, from: data))
      } catch {
        os_log("unable to load data: %{public}@",
               log: FileBasedSubscriptionStore.logger,
               type: .fault,
               String(describing: error))
        fatalError("unable to load data")
      }
    } else {
      targets = []
    }
  }

  func hasSubscribedTo(_ target: CloudTarget) -> Bool {
    return targets.contains(target)
  }

  func setHasSubscribedTo(_ target: CloudTarget) {
    targets.insert(target)
    writeToDisk()
  }

  private func writeToDisk() {
    do {
      let encoder = PropertyListEncoder()
      let data = try encoder.encode(targets)
      FileManager.default.createFile(atPath: FileBasedSubscriptionStore.fileURL.path, contents: data)
    } catch {
      os_log("unable to store data: %{public}@",
             log: FileBasedSubscriptionStore.logger,
             type: .fault,
             String(describing: error))
      fatalError("unable to store data")
    }
  }
}
