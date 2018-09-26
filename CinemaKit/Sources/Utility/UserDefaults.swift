import Foundation

public struct UserDefaultsKey<Value> {
  public let rawKey: String

  public init(_ rawKey: String) {
    self.rawKey = rawKey
  }
}

public final class ObservationToken {
  private let invalidationHandler: () -> Void

  init(invalidationHandler: @escaping () -> Void) {
    self.invalidationHandler = invalidationHandler
  }

  deinit {
    invalidationHandler()
  }
}

public protocol UserDefaultsProtocol {
  func get<Value>(for key: UserDefaultsKey<Value>) -> Value?
  func set<Value>(_ value: Value?, for key: UserDefaultsKey<Value>)

  func clear()

  func observerValue<Value>(for key: UserDefaultsKey<Value>,
                            changeHandler: @escaping (Value?) -> Void) -> ObservationToken
}

extension UserDefaultsProtocol {
  public func get(for key: UserDefaultsKey<Bool>) -> Bool {
    return get(for: key) ?? false
  }

  public func removeValue<Value>(for key: UserDefaultsKey<Value>) {
    set(nil, for: key)
  }
}

protocol UserDefaultsDataStore {
  func get<Value>(for key: UserDefaultsKey<Value>) -> Value?
  func set<Value>(_ value: Value?, for key: UserDefaultsKey<Value>)

  func clear()
}

extension UserDefaults: UserDefaultsDataStore {
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

class StandardUserDefaults: UserDefaultsProtocol {
  private let queue = DispatchQueue(label: "de.martinbauer.cinema.UserDefaultsWrapper")
  private let dataStore: UserDefaultsDataStore
  private var changeHandlersByTokenID = [String: Any]()
  private var tokenIDsByKeys = [String: [String]]()

  init(dataStore: UserDefaultsDataStore = UserDefaults.standard) {
    self.dataStore = dataStore
  }

  func get<Value>(for key: UserDefaultsKey<Value>) -> Value? {
    return queue.sync {
      dataStore.get(for: key)
    }
  }

  func set<Value>(_ value: Value?, for key: UserDefaultsKey<Value>) {
    queue.sync {
      dataStore.set(value, for: key)
      tokenIDsByKeys[key.rawKey]?.forEach { tokenID in
        // swiftlint:disable:next force_cast
        let changeHandler = changeHandlersByTokenID[tokenID] as! (Value?) -> Void
        changeHandler(value)
      }
    }
  }

  func clear() {
    queue.sync {
      dataStore.clear()
    }
  }

  func observerValue<Value>(for key: UserDefaultsKey<Value>,
                            changeHandler: @escaping (Value?) -> Void) -> ObservationToken {
    return queue.sync {
      let tokenID = UUID().uuidString
      if tokenIDsByKeys[key.rawKey] == nil {
        tokenIDsByKeys[key.rawKey] = [tokenID]
      } else {
        tokenIDsByKeys[key.rawKey]!.append(tokenID)
      }
      changeHandlersByTokenID[tokenID] = changeHandler
      return ObservationToken { [weak self] in
        guard let `self` = self else { return }
        self.queue.sync {
          guard self.tokenIDsByKeys[key.rawKey] != nil else { return }
          if self.tokenIDsByKeys[key.rawKey]!.count == 1 {
            self.tokenIDsByKeys.removeValue(forKey: key.rawKey)
          } else if let index = self.tokenIDsByKeys[key.rawKey]?.index(of: tokenID) {
            self.tokenIDsByKeys[key.rawKey]?.remove(at: index)
          }
          self.changeHandlersByTokenID.removeValue(forKey: tokenID)
        }
      }
    }
  }
}
