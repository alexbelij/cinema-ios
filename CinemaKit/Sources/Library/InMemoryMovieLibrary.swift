protocol TmdbMoviePropertiesProvider {
  func tmdbProperties(for tmdbID: TmdbIdentifier) -> (String, Movie.TmdbProperties)?
}

class InMemoryMovieLibrary: InternalMovieLibrary {
  var metadata: MovieLibraryMetadata {
    didSet {
      delegates.invoke { $0.libraryDidUpdateMetadata(self) }
    }
  }
  let delegates: MulticastDelegate<MovieLibraryDelegate> = MulticastDelegate()
  private let tmdbPropertiesProvider: TmdbMoviePropertiesProvider
  private var movies = [Movie]()

  init(metadata: MovieLibraryMetadata, tmdbPropertiesProvider: TmdbMoviePropertiesProvider) {
    self.metadata = metadata
    self.tmdbPropertiesProvider = tmdbPropertiesProvider
  }

  func fetchMovies(then completion: @escaping (Result<[Movie], MovieLibraryError>) -> Void) {
    completion(.success(movies))
  }

  func fetchMovies(for id: GenreIdentifier, then completion: @escaping (Result<[Movie], MovieLibraryError>) -> Void) {
    completion(.success(movies.filter { $0.genreIds.contains(id) }))
  }

  func addMovie(with tmdbID: TmdbIdentifier,
                diskType: DiskType,
                then completion: @escaping (Result<Movie, MovieLibraryError>) -> Void) {
    guard let (title, tmdbProperties) = tmdbPropertiesProvider.tmdbProperties(for: tmdbID) else {
      completion(.failure(.detailsFetchError))
      return
    }
    let cloudProperties = Movie.CloudProperties(tmdbID: tmdbID,
                                                libraryID: metadata.id,
                                                title: title,
                                                diskType: diskType)
    let movie = Movie(cloudProperties, tmdbProperties)
    movies.append(movie)
    let changeSet = ChangeSet<TmdbIdentifier, Movie>(insertions: [movie])
    delegates.invoke { $0.library(self, didUpdateMovies: changeSet) }
    completion(.success(movie))
  }

  func update(_ movie: Movie, then completion: @escaping (Result<Movie, MovieLibraryError>) -> Void) {
    guard let index = movies.index(of: movie) else { preconditionFailure() }
    movies[index] = movie
    let changeSet = ChangeSet<TmdbIdentifier, Movie>(modifications: [movie.tmdbID: movie])
    delegates.invoke { $0.library(self, didUpdateMovies: changeSet) }
    completion(.success(movie))
  }

  func removeMovie(with tmdbID: TmdbIdentifier, then completion: @escaping (Result<Void, MovieLibraryError>) -> Void) {
    guard let index = movies.index(where: { $0.tmdbID == tmdbID }) else { preconditionFailure() }
    let movie = movies.remove(at: index)
    let changeSet = ChangeSet<TmdbIdentifier, Movie>(deletions: [movie.tmdbID: movie])
    delegates.invoke { $0.library(self, didUpdateMovies: changeSet) }
    completion(.success(()))
  }
}
