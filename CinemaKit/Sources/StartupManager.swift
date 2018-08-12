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

    // Library Manager
    let libraryManager = OnePersistentMovieLibraryManager()

    // MovieDb Client
    let language = MovieDbLanguage(rawValue: Locale.current.languageCode ?? "en") ?? .en
    let country = MovieDbCountry(rawValue: Locale.current.regionCode ?? "US") ?? .unitedStates
    let movieDb = TMDBSwiftWrapper(language: language, country: country)

    return AppDependencies(libraryManager: libraryManager, movieDb: movieDb)
  }
}
