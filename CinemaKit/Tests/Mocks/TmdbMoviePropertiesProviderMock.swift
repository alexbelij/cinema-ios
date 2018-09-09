@testable import CinemaKit

class TmdbMoviePropertiesProviderMock: TmdbMoviePropertiesProvider {
  private let value: (String, Movie.TmdbProperties)?

  private init(value: (String, Movie.TmdbProperties)?) {
    self.value = value
  }

  func tmdbProperties(for tmdbID: TmdbIdentifier) -> (String, Movie.TmdbProperties)? {
    return value
  }
}

class FailingTmdbMoviePropertiesProvider: TmdbMoviePropertiesProvider {
  func tmdbProperties(for tmdbID: TmdbIdentifier) -> (String, Movie.TmdbProperties)? {
    fatalError("should not be called")
  }
}

extension TmdbMoviePropertiesProviderMock {
  static func returnNil() -> TmdbMoviePropertiesProviderMock {
    return TmdbMoviePropertiesProviderMock(value: nil)
  }

  static func returnEmpty() -> TmdbMoviePropertiesProviderMock {
    return TmdbMoviePropertiesProviderMock(value: ("Title", Movie.TmdbProperties()))
  }

  static func trap() -> TmdbMoviePropertiesProvider {
    return FailingTmdbMoviePropertiesProvider()
  }
}
