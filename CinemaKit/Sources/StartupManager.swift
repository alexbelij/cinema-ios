import Foundation
import os.log

public protocol StartupManager {
  func initialize(then completion: @escaping (AppDependencies) -> Void)
}

public class CinemaKitStartupManager: StartupManager {
  private static let logger = Logging.createLogger(category: "CinemaKitStartupManager")

  // directories
  private static let documentsDir = directoryUrl(for: .documentDirectory)
  private static let appSupportDir = directoryUrl(for: .applicationSupportDirectory)
      .appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)

  // cinema data file
  private static let libraryDataFileURL = documentsDir.appendingPathComponent("cinema.data")
  private static let legacyLibraryDataFileURL = appSupportDir.appendingPathComponent("cinema.data")

  public init() {
  }

  public func initialize(then completion: @escaping (AppDependencies) -> Void) {
    os_log("initializing CinemaKit", log: CinemaKitStartupManager.logger, type: .default)
    setUpDirectories()
    moveLegacyLibraryFile()
    let dependencies = makeDependencies()
    os_log("finished initializing CinemaKit", log: CinemaKitStartupManager.logger, type: .default)
    completion(dependencies)
  }

  private func setUpDirectories() {
    os_log("setting up directories", log: CinemaKitStartupManager.logger, type: .info)
    makeDirectory(at: CinemaKitStartupManager.documentsDir)
  }

  private func makeDirectory(at url: URL) {
    if FileManager.default.fileExists(atPath: url.path) { return }
    do {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    } catch {
      os_log("unable to create directory at %{public}@: %{public}@",
             log: CinemaKitStartupManager.logger,
             type: .fault,
             url.path,
             String(describing: error))
    }
  }

  private func moveLegacyLibraryFile() {
    os_log("searching for legacy library file", log: CinemaKitStartupManager.logger, type: .info)
    if FileManager.default.fileExists(atPath: CinemaKitStartupManager.legacyLibraryDataFileURL.path) {
      do {
        os_log("moving legacy library data file from 'Application Support' to 'Documents'",
               log: CinemaKitStartupManager.logger,
               type: .default)
        try FileManager.default.moveItem(at: CinemaKitStartupManager.legacyLibraryDataFileURL,
                                         to: CinemaKitStartupManager.libraryDataFileURL)
      } catch {
        os_log("unable to move legacy library data file: %{public}@",
               log: CinemaKitStartupManager.logger,
               type: .fault,
               String(describing: error))
        fatalError("unable to move legacy library data file")
      }
    }
  }

  private func makeDependencies() -> AppDependencies {
    os_log("gathering dependencies", log: CinemaKitStartupManager.logger, type: .info)

    // MovieDb Client
    let language = MovieDbLanguage(rawValue: Locale.current.languageCode ?? "en") ?? .en
    let country = MovieDbCountry(rawValue: Locale.current.regionCode ?? "US") ?? .unitedStates
    let movieDb = TMDBSwiftWrapper(language: language, country: country)

    // Library Manager
    let libraryManager = InMemoryMovieLibraryManager(libraryFactory: DefaultMovieLibraryFactory(tmdbWrapper: movieDb))

    return AppDependencies(libraryManager: libraryManager, movieDb: movieDb)
  }
}

private func directoryUrl(for directory: FileManager.SearchPathDirectory) -> URL {
  return FileManager.default.urls(for: directory, in: .userDomainMask).first!
}

private class DefaultMovieLibraryFactory: MovieLibraryFactory {
  private let tmdbWrapper: TMDBSwiftWrapper

  init(tmdbWrapper: TMDBSwiftWrapper) {
    self.tmdbWrapper = tmdbWrapper
  }

  func makeLibrary(with metadata: MovieLibraryMetadata) -> InternalMovieLibrary {
    return InMemoryMovieLibrary(metadata: metadata, movieProvider: tmdbWrapper)
  }
}
