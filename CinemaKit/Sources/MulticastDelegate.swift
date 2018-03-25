import Foundation

public class MulticastDelegate<T> {

  private let delegates: NSHashTable<AnyObject> = NSHashTable<AnyObject>.weakObjects()

  public var count: Int {
    return delegates.allObjects.count
  }

  public var isEmpty: Bool {
    return delegates.allObjects.isEmpty
  }

  public func add(_ delegate: T) {
    delegates.add(delegate as AnyObject)
  }

  public func remove(_ delegate: T) {
    delegates.remove(delegate as AnyObject)
  }

  public func invoke(_ invocation: (T) -> Void) {
    for delegate in delegates.allObjects {
      // swiftlint:disable:next force_cast
      invocation(delegate as! T)
    }
  }
}
