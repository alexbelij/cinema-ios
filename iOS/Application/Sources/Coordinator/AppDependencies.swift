import CinemaKit

struct AppDependencies: LibraryDependency, MovieDbDependency {
  let library: MovieLibrary
  let movieDb: MovieDbClient
}

protocol LibraryDependency {
  var library: MovieLibrary { get }
}

protocol MovieDbDependency {
  var movieDb: MovieDbClient { get }
}
