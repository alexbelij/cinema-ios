import UIKit.UIImage
import Dispatch
import TMDBSwift

class TMDBSwiftWrapper: MovieDbClient {

  private static let apiKey = "ace1ea1cb456b8d6fe092a0ec923e30c"

  private static let baseUrl = "https://image.tmdb.org/t/p/";

  private static let language = "de"

  private static let country = "DE"

  func tryConnect() {
    isConnected = true
  }

  private(set) var isConnected: Bool = false

  func poster(for id: Int, size: PosterSize) -> UIKit.UIImage? {
    var value: UIKit.UIImage?
    waitUntil { done in
      MovieMDB.movie(TMDBSwiftWrapper.apiKey, movieID: id, language: TMDBSwiftWrapper.language) {
        apiReturn, movie in
        if let posterPath = movie?.poster_path {
          let path = TMDBSwiftWrapper.baseUrl + size.rawValue + posterPath
          let image = try! UIImage(data: Data(contentsOf: URL(string: path)!))
          value = image
        }
        done()
      }
    }
    return value
  }

  func overview(for id: Int) -> String? {
    var value: String?
    waitUntil { done in
      MovieMDB.movie(TMDBSwiftWrapper.apiKey, movieID: id, language: TMDBSwiftWrapper.language) {
        apiReturn, movie in
        value = movie?.overview
        done()
      }
    }
    return value
  }

  func certification(for id: Int) -> String? {
    var value: String?
    waitUntil { done in
      MovieMDB.release_dates(TMDBSwiftWrapper.apiKey, movieID: id) {
        apiReturn, releaseDates in
        if let releaseDates = releaseDates {
          for date in releaseDates {
            if date.iso_3166_1 == TMDBSwiftWrapper.country {
              value = date.release_dates[0].certification
            }
          }
        }
        done()
      }
    }
    return value
  }

  func genres(for id: Int) -> [String] {
    var value = [String]()
    waitUntil { done in
      MovieMDB.movie(TMDBSwiftWrapper.apiKey, movieID: id, language: TMDBSwiftWrapper.language) {
        apiReturn, movie in
        if let genres = movie?.genres.map({ $0.name! }) {
          value = genres
        }
        done()
      }
    }
    return value
  }

  private func waitUntil(_ asyncProcess: (_ done: @escaping () -> Void) -> Void) {
    if Thread.isMainThread {
      fatalError("must not be called on the main thread")
    }
    let semaphore = DispatchSemaphore(value: 0)
    let done = { _ = semaphore.signal() }
    asyncProcess(done)
    semaphore.wait()
  }

}
