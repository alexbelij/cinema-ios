import Dispatch
import Foundation
import os.log
import TMDBSwift
import UIKit

public class TMDBSwiftWrapper: MovieDbClient {
  private static let logger = Logging.createLogger(category: "TMDB")
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
  private var cachedPosterPaths = [TmdbIdentifier: String]()

  public init(language: MovieDbLanguage, country: MovieDbCountry) {
    self.language = language
    self.country = country
    self.cache = StandardTMDBSwiftCache() ?? DummyTMDBSwiftCache()
    TMDBConfig.apikey = TMDBSwiftWrapper.apiKey
  }

  public func poster(for id: TmdbIdentifier, size: PosterSize, purpose: PosterPurpose) -> UIImage? {
    switch purpose {
      case .list, .details:
        return cache.poster(for: "\(id)-\(language)-\(size)") { fetchPoster(for: id, size: size) }
      case .popularMovies:
        return cache.largePoster(for: "\(id)-\(language)-\(size)") { fetchPoster(for: id, size: size) }
      case .searchResult:
        return fetchPoster(for: id, size: size)
    }
  }

  private func fetchPoster(for id: TmdbIdentifier, size: PosterSize) -> UIImage? {
    if cachedPosterPaths.keys.contains(id) {
      guard let posterPath = cachedPosterPaths[id] else { return nil }
      return fetchImage(at: posterPath, size: size.rawValue)
    } else if let posterPath = movie(for: id)?.poster_path {
      return fetchImage(at: posterPath, size: size.rawValue)
    }
    return nil
  }

  public func backdrop(for id: TmdbIdentifier, size: BackdropSize) -> UIImage? {
    return cache.backdrop(for: "\(id)-\(language)-\(size)") {
      guard let backdropPath = movie(for: id)?.backdrop_path else { return nil }
      return fetchImage(at: backdropPath, size: size.rawValue)
    }
  }

  private func fetchImage(at path: String, size: String) -> UIImage? {
    let urlString: String = TMDBSwiftWrapper.baseUrl + size + path
    guard let url = URL(string: urlString) else {
      os_log("image path is no valid URL: %{public}@", log: TMDBSwiftWrapper.logger, type: .error, urlString)
      return nil
    }
    guard let data = try? Data(contentsOf: url) else { return nil }
    return UIImage(data: data)
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

  public func searchMovies(searchText: String) -> [PartialMovie] {
    var movies = [PartialMovie]()
    waitUntil { done in
      SearchMDB.movie(query: searchText,
                      language: language.rawValue,
                      page: 1,
                      includeAdult: false,
                      year: nil,
                      primaryReleaseYear: nil) { _, result in
        if let result = result {
          movies = result.map(self.toPartialMovie)
        }
        done()
      }
    }
    return movies
  }

  public func popularMovies() -> PagingSequence<PartialMovie> {
    return PagingSequence<PartialMovie> { page -> [PartialMovie]? in
      var movies = [PartialMovie]()
      self.waitUntil { done in
        MovieMDB.popular(language: self.language.rawValue, page: page) { _, result in
          if let result = result {
            movies = result.map(self.toPartialMovie)
          }
          done()
        }
      }
      return movies.isEmpty ? nil : movies
    }
  }

  private func toPartialMovie(_ movieMDB: MovieMDB) -> PartialMovie {
    let identifier = TmdbIdentifier(rawValue: movieMDB.id!)
    let year = TMDBSwiftWrapper.releaseDateFormatter.date(from: movieMDB.release_date!)
                                                    .map { Calendar.current.component(.year, from: $0) }
    self.cachedPosterPaths[identifier] = movieMDB.poster_path
    return PartialMovie(tmdbID: identifier, title: movieMDB.title!, releaseYear: year)
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

extension TMDBSwiftWrapper: MovieProvider {
  func movie(with tmdbID: TmdbIdentifier, diskType: DiskType) -> Movie? {
    guard let movie = movie(for: tmdbID) else { return nil }
    var runtime: Measurement<UnitDuration>?
    if let value = movie.runtime, value > 0 {
      runtime = Measurement(value: Double(value), unit: .minutes)
    }
    var releaseDate: Date?
    if let value = movie.release_date {
      releaseDate = TMDBSwiftWrapper.releaseDateFormatter.date(from: value)
    }
    return Movie(tmdbID: tmdbID,
                 title: movie.title!,
                 subtitle: nil,
                 diskType: diskType,
                 runtime: runtime,
                 releaseDate: releaseDate,
                 genreIds: movie.genres.map { GenreIdentifier(rawValue: $0.id!) },
                 certification: certification(for: tmdbID),
                 overview: movie.overview)
  }

  private func certification(for id: TmdbIdentifier) -> String? {
    var releaseDates: [MovieReleaseDatesMDB]?
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
}
