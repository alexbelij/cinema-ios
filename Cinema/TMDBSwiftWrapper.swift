import Dispatch
import Foundation
import TMDBSwift
import UIKit.UIImage

class TMDBSwiftWrapper: MovieDbClient {

  private static let apiKey = "ace1ea1cb456b8d6fe092a0ec923e30c"

  private static let baseUrl = "https://image.tmdb.org/t/p/"

  var storeFront: MovieDbStoreFront

  var language: MovieDbLanguage?

  var cache: TMDBSwiftCache

  init(storeFront: MovieDbStoreFront, cache: TMDBSwiftCache) {
    self.storeFront = storeFront
    self.cache = cache
  }

  private func effectiveLanguage() -> String {
    return language?.rawValue ?? storeFront.language
  }

  func tryConnect() {
    isConnected = true
  }

  private(set) var isConnected: Bool = false

  func poster(for id: Int, size: PosterSize) -> UIKit.UIImage? {
    return cache.poster(for: "\(id)-\(size)") {
      if let posterPath = movie(for: id, language: storeFront.language)?.poster_path {
        let path = TMDBSwiftWrapper.baseUrl + size.rawValue + posterPath
        if let data = try? Data(contentsOf: URL(string: path)!) {
          return UIImage(data: data)
        }
      }
      return nil
    }
  }

  func overview(for id: Int) -> String? {
    return movie(for: id, language: effectiveLanguage())?.overview
  }

  func certification(for id: Int) -> String? {
    let country = self.storeFront.country
    var releaseDates: [MovieReleaseDatesMDB]? = nil
    let certificationJson = cache.string(for: "certification-\(id)") {
      var jsonString: String?
      waitUntil { done in
        MovieMDB.release_dates(TMDBSwiftWrapper.apiKey, movieID: id) { apiReturn, releaseDates1 in
          if let json = apiReturn.json, apiReturn.json!["results"].exists(),
             let releaseDates1 = releaseDates1 {
            jsonString = json["results"].rawString()
            releaseDates = releaseDates1
          }
          done()
        }
      }
      return jsonString
    }
    if releaseDates == nil && certificationJson != nil {
      releaseDates = MovieReleaseDatesMDB.initialize(json: JSON.parse(certificationJson!))
    }
    return releaseDates!.first { $0.iso_3166_1 == country }?.release_dates[0].certification
  }

  func genreIds(for id: Int) -> [Int] {
    if let genres = movie(for: id, language: effectiveLanguage())?.genres.map({ $0.id! }) {
      return genres
    }
    return []
  }

  private func movie(for id: Int, language: String) -> MovieDetailedMDB? {
    var createdMovie: MovieDetailedMDB? = nil
    let movieJson = cache.string(for: "movie-\(id)-\(language)") {
      var jsonString: String?
      waitUntil { done in
        MovieMDB.movie(TMDBSwiftWrapper.apiKey, movieID: id, language: language) { apiReturn, movie in
          if let json = apiReturn.json, apiReturn.json!["id"].exists() {
            jsonString = json.rawString()
            createdMovie = movie
          }
          done()
        }
      }
      return jsonString
    }
    if createdMovie == nil && movieJson != nil {
      createdMovie = MovieDetailedMDB(results: JSON.parse(movieJson!))
    }
    return createdMovie
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

  func releaseDate(for id: Int) -> Date? {
    guard let movie = movie(for: id, language: effectiveLanguage()),
          let releaseDate = movie.release_date else { return nil }
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    return dateFormatter.date(from: releaseDate)
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
