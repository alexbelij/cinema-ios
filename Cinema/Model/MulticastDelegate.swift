import Foundation

class MulticastDelegate<T> {

  private let delegates: NSHashTable<AnyObject> = NSHashTable<AnyObject>.weakObjects()

  var count: Int {
    return delegates.allObjects.count
  }

  var isEmpty: Bool {
    return delegates.allObjects.isEmpty
  }

  func add(_ delegate: T) {
    delegates.add(delegate as AnyObject)
  }

  func remove(_ delegate: T) {
    delegates.remove(delegate as AnyObject)
  }

  func invoke(_ invocation: (T) -> Void) {
    for delegate in delegates.allObjects {
      // swiftlint:disable:next force_cast
      invocation(delegate as! T)
    }
  }
}
