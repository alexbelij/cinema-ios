import Foundation
import os.log

public protocol StartupManager {
  func initialize(then completion: @escaping (AppDependencies) -> Void)
}

public class CinemaKitStartupManager: StartupManager {
  private static let logger = Logging.createLogger(category: "CinemaKitStartupManager")

  public init() {
  }

  public func initialize(then completion: @escaping (AppDependencies) -> Void) {
    completion(makeDependencies())
  }

  private func makeDependencies() -> AppDependencies {
    os_log("gathering dependencies", log: CinemaKitStartupManager.logger, type: .default)
    // Movie Library
    let url = directoryUrl(for: .documentDirectory).appendingPathComponent("cinema.data")
    moveLegacyLibraryFile(to: url)
    let dataFormat = KeyedArchivalFormat()
    dataFormat.defaultSchemaVersion = .v2_0_0
    let library = FileBasedMovieLibrary(url: url, dataFormat: dataFormat)

    // MovieDb Client
    let language = MovieDbLanguage(rawValue: Locale.current.languageCode ?? "en") ?? .en
    let country = MovieDbCountry(rawValue: Locale.current.regionCode ?? "US") ?? .unitedStates
    let movieDb = TMDBSwiftWrapper(language: language, country: country)

    return AppDependencies(library: library, movieDb: movieDb)
  }

  private func moveLegacyLibraryFile(to url: URL) {
    let legacyUrl = directoryUrl(for: .applicationSupportDirectory, createIfNecessary: false)
        .appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)
        .appendingPathComponent("cinema.data")
    if FileManager.default.fileExists(atPath: legacyUrl.path) {
      do {
        try FileManager.default.moveItem(at: legacyUrl, to: url)
        os_log("moved legacy library data file from 'Application Support' to 'Documents'",
               log: CinemaKitStartupManager.logger,
               type: .default)
      } catch {
        os_log("unable to move legacy library data file: %{public}@",
               log: CinemaKitStartupManager.logger,
               type: .fault,
               String(describing: error))
        fatalError("unable to move legacy library data file")
      }
    }
  }
}

func directoryUrl(for directory: FileManager.SearchPathDirectory,
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
