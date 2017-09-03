import Foundation

class PropertyUpdateAction: MaintenanceAction {

  private let library: MediaLibrary
  private let updates: [PropertyUpdate]
  let progress = Progress(totalUnitCount: -1)

  init(library: MediaLibrary, updates: [PropertyUpdate]) {
    self.library = library
    self.updates = updates
  }

  func performAction(completion: (ActionResult<Void>) -> Void) {
    let itemsToUpdate = library.mediaItems { _ in true }
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
      completion(.result())
    } catch let error {
      completion(.error(error))
    }
  }

}

protocol PropertyUpdate {
  func apply(on item: inout MediaItem)
}
