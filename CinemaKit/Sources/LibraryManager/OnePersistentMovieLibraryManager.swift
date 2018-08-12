import Foundation
import os.log

public class OnePersistentMovieLibraryManager: MovieLibraryManager {
  private static let logger = Logging.createLogger(category: "LibraryManager")
  public weak var delegate: MovieLibraryManagerDelegate?
  private var libraries: [UUID: InternalMovieLibrary]

  public init() {
    let metadata = MovieLibraryMetadata(name: NSLocalizedString("library", comment: ""))
    let url = directoryUrl(for: .documentDirectory).appendingPathComponent("cinema.data")
    OnePersistentMovieLibraryManager.moveLegacyLibraryFile(to: url)
    let dataFormat = KeyedArchivalFormat()
    dataFormat.defaultSchemaVersion = .v2_0_0
    let library = FileBasedMovieLibrary(metadata: metadata, url: url, dataFormat: dataFormat)
    libraries = [library.metadata.id: library]
  }

  private static func moveLegacyLibraryFile(to url: URL) {
    let legacyUrl = directoryUrl(for: .applicationSupportDirectory, createIfNecessary: false)
        .appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)
        .appendingPathComponent("cinema.data")
    if FileManager.default.fileExists(atPath: legacyUrl.path) {
      do {
        try FileManager.default.moveItem(at: legacyUrl, to: url)
        os_log("moved legacy library data file from 'Application Support' to 'Documents'",
               log: OnePersistentMovieLibraryManager.logger,
               type: .default)
      } catch {
        os_log("unable to move legacy library data file: %{public}@",
               log: OnePersistentMovieLibraryManager.logger,
               type: .fault,
               String(describing: error))
        fatalError("unable to move legacy library data file")
      }
    }
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

private func directoryUrl(for directory: FileManager.SearchPathDirectory,
                          createIfNecessary: Bool = true) -> URL {
  let fileManager = FileManager.default
  let dir = fileManager.urls(for: directory, in: .userDomainMask).first!
  do {
    var isDirectory: ObjCBool = false
    if !(FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDirectory)
         && isDirectory.boolValue) {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
    }
  } catch {
    fatalError("Could not create \(dir)")
  }
  return dir
}
