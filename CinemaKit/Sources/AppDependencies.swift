import Foundation

public struct AppDependencies {
  public var libraryManager: MovieLibraryManager {
    return internalLibraryManager
  }
  let internalLibraryManager: InternalMovieLibraryManager
  public let movieDb: MovieDbClient
  public let notificationCenter: NotificationCenter

  init(libraryManager: InternalMovieLibraryManager, movieDb: MovieDbClient, notificationCenter: NotificationCenter) {
    self.internalLibraryManager = libraryManager
    self.movieDb = movieDb
    self.notificationCenter = notificationCenter
  }
}
