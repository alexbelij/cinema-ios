import CloudKit
import os.log

class MovieLibraryModel {
  var movies: [CKRecord.ID: Movie]
  var movieRecords: [CKRecord.ID: MovieRecord]
  var recordIDsByTmdbID: [TmdbIdentifier: CKRecord.ID]

  init(movies: [CKRecord.ID: Movie],
       movieRecords: [CKRecord.ID: MovieRecord],
       recordIDsByTmdbID: [TmdbIdentifier: CKRecord.ID]) {
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
  func remove(_ recordID: CKRecord.ID) -> Movie? {
    guard let movie = movies.removeValue(forKey: recordID) else { return nil }
    movieRecords.removeValue(forKey: recordID)
    recordIDsByTmdbID.removeValue(forKey: movie.tmdbID)
    return movie
  }
}

class MovieLibraryModelController: ThreadSafeModelController<MovieLibraryModel, MovieLibraryError> {
  private static let logger = Logging.createLogger(category: "MovieLibraryModelController")

  private let databaseScope: CKDatabase.Scope
  private let fetchManager: FetchManager
  private let syncManager: SyncManager
  private let tmdbPropertiesProvider: TmdbMoviePropertiesProvider
  private let libraryID: CKRecord.ID
  private let movieRecordStore: PersistentRecordStore
  private let tmdbPropertiesStore: TmdbPropertiesStore

  init(databaseScope: CKDatabase.Scope,
       fetchManager: FetchManager,
       syncManager: SyncManager,
       tmdbPropertiesProvider: TmdbMoviePropertiesProvider,
       libraryID: CKRecord.ID,
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
    let start = DispatchTime.now().uptimeNanoseconds
    loadMovieRecords { movieRecords in
      self.loadTmdbProperties(for: movieRecords) { tmdbProperties in
        self.makeModel(with: movieRecords, tmdbProperties) { model in
          let delta = (DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
          os_log("loading MovieLibraryModel took %d ms", log: MovieLibraryModelController.logger, type: .debug, delta)
          self.completeLoading(with: model)
        }
      }
    }
  }

  private func loadMovieRecords(whenLoaded: @escaping ([MovieRecord]) -> Void) {
    let start = DispatchTime.now().uptimeNanoseconds
    if let rawMovieRecords = movieRecordStore.loadRecords() {
      let delta = (DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
      os_log("loaded movie records from store (%d ms)", log: MovieLibraryModelController.logger, type: .debug, delta)
      let movieRecords = rawMovieRecords.map { MovieRecord($0) }
      whenLoaded(movieRecords)
    } else {
      os_log("need to fetch movie records", log: MovieLibraryModelController.logger, type: .debug)
      fetchMovieRecords { movieRecordsResult in
        switch movieRecordsResult {
          case let .success(movieRecords):
            os_log("fetched %d movie records",
                   log: MovieLibraryModelController.logger,
                   type: .debug,
                   movieRecords.count)
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
    let start = DispatchTime.now().uptimeNanoseconds
    if let tmdbProperties = tmdbPropertiesStore.load() {
      let delta = (DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
      os_log("loaded tmdb properties from store (%d ms)", log: MovieLibraryModelController.logger, type: .debug, delta)
      whenLoaded(tmdbProperties)
    } else {
      os_log("need to fetch tmdb properties for %d movies",
             log: MovieLibraryModelController.logger,
             type: .debug,
             movieRecords.count)
      var tmdbProperties = [TmdbIdentifier: Movie.TmdbProperties]()
      var unavailablePropertiesCount = 0
      for movie in movieRecords {
        let tmdbID = TmdbIdentifier(rawValue: movie.tmdbID)
        if let (_, fetched) = self.tmdbPropertiesProvider.tmdbProperties(for: tmdbID) {
          tmdbProperties[tmdbID] = fetched
        } else {
          unavailablePropertiesCount += 1
          tmdbProperties[tmdbID] = Movie.TmdbProperties()
        }
      }
      os_log("fetched tmdb properties (%d unavailable)",
             log: MovieLibraryModelController.logger,
             type: .debug,
             unavailablePropertiesCount)
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
    var moviesDict: [CKRecord.ID: Movie] = Dictionary(minimumCapacity: minimumCapacity)
    var movieRecordsDict: [CKRecord.ID: MovieRecord] = Dictionary(minimumCapacity: minimumCapacity)
    var recordIDsByTmdbIDDict: [TmdbIdentifier: CKRecord.ID] = Dictionary(minimumCapacity: minimumCapacity)
    var duplicates = [CKRecord.ID]()
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
    os_log("saving movie records to store", log: MovieLibraryModelController.logger, type: .debug)
    movieRecordStore.save(Array(model.movieRecords.values))
    os_log("saving tmdb properties to store", log: MovieLibraryModelController.logger, type: .debug)
    let tmdbProperties = Dictionary(uniqueKeysWithValues: model.movies.values.map { ($0.tmdbID, $0.tmdbProperties) })
    tmdbPropertiesStore.save(tmdbProperties)
  }

  override func removePersistedModel() {
    os_log("removing movie records", log: MovieLibraryModelController.logger, type: .debug)
    movieRecordStore.clear()
    os_log("removing tmdb properties", log: MovieLibraryModelController.logger, type: .debug)
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
