import Foundation

public struct AppDependencies {
  public var libraryManager: MovieLibraryManager {
    return internalLibraryManager
  }
  let internalLibraryManager: InternalMovieLibraryManager
  public let movieDb: MovieDbClient
  public let notificationCenter: NotificationCenter
  public let userDefaults: UserDefaultsProtocol
  public let errorReporter: ErrorReporter

  init(libraryManager: InternalMovieLibraryManager,
       movieDb: MovieDbClient,
       notificationCenter: NotificationCenter,
       userDefaults: UserDefaultsProtocol,
       errorReporter: ErrorReporter) {
    self.internalLibraryManager = libraryManager
    self.movieDb = movieDb
    self.notificationCenter = notificationCenter
    self.userDefaults = userDefaults
    self.errorReporter = errorReporter
  }
}
