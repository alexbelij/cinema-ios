import Foundation
import os.log

public class OnePersistentMovieLibraryManager: MovieLibraryManager {
  public weak var delegate: MovieLibraryManagerDelegate?
  private var libraries: [UUID: InternalMovieLibrary]

  public init(url: URL) {
    let metadata = MovieLibraryMetadata(name: NSLocalizedString("library", comment: ""))
    let dataFormat = KeyedArchivalFormat()
    dataFormat.defaultSchemaVersion = .v2_0_0
    let library = FileBasedMovieLibrary(metadata: metadata, url: url, dataFormat: dataFormat)
    libraries = [library.metadata.id: library]
  }

  public var libraryCount: Int {
    return libraries.count
  }

  public func fetchLibraries(
      then completion: @escaping (AsyncResult<[MovieLibrary], MovieLibraryManagerError>) -> Void) {
    completion(.success(Array(libraries.values)))
  }

  public func addLibrary(with metadata: MovieLibraryMetadata,
                         then completion: @escaping (AsyncResult<MovieLibrary, MovieLibraryManagerError>) -> Void) {
    let library = InMemoryMovieLibrary(metadata: metadata)
    libraries[metadata.id] = library
    delegate?.libraryManager(self, didAdd: library)
    completion(.success(library))
  }

  public func updateLibrary(with metadata: MovieLibraryMetadata,
                            then completion: @escaping (AsyncResult<Void, MovieLibraryManagerError>) -> Void) {
    let library = libraries[metadata.id]!
    library.metadata = metadata
    delegate?.libraryManager(self, didUpdate: library)
    completion(.success(()))
  }

  public func removeLibrary(withID id: UUID,
                            then completion: @escaping (AsyncResult<Void, MovieLibraryManagerError>) -> Void) {
    let library = libraries.removeValue(forKey: id)!
    delegate?.libraryManager(self, didRemove: library)
    completion(.success(()))
  }
}
