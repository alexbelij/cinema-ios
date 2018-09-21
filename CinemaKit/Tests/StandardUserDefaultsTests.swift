@testable import CinemaKit
import XCTest

class StandardUserDefaultsTests: XCTestCase {
  func testGetValueForExistingKey() {
    let key = UserDefaultsKey<String>("key")
    let defaultsMock = UserDefaultsMock()
    defaultsMock.values["key"] = "value"
    let defaults = StandardUserDefaults(userDefaults: defaultsMock)

    let value = defaults.get(for: key)

    XCTAssertEqual(value, "value")
  }

  func testGetValueForUnknownKey() {
    let key = UserDefaultsKey<String>("key")
    let defaultsMock = UserDefaultsMock()
    let defaults = StandardUserDefaults(userDefaults: defaultsMock)

    let value = defaults.get(for: key)

    XCTAssertNil(value)
  }

  func testSetValue() {
    let key = UserDefaultsKey<String>("key")
    let defaultsMock = UserDefaultsMock()
    let defaults = StandardUserDefaults(userDefaults: defaultsMock)

    defaults.set("Hello World!", for: key)

    XCTAssertEqual(defaultsMock.values["key"] as? String, "Hello World!")
  }

  func testSetNil() {
    let key = UserDefaultsKey<String>("key")
    let defaultsMock = UserDefaultsMock()
    defaultsMock.values["key"] = "value"
    let defaults = StandardUserDefaults(userDefaults: defaultsMock)

    defaults.set(nil, for: key)

    XCTAssertNil(defaultsMock.values["key"])
  }

  func testRemoveValue() {
    let key = UserDefaultsKey<String>("key")
    let defaultsMock = UserDefaultsMock()
    defaultsMock.values["key"] = "value"
    let defaults = StandardUserDefaults(userDefaults: defaultsMock)

    defaults.removeValue(for: key)

    XCTAssertNil(defaultsMock.values["key"])
  }

  func testClear() {
    let defaultsMock = UserDefaultsMock()
    defaultsMock.values["key"] = "value"
    let defaults = StandardUserDefaults(userDefaults: defaultsMock)

    defaults.clear()

    XCTAssertTrue(defaultsMock.values.isEmpty)
  }
}
