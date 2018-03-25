import Foundation

public class PropertyUpdateAction: MaintenanceAction {

  private let library: MediaLibrary
  private let updates: [PropertyUpdate]
  private let updateSource: UpdateSource
  public let progress = Progress(totalUnitCount: -1)

  public init(library: MediaLibrary, updates: [PropertyUpdate], items: [MediaItem]? = nil) {
    self.library = library
    self.updates = updates
    if let items = items {
      self.updateSource = .only(items)
    } else {
      self.updateSource = .all
    }
  }

  public func performAction(completion: (ActionResult<Void>) -> Void) {
    let itemsToUpdate: [MediaItem]
    switch updateSource {
      case .all: itemsToUpdate = library.fetchAllMediaItems()
      case let .only(items): itemsToUpdate = items
    }
    progress.totalUnitCount = Int64(itemsToUpdate.count)
    do {
      try library.performBatchUpdates {
        for item in itemsToUpdate {
          var updatedItem = item
          updates.forEach { $0.apply(on: &updatedItem) }
          try library.update(updatedItem)
          progress.completedUnitCount += 1
        }
      }
      completion(.result(()))
    } catch {
      completion(.error(error))
    }
  }

  private enum UpdateSource {
    case all
    case only([MediaItem])
  }

}

public protocol PropertyUpdate {
  func apply(on item: inout MediaItem)
}
