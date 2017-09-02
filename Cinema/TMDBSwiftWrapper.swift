import Dispatch
import TMDBSwift
import UIKit.UIImage

class TMDBSwiftWrapper: MovieDbClient {

  private static let apiKey = "ace1ea1cb456b8d6fe092a0ec923e30c"

  private static let baseUrl = "https://image.tmdb.org/t/p/"

  var storeFront: MovieDbStoreFront

  var language: MovieDbLanguage?

  init(storeFront: MovieDbStoreFront) {
    self.storeFront = storeFront
  }

  private func effectiveLanguage() -> String {
    return language?.rawValue ?? storeFront.language
  }

  func tryConnect() {
    isConnected = true
  }

  private(set) var isConnected: Bool = false

  func poster(for id: Int, size: PosterSize) -> UIKit.UIImage? {
    if let posterPath = movie(for: id, language: storeFront.language)?.poster_path {
      let path = TMDBSwiftWrapper.baseUrl + size.rawValue + posterPath
      if let data = try? Data(contentsOf: URL(string: path)!) {
        return UIImage(data: data)
      }
    }
    return nil
  }

  func overview(for id: Int) -> String? {
    return movie(for: id, language: effectiveLanguage())?.overview
  }

  func certification(for id: Int) -> String? {
    var certification: String?
    waitUntil { done in
      MovieMDB.release_dates(TMDBSwiftWrapper.apiKey, movieID: id) { _, releaseDates in
        if let releaseDates = releaseDates {
          for date in releaseDates where date.iso_3166_1 == self.storeFront.country {
            certification = date.release_dates[0].certification
          }
        }
        done()
      }
    }
    return certification
  }

  func genreIds(for id: Int) -> [Int] {
    if let genres = movie(for: id, language: effectiveLanguage())?.genres.map({ $0.id! }) {
      return genres
    }
    return []
  }

  private func movie(for id: Int, language: String) -> MovieDetailedMDB? {
    var movieToReturn: MovieDetailedMDB?
    waitUntil { done in
      MovieMDB.movie(TMDBSwiftWrapper.apiKey, movieID: id, language: language) { _, movie in
        movieToReturn = movie
        done()
      }
    }
    return movieToReturn
  }

  func searchMovies(searchText: String) -> [PartialMediaItem] {
    var value = [PartialMediaItem]()
    waitUntil { done in
      SearchMDB.movie(TMDBSwiftWrapper.apiKey,
                      query: searchText,
                      language: storeFront.language,
                      page: 1,
                      includeAdult: false,
                      year: nil,
                      primaryReleaseYear: nil) { _, results in
        if let results = results {
          let dateFormatter = DateFormatter()
          dateFormatter.dateFormat = "yyyy-MM-dd"
          value = results.map {
            PartialMediaItem(id: $0.id!,
                             title: $0.title!,
                             releaseDate: dateFormatter.date(from: $0.release_date!))
          }
        }
        done()
      }
    }
    return value
  }

  func runtime(for id: Int) -> Int? {
    return movie(for: id, language: storeFront.language)?.runtime
  }

  func popularMovies() -> PagingSequence<PartialMediaItem> {
    return PagingSequence<PartialMediaItem> { page -> [PartialMediaItem]? in
      var movies = [PartialMediaItem]()
      self.waitUntil { done in
        MovieMDB.popular(TMDBSwiftWrapper.apiKey, language: self.effectiveLanguage(), page: page) { _, result in
          if let result = result {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            movies = result.map {
              PartialMediaItem(id: $0.id!,
                               title: $0.title!,
                               releaseDate: dateFormatter.date(from: $0.release_date!))
            }
          }
          done()
        }
      }
      return movies.isEmpty ? nil : movies
    }
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
