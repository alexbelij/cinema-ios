import Foundation

public protocol MovieLibraryManagerDelegate: class {
  func libraryManager(_ libraryManager: MovieLibraryManager, didAdd library: MovieLibrary)
  func libraryManager(_ libraryManager: MovieLibraryManager, didUpdate library: MovieLibrary)
  func libraryManager(_ libraryManager: MovieLibraryManager, didRemove library: MovieLibrary)
}

public protocol MovieLibraryManager: class {
  var delegate: MovieLibraryManagerDelegate? { get set }

  // accessing library content
  func fetchLibraries(then completion: @escaping (AsyncResult<[MovieLibrary], MovieLibraryManagerError>) -> Void)

  // getting information about the library
  var libraryCount: Int { get }

  // managing library content
  func addLibrary(with metadata: MovieLibraryMetadata,
                  then completion: @escaping (AsyncResult<MovieLibrary, MovieLibraryManagerError>) -> Void)
  func updateLibrary(with metadata: MovieLibraryMetadata,
                     then completion: @escaping (AsyncResult<Void, MovieLibraryManagerError>) -> Void)
  func removeLibrary(withID id: UUID, then completion: @escaping (AsyncResult<Void, MovieLibraryManagerError>) -> Void)
}

public enum MovieLibraryManagerError: Error {
}
