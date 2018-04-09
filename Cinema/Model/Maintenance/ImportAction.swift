import Foundation

class ImportAction: MaintenanceAction {

  private let library: MediaLibrary
  private let movieDb: MovieDbClient
  private let data: Data
  let progress = Progress(totalUnitCount: 8)

  init(library: MediaLibrary, movieDb: MovieDbClient, from data: Data) {
    self.library = library
    self.movieDb = movieDb
    self.data = data
  }

  func performAction(completion: (ActionResult<[MediaItem]>) -> Void) {
    do {
      let dataFormat = JSONFormat()
      progress.completedUnitCount += 1

      let itemsToImport = try dataFormat.deserialize(from: data)
      progress.completedUnitCount += 3

      let existingItems = self.library.fetchAllMediaItems()
      let newItems = itemsToImport.filter { itemToImport in
        !existingItems.contains { existingItem in
          itemToImport.tmdbID == existingItem.tmdbID
        }
      }
      progress.completedUnitCount += 2

      try self.library.performBatchUpdates {
        for item in newItems {
          try self.library.add(item)
        }
      }
      progress.completedUnitCount += 2

      completion(.result(Array(newItems)))
    } catch {
      completion(.error(error))
    }
  }
}
