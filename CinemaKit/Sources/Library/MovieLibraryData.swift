import CloudKit
import os.log

class MovieLibraryDataObject {
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
}

class MovieLibraryData: LazyData<MovieLibraryDataObject, MovieLibraryError> {
  private static let logger = Logging.createLogger(category: "MovieLibraryData")

  private let databaseOperationQueue: DatabaseOperationQueue
  private let fetchManager: FetchManager
  private let syncManager: SyncManager
  private let tmdbPropertiesProvider: TmdbMoviePropertiesProvider
  private let libraryID: CKRecordID
  private let movieRecordStore: PersistentRecordStore
  private let tmdbPropertiesStore: TmdbPropertiesStore

  init(databaseOperationQueue: DatabaseOperationQueue,
       fetchManager: FetchManager,
       syncManager: SyncManager,
       tmdbPropertiesProvider: TmdbMoviePropertiesProvider,
       libraryID: CKRecordID,
       movieRecordStore: PersistentRecordStore,
       tmdbPropertiesStore: TmdbPropertiesStore) {
    self.databaseOperationQueue = databaseOperationQueue
    self.fetchManager = fetchManager
    self.syncManager = syncManager
    self.tmdbPropertiesProvider = tmdbPropertiesProvider
    self.libraryID = libraryID
    self.movieRecordStore = movieRecordStore
    self.tmdbPropertiesStore = tmdbPropertiesStore
    super.init(label: "de.martinbauer.cinema.MovieLibraryData")
  }

  override func makeWithDefaultValue() -> MovieLibraryDataObject {
    return MovieLibraryDataObject(movies: [:], movieRecords: [:], recordIDsByTmdbID: [:])
  }

  override func loadData() {
    if let rawMovieRecords = movieRecordStore.loadRecords(),
       let tmdbProperties = tmdbPropertiesStore.load() {
      os_log("loaded records from store", log: MovieLibraryData.logger, type: .debug)
      makeData(rawMovieRecords.map { MovieRecord($0) }, tmdbProperties)
    } else {
      os_log("loading records from cloud", log: MovieLibraryData.logger, type: .debug)
      fetchMoviesFromCloud { result in
        self.didFetchMovieRecords(result)
      }
    }
  }

  private func didFetchMovieRecords(_ movieRecordsResult: Result<[MovieRecord], MovieLibraryError>) {
    switch movieRecordsResult {
      case let .failure(error):
        abortLoading(with: error)
      case let .success(movieRecords):
        os_log("saving fetched records to store", log: MovieLibraryData.logger, type: .debug)
        movieRecordStore.save(movieRecords)
        os_log("fetching %d tmdb properties", log: MovieLibraryData.logger, type: .debug, movieRecords.count)
        self.fetchTmdbProperties(for: movieRecords) { tmdbProperties in
          os_log("saving fetched tmdb properties store", log: MovieLibraryData.logger, type: .debug)
          self.tmdbPropertiesStore.save(tmdbProperties)
          self.makeData(movieRecords, tmdbProperties)
        }
    }
  }

  private func makeData(_ movieRecords: [MovieRecord], _ tmdbProperties: [TmdbIdentifier: Movie.TmdbProperties]) {
    let start = DispatchTime.now().uptimeNanoseconds
    if movieRecords.count != tmdbProperties.count {
      os_log("some data is missing: %d movieRecords and %d tmdbProperties",
             log: MovieLibraryData.logger,
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
             log: MovieLibraryData.logger,
             type: .default,
             duplicates.count)
      syncManager.delete(duplicates, using: databaseOperationQueue)
    }
    let end = DispatchTime.now().uptimeNanoseconds
    print("loading data took \((end - start) / 1_000_000) ms")
    completeLoading(with: MovieLibraryDataObject(movies: moviesDict,
                                                 movieRecords: movieRecordsDict,
                                                 recordIDsByTmdbID: recordIDsByTmdbIDDict))
  }

  override func persist(_ data: MovieLibraryDataObject) {
    os_log("saving records to store", log: MovieLibraryData.logger, type: .debug)
    movieRecordStore.save(Array(data.movieRecords.values))
    os_log("saving tmdb properties to store", log: MovieLibraryData.logger, type: .debug)
    let tmdbProperties = Dictionary(uniqueKeysWithValues: data.movies.values.map { ($0.tmdbID, $0.tmdbProperties) })
    tmdbPropertiesStore.save(tmdbProperties)
  }

  override func clear() {
    os_log("removing store", log: MovieLibraryData.logger, type: .debug)
    movieRecordStore.clear()
    tmdbPropertiesStore.clear()
  }
}

// MARK: - Fetching Movies From Cloud

extension MovieLibraryData {
  private func fetchMoviesFromCloud(then completion: @escaping (Result<[MovieRecord], MovieLibraryError>) -> Void) {
    fetchManager.fetch(MovieRecord.self,
                       matching: MovieRecord.queryPredicate(forMoviesInLibraryWithID: libraryID),
                       inZoneWithID: libraryID.zoneID,
                       using: databaseOperationQueue) { records, error in
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

  private func fetchTmdbProperties(for movieRecords: [MovieRecord],
                                   then completion: @escaping ([TmdbIdentifier: Movie.TmdbProperties]) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
      var properties = [TmdbIdentifier: Movie.TmdbProperties]()
      for movie in movieRecords {
        let tmdbID = TmdbIdentifier(rawValue: movie.tmdbID)
        if let (_, fetched) = self.tmdbPropertiesProvider.tmdbProperties(for: tmdbID) {
          properties[tmdbID] = fetched
        } else {
          properties[tmdbID] = Movie.TmdbProperties()
        }
      }
      completion(properties)
    }
  }
}
