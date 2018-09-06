import CloudKit
import Dispatch
import os.log

protocol TmdbMoviePropertiesProvider {
  func tmdbProperties(for tmdbID: TmdbIdentifier) -> (String, Movie.TmdbProperties)?
}

class DeviceSyncingMovieLibrary: InternalMovieLibrary {
  private static let logger = Logging.createLogger(category: "Library")

  var metadata: MovieLibraryMetadata {
    willSet {
      precondition(self.metadata.id == metadata.id)
    }
    didSet {
      delegates.invoke { $0.libraryDidUpdateMetadata(self) }
    }
  }
  let delegates: MulticastDelegate<MovieLibraryDelegate> = MulticastDelegate()
  private var localData: LazyData<MovieLibraryDataObject, MovieLibraryError>
  private let tmdbPropertiesProvider: TmdbMoviePropertiesProvider
  private let syncManager: SyncManager

  init(metadata: MovieLibraryMetadata,
       data: LazyData<MovieLibraryDataObject, MovieLibraryError>,
       tmdbPropertiesProvider: TmdbMoviePropertiesProvider,
       syncManager: SyncManager) {
    self.metadata = metadata
    self.localData = data
    self.tmdbPropertiesProvider = tmdbPropertiesProvider
    self.syncManager = syncManager
  }
}

// MARK: - core functionality

extension DeviceSyncingMovieLibrary {
  func fetchMovies(then completion: @escaping (Result<[Movie], MovieLibraryError>) -> Void) {
    localData.access(onceLoaded: { data in
      completion(.success(Array(data.movies.values)))
    }, whenUnableToLoad: { error in
      completion(.failure(error))
    })
  }

  func fetchMovies(for id: GenreIdentifier, then completion: @escaping (Result<[Movie], MovieLibraryError>) -> Void) {
    localData.access(onceLoaded: { data in
      completion(.success(Array(data.movies.values.filter { $0.genreIds.contains(id) })))
    }, whenUnableToLoad: { error in
      completion(.failure(error))
    })
  }

  func addMovie(with tmdbID: TmdbIdentifier,
                diskType: DiskType,
                then completion: @escaping (Result<Movie, MovieLibraryError>) -> Void) {
    localData.access(onceLoaded: { data in
      if let recordID = data.recordIDsByTmdbID[tmdbID] {
        completion(.success(data.movies[recordID]!))
        return
      }
      guard let (title, tmdbProperties) = self.tmdbPropertiesProvider.tmdbProperties(for: tmdbID) else {
        completion(.failure(.detailsFetchError))
        return
      }
      let cloudProperties = Movie.CloudProperties(tmdbID: tmdbID,
                                                  libraryID: self.metadata.id,
                                                  title: title,
                                                  diskType: diskType)
      let record = MovieRecord(from: cloudProperties)
      self.syncManager.sync(record.rawRecord, in: self.metadata.databaseScope) { error in
        let movie = Movie(cloudProperties, tmdbProperties)
        self.addSyncCompletion(movie, record, error, completion)
      }
    }, whenUnableToLoad: { error in
      completion(.failure(error))
    })
  }

  private func addSyncCompletion(_ movie: Movie,
                                 _ record: MovieRecord,
                                 _ error: CloudKitError?,
                                 _ completion: @escaping (Result<Movie, MovieLibraryError>) -> Void) {
    if let error = error {
      switch error {
        case .notAuthenticated, .userDeletedZone, .permissionFailure, .nonRecoverableError:
          completion(.failure(error.asMovieLibraryError))
        case .conflict, .itemNoLongerExists, .zoneNotFound:
          fatalError("should not occur: \(error)")
      }
    } else {
      localData.access { data in
        if let existingMovieRecordID = data.recordIDsByTmdbID[movie.tmdbID] {
          os_log("aborting explicit adding, because movie has already been added via changes -> deleting duplicate",
                 log: DeviceSyncingMovieLibrary.logger,
                 type: .default)
          self.syncManager.delete([record.id], in: self.metadata.databaseScope)
          completion(.success(data.movies[existingMovieRecordID]!))
        } else {
          data.movies[movie.cloudProperties.id] = movie
          data.movieRecords[movie.cloudProperties.id] = record
          data.recordIDsByTmdbID[movie.cloudProperties.tmdbID] = record.id
          self.localData.persist()
          let changeSet = ChangeSet<TmdbIdentifier, Movie>(insertions: [movie])
          self.delegates.invoke { $0.library(self, didUpdateMovies: changeSet) }
          completion(.success(movie))
        }
      }
    }
  }

  func update(_ movie: Movie, then completion: @escaping (Result<Movie, MovieLibraryError>) -> Void) {
    precondition(movie.cloudProperties.libraryID == metadata.id)
    localData.access(onceLoaded: { data in
      guard let record = data.movieRecords[movie.cloudProperties.id] else {
        completion(.failure(.movieDoesNotExist))
        return
      }
      movie.cloudProperties.setCustomFields(in: record)
      self.syncManager.sync(record.rawRecord, in: self.metadata.databaseScope) { error in
        self.updateSyncCompletion(movie, record, error, completion)
      }
    }, whenUnableToLoad: { error in
      completion(.failure(error))
    })
  }

  private func updateSyncCompletion(_ movie: Movie,
                                    _ record: MovieRecord,
                                    _ error: CloudKitError?,
                                    _ completion: @escaping (Result<Movie, MovieLibraryError>) -> Void) {
    localData.access { data in
      if let error = error {
        switch error {
          case let .conflict(serverRecord):
            MovieRecord.copyCustomFields(from: record.rawRecord, to: serverRecord)
            data.movieRecords[movie.cloudProperties.id] = MovieRecord(serverRecord)
            os_log("resolved movie record conflict", log: DeviceSyncingMovieLibrary.logger, type: .default)
            self.update(movie, then: completion)
          case .itemNoLongerExists:
            if data.movies.removeValue(forKey: movie.cloudProperties.id) != nil {
              data.movieRecords.removeValue(forKey: movie.cloudProperties.id)
              let changeSet = ChangeSet<TmdbIdentifier, Movie>(deletions: [movie.tmdbID: movie])
              self.delegates.invoke { $0.library(self, didUpdateMovies: changeSet) }
            } else {
              // item has already been removed via changes
              assert(data.movieRecords[movie.cloudProperties.id] == nil)
            }
            completion(.failure(.movieDoesNotExist))
          case .userDeletedZone:
            completion(.failure(error.asMovieLibraryError))
          case .notAuthenticated, .permissionFailure, .nonRecoverableError:
            // need to reset record (changed keys)
            self.localData.requestReload()
            completion(.failure(error.asMovieLibraryError))
          case .zoneNotFound:
            fatalError("should not occur: \(error)")
        }
      } else {
        data.movies[movie.cloudProperties.id] = movie
        self.localData.persist()
        let changeSet = ChangeSet<TmdbIdentifier, Movie>(modifications: [movie.tmdbID: movie])
        self.delegates.invoke { $0.library(self, didUpdateMovies: changeSet) }
        completion(.success(movie))
      }
    }
  }

  func removeMovie(with tmdbID: TmdbIdentifier, then completion: @escaping (Result<Void, MovieLibraryError>) -> Void) {
    localData.access(onceLoaded: { data in
      guard let recordID = data.recordIDsByTmdbID[tmdbID] else {
        completion(.success(()))
        return
      }
      let movie = data.movies[recordID]!
      self.syncManager.delete(data.movieRecords[recordID]!.rawRecord, in: self.metadata.databaseScope) { error in
        self.removeSyncCompletion(movie, error, completion)
      }
    }, whenUnableToLoad: { error in
      completion(.failure(error))
    })
  }

  private func removeSyncCompletion(_ movie: Movie,
                                    _ error: CloudKitError?,
                                    _ completion: @escaping (Result<Void, MovieLibraryError>) -> Void) {
    if let error = error {
      switch error {
        case .itemNoLongerExists:
          completion(.success(()))
        case .notAuthenticated, .userDeletedZone, .permissionFailure, .nonRecoverableError:
          completion(.failure(error.asMovieLibraryError))
        case .conflict, .zoneNotFound:
          fatalError("should not occur: \(error)")
      }
    } else {
      localData.access { data in
        data.movies.removeValue(forKey: movie.cloudProperties.id)
        data.movieRecords.removeValue(forKey: movie.cloudProperties.id)
        data.recordIDsByTmdbID.removeValue(forKey: movie.tmdbID)
        self.localData.persist()
        let changeSet = ChangeSet<TmdbIdentifier, Movie>(deletions: [movie.tmdbID: movie])
        self.delegates.invoke { $0.library(self, didUpdateMovies: changeSet) }
        completion(.success(()))
      }
    }
  }
}

// MARK: - apply changes

extension DeviceSyncingMovieLibrary {
  func processChanges(_ changes: FetchedChanges) {
    localData.access(onceLoaded: { data in
      var changeSet = ChangeSet<TmdbIdentifier, Movie>()
      let duplicates = self.process(changedRecords: changes.changedRecords,
                                    changeSet: &changeSet,
                                    data: data)
      self.process(deletedRecordIDsAndTypes: changes.deletedRecordIDsAndTypes,
                   changeSet: &changeSet,
                   data: data)
      if !duplicates.isEmpty {
        os_log("found %d duplicates while processing changes -> deleting",
               log: DeviceSyncingMovieLibrary.logger,
               type: .default,
               duplicates.count)
        self.syncManager.delete(duplicates, in: self.metadata.databaseScope)
      }
      if changeSet.hasPublicChanges || changeSet.hasInternalChanges {
        self.localData.persist()
      }
      if changeSet.hasPublicChanges {
        self.delegates.invoke { $0.library(self, didUpdateMovies: changeSet) }
      }
    }, whenUnableToLoad: { error in
      os_log("unable to process changes, because loading failed: %{public}@",
             log: DeviceSyncingMovieLibrary.logger,
             type: .default,
             String(describing: error))
    })
  }

  private func process(changedRecords: [CKRecord],
                       changeSet: inout ChangeSet<TmdbIdentifier, Movie>,
                       data: MovieLibraryDataObject) -> [CKRecordID] {
    var duplicates = [CKRecordID]()
    for rawRecord in changedRecords where rawRecord.recordType == MovieRecord.recordType {
      let movieRecord = MovieRecord(rawRecord)
      guard movieRecord.library.recordID == metadata.id else { continue }
      let cloudProperties = Movie.CloudProperties(from: movieRecord)

      // check if a movie with this tmdb identifier already exists locally
      if let existingRecordID = data.recordIDsByTmdbID[cloudProperties.tmdbID] {
        if existingRecordID == movieRecord.id { // the underlying record changed
          data.movieRecords[movieRecord.id] = movieRecord
          if data.movies[existingRecordID]!.cloudProperties != cloudProperties { // this is a public change
            data.movies[existingRecordID]!.cloudProperties = cloudProperties
            changeSet.modifications[cloudProperties.tmdbID] = data.movies[cloudProperties.id]
          } else {
            changeSet.hasInternalChanges = true
          }
        } else { // found a new duplicate
          let existingRecord = data.movieRecords[existingRecordID]!
          if existingRecord.rawRecord.creationDate! <= movieRecord.rawRecord.creationDate! {
            duplicates.append(movieRecord.id)
          } else {
            duplicates.append(existingRecord.id)
            data.movies.removeValue(forKey: existingRecordID)
            data.movieRecords.removeValue(forKey: existingRecordID)
            let tmdbProperties: Movie.TmdbProperties
            if let (_, fetched) = self.tmdbPropertiesProvider.tmdbProperties(for: cloudProperties.tmdbID) {
              tmdbProperties = fetched
            } else {
              tmdbProperties = Movie.TmdbProperties()
            }
            let movie = Movie(cloudProperties, tmdbProperties)
            data.movies[movieRecord.id] = movie
            data.movieRecords[movieRecord.id] = movieRecord
            data.recordIDsByTmdbID[cloudProperties.tmdbID] = movieRecord.id
            changeSet.modifications[cloudProperties.tmdbID] = movie
          }
        }
      } else {
        let tmdbProperties: Movie.TmdbProperties
        if let (_, fetched) = self.tmdbPropertiesProvider.tmdbProperties(for: cloudProperties.tmdbID) {
          tmdbProperties = fetched
        } else {
          tmdbProperties = Movie.TmdbProperties()
        }
        let movie = Movie(cloudProperties, tmdbProperties)
        data.movies[movieRecord.id] = movie
        data.movieRecords[movieRecord.id] = movieRecord
        data.recordIDsByTmdbID[cloudProperties.tmdbID] = movieRecord.id
        changeSet.insertions.append(movie)
      }
    }
    return duplicates
  }

  private func process(deletedRecordIDsAndTypes: [(CKRecordID, String)],
                       changeSet: inout ChangeSet<TmdbIdentifier, Movie>,
                       data: MovieLibraryDataObject) {
    for (recordID, recordType) in deletedRecordIDsAndTypes
        where recordType == MovieRecord.recordType && data.movies[recordID] != nil {
      let movie = data.movies.removeValue(forKey: recordID)!
      data.movieRecords.removeValue(forKey: recordID)
      data.recordIDsByTmdbID.removeValue(forKey: movie.tmdbID)
      changeSet.deletions[movie.tmdbID] = movie
    }
  }

  func cleanupForRemoval() {
    localData.clear()
  }
}

extension DeviceSyncingMovieLibrary {
  func migrateMovies(from url: URL, then completion: @escaping (Bool) -> Void) {
    let data: Data
    do {
      data = try Data(contentsOf: url)
    } catch {
      os_log("unable to load movies from url: %{public}@",
             log: DeviceSyncingMovieLibrary.logger,
             type: .error,
             String(describing: error))
      completion(false)
      return
    }
    let legacyMovies = Legacy.deserialize(from: data)
    os_log("migrating %d movies", log: DeviceSyncingMovieLibrary.logger, type: .info, legacyMovies.count)
    batchInsert(legacyMovies, then: completion)
  }

  private func batchInsert(_ legacyMovies: [Legacy.LegacyMovieData],
                           then completion: @escaping (Bool) -> Void) {
    if legacyMovies.isEmpty {
      completion(true)
      return
    }
    let group = DispatchGroup()
    group.enter()
    var cloudData: [TmdbIdentifier: (Movie.CloudProperties, MovieRecord)]?
    DispatchQueue.global(qos: .userInitiated).async {
      self.prepareCloudData(for: legacyMovies) {
        cloudData = $0
        group.leave()
      }
    }
    group.enter()
    var tmdbData: [TmdbIdentifier: Movie.TmdbProperties]?
    DispatchQueue.global(qos: .userInitiated).async {
      self.prepareTmdbData(for: legacyMovies) {
        tmdbData = $0
        group.leave()
      }
    }
    group.notify(queue: DispatchQueue.global()) {
      self.didPrepareForBatchInsertion(legacyMovies, cloudData, tmdbData, completion)
    }
  }

  private func prepareCloudData(
      for legacyMovies: [Legacy.LegacyMovieData],
      then completion: @escaping ([TmdbIdentifier: (Movie.CloudProperties, MovieRecord)]?) -> Void) {
    let cloudData: [TmdbIdentifier: (Movie.CloudProperties, MovieRecord)] =
        Dictionary(uniqueKeysWithValues: legacyMovies.map {
          let cloudProperties = Movie.CloudProperties(tmdbID: $0.tmdbID,
                                                      libraryID: self.metadata.id,
                                                      title: $0.title,
                                                      subtitle: $0.subtitle,
                                                      diskType: $0.diskType)
          let record = MovieRecord(from: cloudProperties)
          return ($0.tmdbID, (cloudProperties, record))
        })
    let rawRecords = Array(cloudData.values.map { $0.1.rawRecord })
    self.syncManager.syncAll(rawRecords, in: metadata.databaseScope) { error in
      if let error = error {
        switch error {
          case .notAuthenticated, .userDeletedZone, .nonRecoverableError:
            os_log("unable to sync movies: %{public}@",
                   log: DeviceSyncingMovieLibrary.logger,
                   type: .error,
                   String(describing: error))
            completion(nil)
          case .conflict, .itemNoLongerExists, .zoneNotFound, .permissionFailure:
            fatalError("should not occur: \(error)")
        }
      } else {
        completion(cloudData)
      }
    }
  }

  private func prepareTmdbData(for legacyMovies: [Legacy.LegacyMovieData],
                               then completion: @escaping ([TmdbIdentifier: Movie.TmdbProperties]) -> Void) {
    let tmdbData: [TmdbIdentifier: Movie.TmdbProperties] = Dictionary(uniqueKeysWithValues: legacyMovies.map { movie in
      if let data = tmdbPropertiesProvider.tmdbProperties(for: movie.tmdbID) {
        return (movie.tmdbID, data.1)
      } else {
        return (movie.tmdbID, Movie.TmdbProperties())
      }
    })
    completion(tmdbData)
  }

  private func didPrepareForBatchInsertion(_ legacyMovies: [Legacy.LegacyMovieData],
                                           _ cloudData: [TmdbIdentifier: (Movie.CloudProperties, MovieRecord)]?,
                                           _ tmdbData: [TmdbIdentifier: Movie.TmdbProperties]?,
                                           _ completion: @escaping (Bool) -> Void) {
    guard let cloudData = cloudData, let tmdbData = tmdbData else {
      completion(false)
      return
    }
    localData.initializeWithDefaultValue()
    self.localData.access { data in
      var changeSet = ChangeSet<TmdbIdentifier, Movie>()
      for legacyMovie in legacyMovies {
        let (cloudProperties, record) = cloudData[legacyMovie.tmdbID]!
        let tmdbProperties = tmdbData[legacyMovie.tmdbID]!
        let movie = Movie(cloudProperties, tmdbProperties)
        data.movies[movie.cloudProperties.id] = movie
        data.movieRecords[movie.cloudProperties.id] = record
        data.recordIDsByTmdbID[movie.cloudProperties.tmdbID] = record.id
        changeSet.insertions.append(movie)
      }
      self.localData.persist()
      self.delegates.invoke { $0.library(self, didUpdateMovies: changeSet) }
      completion(true)
    }
  }
}
