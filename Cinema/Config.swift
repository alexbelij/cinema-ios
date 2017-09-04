import Foundation

enum Config {

  /// Usage
  /// ```
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
      case .fileBased:
        let url = Utils.directoryUrl(for: .documentDirectory).appendingPathComponent("cinema.data")
        moveLegacyLibraryFile(to: url)
        let dataFormat = KeyedArchivalFormat()
        dataFormat.defaultSchemaVersion = .v2_0_0
        do {
          library = try FileBasedMediaLibrary(url: url, dataFormat: dataFormat)
        } catch let error {
          fatalError("Library could not be instantiated: \(error)")
        }
    }
    return library
  }

  private static func moveLegacyLibraryFile(to url: URL) {
    let legacyUrl = Utils.directoryUrl(for: .applicationSupportDirectory, createIfNecessary: false)
                         .appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)
                         .appendingPathComponent("cinema.data")
    if FileManager.default.fileExists(atPath: legacyUrl.path) {
      do {
        try FileManager.default.moveItem(at: legacyUrl, to: url)
      } catch let error {
        fatalError("could not move library file: \(error)")
      }
    }
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
        let language = MovieDbLanguage(rawValue: Locale.current.languageCode ?? "en") ?? .en
        if arguments[orEmptyAt: startIndex + 2] == MovieDbArgument.Options.cached.rawValue {
          movieDb = TMDBSwiftWrapper(language: language, cache: StandardTMDBSwiftCache())
        } else {
          movieDb = TMDBSwiftWrapper(language: language, cache: EmptyTMDBSwiftCache())
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

private enum LibraryArgument: String {
  static let defaultArguments = [flag, fileBased.rawValue]
  static let flag = "--library"

  case fileBased
}

private enum MovieDbArgument: String {
  static let defaultArguments = [flag, tmdbSwiftWrapper.rawValue, Options.cached.rawValue]
  static let flag = "--movie-db"

  case tmdbSwiftWrapper

  enum Options: String {
    case cached = "--cached"
  }
}
