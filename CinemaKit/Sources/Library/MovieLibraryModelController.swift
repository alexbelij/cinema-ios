import CloudKit
import os.log

class MovieLibraryModel {
  var movies: [CKRecordID: Movie]
  var movieRecords: [CKRecordID: MovieRecord]
  var recordIDsByTmdbID: [TmdbIdentifier: CKRecordID]

  init(movies: [CKRecordID: Movie],
       movieRecords: [CKRecordID: MovieRecord],
       recordIDsByTmdbID: [TmdbIdentifier: CKRecordID]) {
    self.movies = movies
    self.movieRecords = movieRecords
    self.recordIDsByTmdbID = recordIDsByTmdbID
  }

  var allMovies: [Movie] {
    return Array(movies.values)
  }

  func movie(for tmdbID: TmdbIdentifier) -> Movie? {
    guard let recordID = recordIDsByTmdbID[tmdbID] else { return nil }
    return movies[recordID]
  }

  func record(for movie: Movie) -> MovieRecord? {
    return movieRecords[movie.id]
  }

  func add(_ movie: Movie, with record: MovieRecord) {
    movies[movie.id] = movie
    movieRecords[movie.id] = record
    recordIDsByTmdbID[movie.tmdbID] = movie.id
  }

  func update(_ movie: Movie, and record: MovieRecord) {
    movies[movie.id] = movie
    movieRecords[movie.id] = record
  }

  @discardableResult
  func remove(_ recordID: CKRecordID) -> Movie? {
    guard let movie = movies.removeValue(forKey: recordID) else { return nil }
    movieRecords.removeValue(forKey: recordID)
    recordIDsByTmdbID.removeValue(forKey: movie.tmdbID)
    return movie
  }
}

class MovieLibraryModelController: ThreadSafeModelController<MovieLibraryModel, MovieLibraryError> {
  private static let logger = Logging.createLogger(category: "MovieLibraryModelController")

  private let databaseScope: CKDatabaseScope
  private let fetchManager: FetchManager
  private let syncManager: SyncManager
  private let tmdbPropertiesProvider: TmdbMoviePropertiesProvider
  private let libraryID: CKRecordID
  private let movieRecordStore: PersistentRecordStore
  private let tmdbPropertiesStore: TmdbPropertiesStore

  init(databaseScope: CKDatabaseScope,
       fetchManager: FetchManager,
       syncManager: SyncManager,
       tmdbPropertiesProvider: TmdbMoviePropertiesProvider,
       libraryID: CKRecordID,
       movieRecordStore: PersistentRecordStore,
       tmdbPropertiesStore: TmdbPropertiesStore) {
    self.databaseScope = databaseScope
    self.fetchManager = fetchManager
    self.syncManager = syncManager
    self.tmdbPropertiesProvider = tmdbPropertiesProvider
    self.libraryID = libraryID
    self.movieRecordStore = movieRecordStore
    self.tmdbPropertiesStore = tmdbPropertiesStore
    super.init(label: "de.martinbauer.cinema.MovieLibraryModelController")
  }

  override func makeWithDefaultValue() -> MovieLibraryModel {
    return MovieLibraryModel(movies: [:], movieRecords: [:], recordIDsByTmdbID: [:])
  }

  override func loadModel() {
    loadMovieRecords { movieRecords in
      self.loadTmdbProperties(for: movieRecords) { tmdbProperties in
        self.makeModel(with: movieRecords, tmdbProperties) { model in
          self.completeLoading(with: model)
        }
      }
    }
  }

  private func loadMovieRecords(whenLoaded: @escaping ([MovieRecord]) -> Void) {
    if let rawMovieRecords = movieRecordStore.loadRecords() {
      os_log("loaded records from store", log: MovieLibraryModelController.logger, type: .debug)
      let movieRecords = rawMovieRecords.map { MovieRecord($0) }
      whenLoaded(movieRecords)
    } else {
      os_log("loading records from cloud", log: MovieLibraryModelController.logger, type: .debug)
      fetchMovieRecords { movieRecordsResult in
        switch movieRecordsResult {
          case let .success(movieRecords):
            os_log("saving fetched records to store", log: MovieLibraryModelController.logger, type: .debug)
            self.movieRecordStore.save(movieRecords)
            whenLoaded(movieRecords)
          case let .failure(error):
            self.abortLoading(with: error)
        }
      }
    }
  }

  private func loadTmdbProperties(for movieRecords: [MovieRecord],
                                  whenLoaded: @escaping ([TmdbIdentifier: Movie.TmdbProperties]) -> Void) {
    if let tmdbProperties = tmdbPropertiesStore.load() {
      os_log("loaded tmdb properties from store", log: MovieLibraryModelController.logger, type: .debug)
      whenLoaded(tmdbProperties)
    } else {
      os_log("fetching %d tmdb properties", log: MovieLibraryModelController.logger, type: .debug, movieRecords.count)
      var tmdbProperties = [TmdbIdentifier: Movie.TmdbProperties]()
      for movie in movieRecords {
        let tmdbID = TmdbIdentifier(rawValue: movie.tmdbID)
        if let (_, fetched) = self.tmdbPropertiesProvider.tmdbProperties(for: tmdbID) {
          tmdbProperties[tmdbID] = fetched
        } else {
          tmdbProperties[tmdbID] = Movie.TmdbProperties()
        }
      }
      os_log("saving fetched tmdb properties store", log: MovieLibraryModelController.logger, type: .debug)
      self.tmdbPropertiesStore.save(tmdbProperties)
      whenLoaded(tmdbProperties)
    }
  }

  private func makeModel(with movieRecords: [MovieRecord],
                         _ tmdbProperties: [TmdbIdentifier: Movie.TmdbProperties],
                         whenLoaded: @escaping (MovieLibraryModel) -> Void) {
    if movieRecords.count != tmdbProperties.count {
      os_log("some data is missing: %d movieRecords and %d tmdbProperties",
             log: MovieLibraryModelController.logger,
             type: .error,
             movieRecords.count,
             tmdbProperties.count)
    }
    let minimumCapacity = movieRecords.count
    var moviesDict: [CKRecordID: Movie] = Dictionary(minimumCapacity: minimumCapacity)
    var movieRecordsDict: [CKRecordID: MovieRecord] = Dictionary(minimumCapacity: minimumCapacity)
    var recordIDsByTmdbIDDict: [TmdbIdentifier: CKRecordID] = Dictionary(minimumCapacity: minimumCapacity)
    var duplicates = [CKRecordID]()
    for movieRecord in movieRecords {
      let cloudProperties = Movie.CloudProperties(from: movieRecord)
      if let existingRecordID = recordIDsByTmdbIDDict[cloudProperties.tmdbID] {
        let existingRecord = movieRecordsDict[existingRecordID]!
        if existingRecord.rawRecord.creationDate! <= movieRecord.rawRecord.creationDate! {
          duplicates.append(movieRecord.id)
          continue
        } else {
          duplicates.append(existingRecord.id)
          moviesDict.removeValue(forKey: existingRecordID)
          movieRecordsDict.removeValue(forKey: existingRecordID)
          recordIDsByTmdbIDDict.removeValue(forKey: cloudProperties.tmdbID)
        }
      }
      let tmdbProperties = tmdbProperties[cloudProperties.tmdbID]!
      moviesDict[movieRecord.id] = Movie(cloudProperties, tmdbProperties)
      movieRecordsDict[movieRecord.id] = movieRecord
      recordIDsByTmdbIDDict[cloudProperties.tmdbID] = movieRecord.id
    }
    if !duplicates.isEmpty {
      os_log("found %d duplicates while loading -> deleting",
             log: MovieLibraryModelController.logger,
             type: .default,
             duplicates.count)
      syncManager.delete(duplicates, in: databaseScope)
    }
    whenLoaded(MovieLibraryModel(movies: moviesDict,
                                 movieRecords: movieRecordsDict,
                                 recordIDsByTmdbID: recordIDsByTmdbIDDict))
  }

  override func persist(_ model: MovieLibraryModel) {
    os_log("saving records to store", log: MovieLibraryModelController.logger, type: .debug)
    movieRecordStore.save(Array(model.movieRecords.values))
    os_log("saving tmdb properties to store", log: MovieLibraryModelController.logger, type: .debug)
    let tmdbProperties = Dictionary(uniqueKeysWithValues: model.movies.values.map { ($0.tmdbID, $0.tmdbProperties) })
    tmdbPropertiesStore.save(tmdbProperties)
  }

  override func removePersistedModel() {
    os_log("removing store", log: MovieLibraryModelController.logger, type: .debug)
    movieRecordStore.clear()
    tmdbPropertiesStore.clear()
  }
}

// MARK: - Fetching From Cloud

extension MovieLibraryModelController {
  private func fetchMovieRecords(then completion: @escaping (Result<[MovieRecord], MovieLibraryError>) -> Void) {
    fetchManager.fetch(MovieRecord.self,
                       matching: MovieRecord.queryPredicate(forMoviesInLibraryWithID: libraryID),
                       inZoneWithID: libraryID.zoneID,
                       in: databaseScope) { records, error in
      if let error = error {
        switch error {
          case .userDeletedZone:
            completion(.failure(.globalError(.userDeletedZone)))
          case .notAuthenticated:
            completion(.failure(.globalError(.notAuthenticated)))
          case .nonRecoverableError:
            completion(.failure(.nonRecoverableError))
          case .conflict, .itemNoLongerExists, .zoneNotFound, .permissionFailure:
            fatalError("should not occur: \(error)")
        }
      } else if let records = records {
        completion(.success(records))
      }
    }
  }
}
