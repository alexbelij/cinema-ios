import CloudKit
import Foundation
import UIKit

public protocol MovieLibraryManagerDelegate: class {
  func libraryManager(_ libraryManager: MovieLibraryManager,
                      didUpdateLibraries changeSet: ChangeSet<CKRecordID, MovieLibrary>)
}

public protocol MovieLibraryManager: class {
  var delegates: MulticastDelegate<MovieLibraryManagerDelegate> { get }

  // accessing library content
  func fetchLibraries(then completion: @escaping (Result<[MovieLibrary], MovieLibraryManagerError>) -> Void)

  // managing library content
  func addLibrary(with metadata: MovieLibraryMetadata,
                  then completion: @escaping (Result<MovieLibrary, MovieLibraryManagerError>) -> Void)
  func updateLibrary(with metadata: MovieLibraryMetadata,
                     then completion: @escaping (Result<MovieLibrary, MovieLibraryManagerError>) -> Void)
  func removeLibrary(with id: CKRecordID, then completion: @escaping (Result<Void, MovieLibraryManagerError>) -> Void)

  func fetchChanges(then completion: @escaping (UIBackgroundFetchResult) -> Void)
}

public enum MovieLibraryManagerError: Error {
  case globalError(ApplicationWideEvent)
  case nonRecoverableError
  case libraryDoesNotExist
}

extension CloudKitError {
  var asMovieLibraryManagerError: MovieLibraryManagerError {
    switch self {
      case .itemNoLongerExists:
        return .libraryDoesNotExist
      case .notAuthenticated:
        return .globalError(.notAuthenticated)
      case .userDeletedZone:
        return .globalError(.userDeletedZone)
      case .nonRecoverableError:
        return .nonRecoverableError
      case .conflict, .zoneNotFound:
        fatalError("\(self) can not be expressed as MovieLibraryManagerError")
    }
  }
}
