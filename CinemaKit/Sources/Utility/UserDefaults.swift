import Foundation

public protocol UserDefaultsProtocol {
  func set(_ value: Any?, forKey defaultName: String)

  func bool(forKey defaultName: String) -> Bool
  func string(forKey defaultName: String) -> String?
  func data(forKey defaultName: String) -> Data?

  func removeObject(forKey defaultName: String)

  func clear()
}

extension UserDefaults: UserDefaultsProtocol {
  public func clear() {
    removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
  }
}
