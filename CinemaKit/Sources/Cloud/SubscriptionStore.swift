import CloudKit

protocol SubscriptionStore {
  func hasSubscribedTo(_ target: SubscriptionTarget) -> Bool
  func setHasSubscribedTo(_ target: SubscriptionTarget)
}

class FileBasedSubscriptionStore: SubscriptionStore {
  static let fileURL = directoryUrl(for: .applicationSupportDirectory)
      .appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)
      .appendingPathComponent("Subscriptions.plist")
  private var targets: Set<SubscriptionTarget>
  private let errorReporter: ErrorReporter

  init(errorReporter: ErrorReporter = LoggingErrorReporter.shared) {
    self.errorReporter = errorReporter
    if FileManager.default.fileExists(atPath: FileBasedSubscriptionStore.fileURL.path) {
      do {
        let data = try Data(contentsOf: FileBasedSubscriptionStore.fileURL)
        let decoder = PropertyListDecoder()
        targets = Set(try decoder.decode([SubscriptionTarget].self, from: data))
      } catch {
        errorReporter.report(error)
        fatalError("unable to load data")
      }
    } else {
      targets = []
    }
  }

  func hasSubscribedTo(_ target: SubscriptionTarget) -> Bool {
    return targets.contains(target)
  }

  func setHasSubscribedTo(_ target: SubscriptionTarget) {
    targets.insert(target)
    writeToDisk()
  }

  private func writeToDisk() {
    do {
      let encoder = PropertyListEncoder()
      let data = try encoder.encode(targets)
      FileManager.default.createFile(atPath: FileBasedSubscriptionStore.fileURL.path, contents: data)
    } catch {
      errorReporter.report(error)
      fatalError("unable to store data")
    }
  }
}
