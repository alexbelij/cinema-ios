@testable import CinemaKit
import CloudKit

class ChangesManagerMock: ChangesManager {
  private let changes: FetchedChanges?
  private let error: CloudKitError?

  private init() {
    self.changes = nil
    self.error = nil
  }

  private init(changes: FetchedChanges) {
    self.changes = changes
    self.error = nil
  }

  private init(error: CloudKitError) {
    self.changes = nil
    self.error = error
  }

  func fetchChanges(then completion: @escaping (FetchedChanges?, CloudKitError?) -> Void) {
    if changes == nil && error == nil {
      fatalError("should not be called")
    }
    completion(changes, error)
  }
}

extension ChangesManagerMock {
  static func fetchAny() -> ChangesManagerMock {
    let changes = FetchedChanges(changedRecords: [CKRecord(recordType: "Dummy")])
    return ChangesManagerMock(changes: changes)
  }

  static func fetch(_ changes: FetchedChanges) -> ChangesManagerMock {
    return ChangesManagerMock(changes: changes)
  }

  static func fail(with error: CloudKitError) -> ChangesManagerMock {
    return ChangesManagerMock(error: error)
  }

  static func trap() -> ChangesManagerMock {
    return ChangesManagerMock()
  }
}
