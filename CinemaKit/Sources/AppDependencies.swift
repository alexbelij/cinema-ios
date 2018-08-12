public protocol LibraryDependency {
  var library: MovieLibrary { get }
}

public protocol MovieDbDependency {
  var movieDb: MovieDbClient { get }
}

public struct AppDependencies: LibraryDependency, MovieDbDependency {
  public let library: MovieLibrary
  public let movieDb: MovieDbClient
}
