import CloudKit
import Foundation

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
}

public enum MovieLibraryManagerError: Error {
}
