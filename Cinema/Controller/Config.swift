import Foundation

enum Config {

  static func initLibrary() -> MediaLibrary {
    let url = Utils.directoryUrl(for: .documentDirectory).appendingPathComponent("cinema.data")
    moveLegacyLibraryFile(to: url)
    let dataFormat = KeyedArchivalFormat()
    dataFormat.defaultSchemaVersion = .v2_0_0
    do {
      return try FileBasedMediaLibrary(url: url, dataFormat: dataFormat)
    } catch let error {
      fatalError("Library could not be instantiated: \(error)")
    }
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

  static func initMovieDb() -> MovieDbClient {
    let language = MovieDbLanguage(rawValue: Locale.current.languageCode ?? "en") ?? .en
    let country = MovieDbCountry(rawValue: Locale.current.regionCode ?? "US") ?? .unitedStates
    return TMDBSwiftWrapper(language: language, country: country, cache: StandardTMDBSwiftCache())
  }
}
