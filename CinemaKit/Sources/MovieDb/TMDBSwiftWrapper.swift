import Dispatch
import Foundation
import TMDBSwift
import UIKit

public class TMDBSwiftWrapper: MovieDbClient {

  private static let apiKey = "ace1ea1cb456b8d6fe092a0ec923e30c"

  private static let baseUrl = "https://image.tmdb.org/t/p/"

  private static let releaseDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  public var language: MovieDbLanguage

  public var country: MovieDbCountry

  private var cache: TMDBSwiftCache

  public init(language: MovieDbLanguage, country: MovieDbCountry) {
    self.language = language
    self.country = country
    self.cache = StandardTMDBSwiftCache()
    TMDBConfig.apikey = TMDBSwiftWrapper.apiKey
  }

  public func poster(for id: TmdbIdentifier, size: PosterSize, purpose: PosterPurpose) -> UIImage? {
    switch purpose {
      case .list, .details:
        return cache.poster(for: "\(id)-\(language)-\(size)") { fetchPoster(for: id, size: size) }
      case .popularMovies:
        return cache.largePoster(for: "\(id)-\(language)-\(size)") { fetchPoster(for: id, size: size) }
      case .libraryUpdate:
        return fetchPoster(for: id, size: size)
    }
  }

  private func fetchPoster(for id: TmdbIdentifier, size: PosterSize) -> UIImage? {
    guard let posterPath = movie(for: id)?.poster_path else { return nil }
    return fetchImage(at: posterPath, size: size.rawValue)
  }

  public func backdrop(for id: TmdbIdentifier, size: BackdropSize) -> UIImage? {
    return cache.backdrop(for: "\(id)-\(language)-\(size)") {
      guard let backdropPath = movie(for: id)?.backdrop_path else { return nil }
      return fetchImage(at: backdropPath, size: size.rawValue)
    }
  }

  private func fetchImage(at path: String, size: String) -> UIImage? {
    guard let data = try? Data(contentsOf: URL(string: TMDBSwiftWrapper.baseUrl + size + path)!) else { return nil }
    return UIImage(data: data)
  }

  public func overview(for id: TmdbIdentifier) -> String? {
    return movie(for: id)?.overview
  }

  public func certification(for id: TmdbIdentifier) -> String? {
    var releaseDates: [MovieReleaseDatesMDB]? = nil
    let certificationJson = cache.string(for: "certification-\(id)") {
      var jsonString: String?
      waitUntil { done in
        MovieMDB.release_dates(movieID: id.rawValue) { apiReturn, releaseDates1 in
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
      var array = [MovieReleaseDatesMDB]()
      JSON(parseJSON: certificationJson!).forEach {
        array.append(MovieReleaseDatesMDB(results: $0.1))
      }
      releaseDates = array
    }
    return releaseDates?.first { $0.iso_3166_1 == self.country.rawValue }?.release_dates[0].certification
  }

  public func genreIds(for id: TmdbIdentifier) -> [GenreIdentifier] {
    if let genres = movie(for: id)?.genres.map({ GenreIdentifier(rawValue: $0.id!) }) {
      return genres
    }
    return []
  }

  private func movie(for id: TmdbIdentifier) -> MovieDetailedMDB? {
    var createdMovie: MovieDetailedMDB? = nil
    let movieJson = cache.string(for: "movie-\(id)-\(language.rawValue)") {
      var jsonString: String?
      waitUntil { done in
        MovieMDB.movie(movieID: id.rawValue, language: language.rawValue) { apiReturn, movie in
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
      createdMovie = MovieDetailedMDB(results: JSON(parseJSON: movieJson!))
    }
    return createdMovie
  }

  public func searchMovies(searchText: String) -> [PartialMediaItem] {
    var movies = [PartialMediaItem]()
    waitUntil { done in
      SearchMDB.movie(query: searchText,
                      language: language.rawValue,
                      page: 1,
                      includeAdult: false,
                      year: nil,
                      primaryReleaseYear: nil) { _, result in
        if let result = result {
          movies = result.map(self.toPartialMediaItem)
        }
        done()
      }
    }
    return movies
  }

  public func runtime(for id: TmdbIdentifier) -> Measurement<UnitDuration>? {
    guard let runtime = movie(for: id)?.runtime, runtime > 0 else { return nil }
    return Measurement(value: Double(runtime), unit: UnitDuration.minutes)
  }

  public func popularMovies() -> PagingSequence<PartialMediaItem> {
    return PagingSequence<PartialMediaItem> { page -> [PartialMediaItem]? in
      var movies = [PartialMediaItem]()
      self.waitUntil { done in
        MovieMDB.popular(language: self.language.rawValue, page: page) { _, result in
          if let result = result {
            movies = result.map(self.toPartialMediaItem)
          }
          done()
        }
      }
      return movies.isEmpty ? nil : movies
    }
  }

  private func toPartialMediaItem(_ movieMDB: MovieMDB) -> PartialMediaItem {
    let year = TMDBSwiftWrapper.releaseDateFormatter.date(from: movieMDB.release_date!)
                                                    .map { Calendar.current.component(.year, from: $0) }
    return PartialMediaItem(tmdbID: TmdbIdentifier(rawValue: movieMDB.id!), title: movieMDB.title!, releaseYear: year)
  }

  public func releaseDate(for id: TmdbIdentifier) -> Date? {
    guard let movie = movie(for: id),
          let releaseDate = movie.release_date else { return nil }
    return TMDBSwiftWrapper.releaseDateFormatter.date(from: releaseDate)
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
