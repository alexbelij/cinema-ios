import Foundation

enum Config {

  static func initLibrary() -> MediaLibrary {
    do {
      return try FileBasedMediaLibrary(directory: Utils.applicationSupportDirectory(),
                                       fileName: "cinema.data",
                                       dataFormat: KeyedArchivalFormat())
    } catch let error {
      fatalError("Library could not be instantiated: \(error)")
    }
  }

  static func initMovieDb() -> MovieDbClient {
    return CachingMovieDbClient(backingClient: TMDBSwiftWrapper(storeFront: .germany))
  }
}
