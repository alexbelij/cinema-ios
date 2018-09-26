@testable import CinemaKit
import XCTest

class StandardUserDefaultsTests: XCTestCase {
  func testGetValueForExistingKey() {
    let key = UserDefaultsKey<String>("key")
    let dataStoreMock = UserDefaultsDataStoreMock()
    dataStoreMock.values["key"] = "value"
    let defaults = StandardUserDefaults(dataStore: dataStoreMock)

    let value = defaults.get(for: key)

    XCTAssertEqual(value, "value")
  }

  func testGetValueForUnknownKey() {
    let key = UserDefaultsKey<String>("key")
    let dataStoreMock = UserDefaultsDataStoreMock()
    let defaults = StandardUserDefaults(dataStore: dataStoreMock)

    let value = defaults.get(for: key)

    XCTAssertNil(value)
  }

  func testSetValue() {
    let key = UserDefaultsKey<String>("key")
    let dataStoreMock = UserDefaultsDataStoreMock()
    let defaults = StandardUserDefaults(dataStore: dataStoreMock)

    defaults.set("Hello World!", for: key)

    XCTAssertEqual(dataStoreMock.values["key"] as? String, "Hello World!")
  }

  func testSetNil() {
    let key = UserDefaultsKey<String>("key")
    let dataStoreMock = UserDefaultsDataStoreMock()
    dataStoreMock.values["key"] = "value"
    let defaults = StandardUserDefaults(dataStore: dataStoreMock)

    defaults.set(nil, for: key)

    XCTAssertNil(dataStoreMock.values["key"])
  }

  func testRemoveValue() {
    let key = UserDefaultsKey<String>("key")
    let dataStoreMock = UserDefaultsDataStoreMock()
    dataStoreMock.values["key"] = "value"
    let defaults = StandardUserDefaults(dataStore: dataStoreMock)

    defaults.removeValue(for: key)

    XCTAssertNil(dataStoreMock.values["key"])
  }

  func testClear() {
    let dataStoreMock = UserDefaultsDataStoreMock()
    dataStoreMock.values["key"] = "value"
    let defaults = StandardUserDefaults(dataStore: dataStoreMock)

    defaults.clear()

    XCTAssertTrue(dataStoreMock.values.isEmpty)
  }

  func testObserveValue() {
    let key = UserDefaultsKey<String>("key")
    let dataStoreMock = UserDefaultsDataStoreMock()
    dataStoreMock.values["key"] = "value1"
    let defaults = StandardUserDefaults(dataStore: dataStoreMock)

    var value: String?
    let expectation = self.expectation(description: "observation")
    let token = defaults.observerValue(for: key) {
      value = $0
      expectation.fulfill()
    }
    _ = token // silence never used warning
    defaults.set("value2", for: key)
    waitForExpectations(timeout: 0.1)

    XCTAssertEqual(value, "value2")
  }

  func testObserveValueTwice() {
    let key = UserDefaultsKey<String>("key")
    let dataStoreMock = UserDefaultsDataStoreMock()
    dataStoreMock.values["key"] = "value1"
    let defaults = StandardUserDefaults(dataStore: dataStoreMock)

    var value1: String?
    let expectation1 = self.expectation(description: "observation1")
    let token1 = defaults.observerValue(for: key) {
      value1 = $0
      expectation1.fulfill()
    }
    _ = token1 // silence never used warning
    var value2: String?
    let expectation2 = self.expectation(description: "observation2")
    let token2 = defaults.observerValue(for: key) {
      value2 = $0
      expectation2.fulfill()
    }
    _ = token2 // silence never used warning
    defaults.set("value2", for: key)
    waitForExpectations(timeout: 0.1)

    XCTAssertEqual(value1, "value2")
    XCTAssertEqual(value2, "value2")
  }

  func testObserveValueWithInvalidation() {
    let key = UserDefaultsKey<String>("key")
    let dataStoreMock = UserDefaultsDataStoreMock()
    dataStoreMock.values["key"] = "value1"
    let defaults = StandardUserDefaults(dataStore: dataStoreMock)

    var value: String?
    let expectation = self.expectation(description: "observation")
    var token: ObservationToken? = defaults.observerValue(for: key) {
      value = $0
      expectation.fulfill()
    }
    _ = token // silence never read warning
    defaults.set("value2", for: key)
    token = nil
    defaults.set("value3", for: key)
    waitForExpectations(timeout: 0.1)

    XCTAssertEqual(value, "value2")
  }
}
