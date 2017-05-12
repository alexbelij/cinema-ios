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
    if let posterPath = movie(for: id)?.poster_path {
      let path = TMDBSwiftWrapper.baseUrl + size.rawValue + posterPath
      let image = try! UIImage(data: Data(contentsOf: URL(string: path)!))
      return image
    }
    return nil
  }

  func overview(for id: Int) -> String? {
    return movie(for: id)?.overview
  }

  func certification(for id: Int) -> String? {
    var certification: String?
    waitUntil { done in
      MovieMDB.release_dates(TMDBSwiftWrapper.apiKey, movieID: id) {
        apiReturn, releaseDates in
        if let releaseDates = releaseDates {
          for date in releaseDates {
            if date.iso_3166_1 == TMDBSwiftWrapper.country {
              certification = date.release_dates[0].certification
            }
          }
        }
        done()
      }
    }
    return certification
  }

  func genres(for id: Int) -> [String] {
    if let genres = movie(for: id)?.genres.map({ $0.name! }) {
      return genres
    }
    return []
  }

  private func movie(for id: Int) -> MovieDetailedMDB? {
    var movieToReturn: MovieDetailedMDB?
    waitUntil { done in
      MovieMDB.movie(TMDBSwiftWrapper.apiKey, movieID: id, language: TMDBSwiftWrapper.language) {
        apiReturn, movie in
        movieToReturn = movie
        done()
      }
    }
    return movieToReturn
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
