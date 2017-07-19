import Foundation

enum Config {

  /// Usage
  /// ```
  ///   --library sample
  ///   --library fileBased
  /// ```
  static func initLibrary(launchArguments: [String]) -> MediaLibrary {
    let arguments = launchArguments.contains(LibraryArgument.flag) ? launchArguments : LibraryArgument.defaultArguments
    guard let startIndex = arguments.index(of: LibraryArgument.flag) else { fatalError("missing library argument") }
    guard let libraryType = LibraryArgument(rawValue: arguments[orEmptyAt: startIndex + 1]) else {
      fatalError("unsupported library '\(arguments[orEmptyAt: startIndex + 1])'")
    }
    let library: MediaLibrary
    switch libraryType {
      case .sample:
        library = SampleLibrary()
      case .fileBased:
        do {
          library = try FileBasedMediaLibrary(directory: Utils.applicationSupportDirectory(),
                                              fileName: "cinema.data",
                                              dataFormat: KeyedArchivalFormat())
        } catch let error {
          fatalError("Library could not be instantiated: \(error)")
        }
    }
    return library
  }

  /// Usage
  /// ```
  ///   --movie-db tmdbSwiftWrapper [--cached]
  /// ```
  static func initMovieDb(launchArguments: [String]) -> MovieDbClient {
    let arguments = launchArguments.contains(MovieDbArgument.flag) ? launchArguments : MovieDbArgument.defaultArguments
    guard let startIndex = arguments.index(of: MovieDbArgument.flag) else { fatalError("missing movie-db argument") }
    guard let movieDbType = MovieDbArgument(rawValue: arguments[orEmptyAt: startIndex + 1]) else {
      fatalError("unsupported movie db '\(arguments[orEmptyAt: startIndex + 1])'")
    }
    let movieDb: MovieDbClient
    switch movieDbType {
      case .tmdbSwiftWrapper:
        if arguments[orEmptyAt: startIndex + 2] == MovieDbArgument.Options.cached.rawValue {
          movieDb = CachingMovieDbClient(backingClient: TMDBSwiftWrapper(storeFront: .germany))
        } else {
          movieDb = TMDBSwiftWrapper(storeFront: .germany)
        }
    }
    return movieDb
  }
}

private extension Array where Iterator.Element == String {
  subscript(orEmptyAt index: Int) -> String {
    get {
      guard self.count >= index else { return "" }
      return self[index]
    }
  }
}

fileprivate enum LibraryArgument: String {
  static let defaultArguments = [flag, fileBased.rawValue]
  static let flag = "--library"

  case sample
  case fileBased
}

fileprivate enum MovieDbArgument: String {
  static let defaultArguments = [flag, tmdbSwiftWrapper.rawValue, Options.cached.rawValue]
  static let flag = "--movie-db"

  case tmdbSwiftWrapper

  enum Options: String {
    case cached = "--cached"
  }
}
