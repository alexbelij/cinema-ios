import Foundation

class PropertyUpdateAction: MaintenanceAction {

  private let library: MediaLibrary
  private let updates: [PropertyUpdate]
  private let updateSource: UpdateSource
  let progress = Progress(totalUnitCount: -1)

  init(library: MediaLibrary, updates: [PropertyUpdate], items: [MediaItem]? = nil) {
    self.library = library
    self.updates = updates
    if let items = items {
      self.updateSource = .only(items)
    } else {
      self.updateSource = .all
    }
  }

  func performAction(completion: (ActionResult<Void>) -> Void) {
    let itemsToUpdate: [MediaItem]
    switch updateSource {
      case .all: itemsToUpdate = library.mediaItems { _ in true }
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
    } catch let error {
      completion(.error(error))
    }
  }

  private enum UpdateSource {
    case all
    case only([MediaItem])
  }

}

protocol PropertyUpdate {
  func apply(on item: inout MediaItem)
}
