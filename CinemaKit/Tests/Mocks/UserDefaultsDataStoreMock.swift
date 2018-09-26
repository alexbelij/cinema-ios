@testable import CinemaKit

class UserDefaultsDataStoreMock: UserDefaultsDataStore {
  var values = [String: Any]()

  func get<Value>(for key: UserDefaultsKey<Value>) -> Value? {
    return values[key.rawKey] as? Value
  }

  func set<Value>(_ value: Value?, for key: UserDefaultsKey<Value>) {
    values[key.rawKey] = value
  }

  func clear() {
    values.removeAll()
  }
}
