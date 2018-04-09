import Foundation

class ImportAndUpdateAction: MaintenanceAction {

  private let library: MediaLibrary
  private let movieDb: MovieDbClient
  private let url: URL
  let progress = Progress(totalUnitCount: -1)

  init(library: MediaLibrary, movieDb: MovieDbClient, from url: URL) {
    self.library = library
    self.movieDb = movieDb
    self.url = url
  }

  func performAction(completion: (ActionResult<[MediaItem]>) -> Void) {
    defer { try? FileManager.default.removeItem(at: url) }
    do {
      let dataFormat = JSONFormat()
      let data = try Data(contentsOf: url)
      let schemaVersion = try dataFormat.schemaVersion(of: data)

      let updates = Utils.updates(from: schemaVersion, using: movieDb)
      let hasUpdates = !updates.isEmpty
      progress.totalUnitCount = hasUpdates ? 10 : 1
      let importAction = ImportAction(library: library, movieDb: movieDb, from: data)
      progress.addChild(importAction.progress, withPendingUnitCount: 1)
      importAction.performAction { importResult in
        switch importResult {
          case let .error(error): completion(.error(error))
          case let .result(importedItems):
            guard hasUpdates else {
              completion(importResult)
              break
            }
            let updateAction = PropertyUpdateAction(library: library, updates: updates, items: importedItems)
            progress.addChild(updateAction.progress, withPendingUnitCount: 9)
            updateAction.performAction { updateResult in
              switch updateResult {
                case let .error(error): completion(.error(error))
                case .result: completion(.result(importedItems))
              }
            }
        }
      }
    } catch {
      completion(.error(error))
    }
  }

}
