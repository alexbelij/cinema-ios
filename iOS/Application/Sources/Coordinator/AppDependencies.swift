import CinemaKit

struct AppDependencies: LibraryDependency, MovieDbDependency {
  let library: MediaLibrary
  let movieDb: MovieDbClient
}

protocol LibraryDependency {
  var library: MediaLibrary { get }
}

protocol MovieDbDependency {
  var movieDb: MovieDbClient { get }
}
