import CloudKit
import Foundation
import os.log

protocol MovieLibraryFactory {
  func makeLibrary(with metadata: MovieLibraryMetadata) -> InternalMovieLibrary
}

class InMemoryMovieLibraryManager: MovieLibraryManager {
  weak var delegate: MovieLibraryManagerDelegate?
  private let libraryFactory: MovieLibraryFactory
  private var libraries: [CKRecordID: InternalMovieLibrary]

  init(libraryFactory: MovieLibraryFactory) {
    self.libraryFactory = libraryFactory
    let library = libraryFactory.makeLibrary(with: MovieLibraryMetadata(name: "__Unnamed__"))
    libraries = [library.metadata.id: library]
  }

  var libraryCount: Int {
    return libraries.count
  }

  func fetchLibraries(
      then completion: @escaping (Result<[MovieLibrary], MovieLibraryManagerError>) -> Void) {
    completion(.success(Array(libraries.values)))
  }

  func addLibrary(with metadata: MovieLibraryMetadata,
                  then completion: @escaping (Result<MovieLibrary, MovieLibraryManagerError>) -> Void) {
    let library = libraryFactory.makeLibrary(with: metadata)
    libraries[metadata.id] = library
    delegate?.libraryManager(self, didAdd: library)
    completion(.success(library))
  }

  func updateLibrary(with metadata: MovieLibraryMetadata,
                     then completion: @escaping (Result<MovieLibrary, MovieLibraryManagerError>) -> Void) {
    let library = libraries[metadata.id]!
    library.metadata = metadata
    delegate?.libraryManager(self, didUpdate: library)
    completion(.success(library))
  }

  func removeLibrary(with id: CKRecordID,
                     then completion: @escaping (Result<Void, MovieLibraryManagerError>) -> Void) {
    let library = libraries.removeValue(forKey: id)!
    delegate?.libraryManager(self, didRemove: library)
    completion(.success(()))
  }
}
