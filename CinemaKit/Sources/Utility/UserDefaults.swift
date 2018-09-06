import Foundation

public struct UserDefaultsKey<Value> {
  public let rawKey: String

  public init(_ rawKey: String) {
    self.rawKey = rawKey
  }
}

public protocol UserDefaultsProtocol {
  func get<Value>(for key: UserDefaultsKey<Value>) -> Value?
  func set<Value>(_ value: Value?, for key: UserDefaultsKey<Value>)

  func clear()
}

extension UserDefaultsProtocol {
  public func get(for key: UserDefaultsKey<Bool>) -> Bool {
    return get(for: key) ?? false
  }

  public func removeValue<Value>(for key: UserDefaultsKey<Value>) {
    set(nil, for: key)
  }
}

extension UserDefaults: UserDefaultsProtocol {
  public func get<Value>(for key: UserDefaultsKey<Value>) -> Value? {
    guard let rawValue = value(forKey: key.rawKey) else { return nil }
    guard let value = rawValue as? Value else { fatalError("'\(rawValue)' can not be expressed as \(Value.self)") }
    return value
  }

  public func set<Value>(_ value: Value?, for key: UserDefaultsKey<Value>) {
    if let value = value {
      setValue(value, forKey: key.rawKey)
    } else {
      removeObject(forKey: key.rawKey)
    }
  }

  public func clear() {
    removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
  }
}
