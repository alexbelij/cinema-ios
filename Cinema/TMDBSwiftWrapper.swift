import UIKit.UIImage
import Dispatch
import TMDBSwift

class TMDBSwiftWrapper: MovieDbClient {

  private static let apiKey = "ace1ea1cb456b8d6fe092a0ec923e30c"

  private static let baseUrl = "https://image.tmdb.org/t/p/";

  private static let language = "de"

  func tryConnect() {
    isConnected = true
  }

  private(set) var isConnected: Bool = false

  func poster(for id: Int, size: PosterSize) -> UIKit.UIImage? {
    if Thread.isMainThread {
      fatalError("must not be called on the main thread")
    }
    var value: UIKit.UIImage?
    let semaphore = DispatchSemaphore(value: 0)
    MovieMDB.movie(TMDBSwiftWrapper.apiKey, movieID: id, language: TMDBSwiftWrapper.language) {
      apiReturn, movie in
      if let posterPath = movie?.poster_path {
        let path = TMDBSwiftWrapper.baseUrl + size.rawValue + posterPath
        let image = try! UIImage(data: Data(contentsOf: URL(string: path)!))
        value = image
      }
      semaphore.signal()
    }
    semaphore.wait()
    return value
  }
}
