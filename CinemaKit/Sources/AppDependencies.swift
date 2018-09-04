import Foundation

public struct AppDependencies {
  public let libraryManager: MovieLibraryManager
  public let movieDb: MovieDbClient
  public let notificationCenter: NotificationCenter
}
