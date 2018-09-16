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
  private var modelController: AnyModelController<MovieLibraryModel, MovieLibraryError>
  private let tmdbPropertiesProvider: TmdbMoviePropertiesProvider
  private let syncManager: SyncManager

  init<Controller: ModelController>(metadata: MovieLibraryMetadata,
                                    modelController: Controller,
                                    tmdbPropertiesProvider: TmdbMoviePropertiesProvider,
                                    syncManager: SyncManager)
      where Controller.ModelType == MovieLibraryModel, Controller.ErrorType == MovieLibraryError {
    self.metadata = metadata
    self.modelController = AnyModelController(modelController)
    self.tmdbPropertiesProvider = tmdbPropertiesProvider
    self.syncManager = syncManager
  }
}

// MARK: - core functionality

extension DeviceSyncingMovieLibrary {
  func fetchMovies(then completion: @escaping (Result<[Movie], MovieLibraryError>) -> Void) {
    modelController.access(onceLoaded: { model in
      completion(.success(Array(model.allMovies)))
    }, whenUnableToLoad: { error in
      completion(.failure(error))
    })
  }

  func fetchMovies(for id: GenreIdentifier, then completion: @escaping (Result<[Movie], MovieLibraryError>) -> Void) {
    modelController.access(onceLoaded: { model in
      completion(.success(Array(model.allMovies.filter { $0.genreIds.contains(id) })))
    }, whenUnableToLoad: { error in
      completion(.failure(error))
    })
  }

  func addMovie(with tmdbID: TmdbIdentifier,
                diskType: DiskType,
                then completion: @escaping (Result<Movie, MovieLibraryError>) -> Void) {
    modelController.access(onceLoaded: { model in
      if let existingMovie = model.movie(for: tmdbID) {
        completion(.success(existingMovie))
        return
      }
      guard let (title, tmdbProperties) = self.tmdbPropertiesProvider.tmdbProperties(for: tmdbID) else {
        completion(.failure(.tmdbDetailsCouldNotBeFetched))
        return
      }
      let cloudProperties = Movie.CloudProperties(tmdbID: tmdbID,
                                                  libraryID: self.metadata.id,
                                                  title: title,
                                                  diskType: diskType)
      let newRecord = MovieRecord(from: cloudProperties)
      self.syncManager.sync(newRecord.rawRecord, in: self.metadata.databaseScope) { error in
        let newMovie = Movie(cloudProperties, tmdbProperties)
        self.addSyncCompletion(newMovie, newRecord, error, completion)
      }
    }, whenUnableToLoad: { error in
      completion(.failure(error))
    })
  }

  private func addSyncCompletion(_ newMovie: Movie,
                                 _ newRecord: MovieRecord,
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
      modelController.access { model in
        if let existingMovie = model.movie(for: newMovie.tmdbID) {
          os_log("aborting explicit adding, because movie has already been added via changes -> deleting duplicate",
                 log: DeviceSyncingMovieLibrary.logger,
                 type: .default)
          self.syncManager.delete([newRecord.id], in: self.metadata.databaseScope)
          completion(.success(existingMovie))
        } else {
          model.add(newMovie, with: newRecord)
          self.modelController.persist()
          let changeSet = ChangeSet<TmdbIdentifier, Movie>(insertions: [newMovie])
          self.delegates.invoke { $0.library(self, didUpdateMovies: changeSet) }
          completion(.success(newMovie))
        }
      }
    }
  }

  func update(_ movie: Movie, then completion: @escaping (Result<Movie, MovieLibraryError>) -> Void) {
    precondition(movie.cloudProperties.libraryID == metadata.id)
    modelController.access(onceLoaded: { model in
      guard let record = model.record(for: movie) else {
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
    modelController.access { model in
      if let error = error {
        switch error {
          case let .conflict(serverRecord):
            MovieRecord.copyCustomFields(from: record.rawRecord, to: serverRecord)
            model.update(movie, and: MovieRecord(serverRecord))
            os_log("resolved movie record conflict", log: DeviceSyncingMovieLibrary.logger, type: .default)
            self.update(movie, then: completion)
          case .itemNoLongerExists:
            if let movie = model.remove(movie.id) {
              self.modelController.persist()
              let changeSet = ChangeSet<TmdbIdentifier, Movie>(deletions: [movie.tmdbID: movie])
              self.delegates.invoke { $0.library(self, didUpdateMovies: changeSet) }
            }
            completion(.failure(.movieDoesNotExist))
          case .userDeletedZone:
            completion(.failure(error.asMovieLibraryError))
          case .notAuthenticated, .permissionFailure, .nonRecoverableError:
            // need to reset record (changed keys)
            self.modelController.requestReload()
            completion(.failure(error.asMovieLibraryError))
          case .zoneNotFound:
            fatalError("should not occur: \(error)")
        }
      } else {
        model.update(movie, and: record)
        self.modelController.persist()
        let changeSet = ChangeSet<TmdbIdentifier, Movie>(modifications: [movie.tmdbID: movie])
        self.delegates.invoke { $0.library(self, didUpdateMovies: changeSet) }
        completion(.success(movie))
      }
    }
  }

  func removeMovie(with tmdbID: TmdbIdentifier, then completion: @escaping (Result<Void, MovieLibraryError>) -> Void) {
    modelController.access(onceLoaded: { model in
      guard let movie = model.movie(for: tmdbID) else {
        completion(.success(()))
        return
      }
      self.syncManager.delete(model.record(for: movie)!.rawRecord, in: self.metadata.databaseScope) { error in
        self.removeSyncCompletion(movie, error, completion)
      }
    }, whenUnableToLoad: { error in
      completion(.failure(error))
    })
  }

  private func removeSyncCompletion(_ movie: Movie,
                                    _ error: CloudKitError?,
                                    _ completion: @escaping (Result<Void, MovieLibraryError>) -> Void) {
    modelController.access { model in
      if let error = error {
        switch error {
          case .itemNoLongerExists:
            if model.remove(movie.id) != nil {
              self.modelController.persist()
              let changeSet = ChangeSet<TmdbIdentifier, Movie>(deletions: [movie.tmdbID: movie])
              self.delegates.invoke { $0.library(self, didUpdateMovies: changeSet) }
            }
            completion(.success(()))
          case .notAuthenticated, .userDeletedZone, .permissionFailure, .nonRecoverableError:
            completion(.failure(error.asMovieLibraryError))
          case .conflict, .zoneNotFound:
            fatalError("should not occur: \(error)")
        }
      } else {
        if model.remove(movie.id) != nil {
          self.modelController.persist()
          let changeSet = ChangeSet<TmdbIdentifier, Movie>(deletions: [movie.tmdbID: movie])
          self.delegates.invoke { $0.library(self, didUpdateMovies: changeSet) }
        }
        completion(.success(()))
      }
    }
  }
}

// MARK: - apply changes

extension DeviceSyncingMovieLibrary {
  func processChanges(_ changes: FetchedChanges) {
    modelController.access(onceLoaded: { model in
      var changeSet = ChangeSet<TmdbIdentifier, Movie>()
      if !changes.changedRecords.isEmpty {
        let duplicates = self.process(changedRecords: changes.changedRecords,
                                      changeSet: &changeSet,
                                      model: model)
        if !duplicates.isEmpty {
          os_log("found %d duplicates while processing changes -> deleting",
                 log: DeviceSyncingMovieLibrary.logger,
                 type: .default,
                 duplicates.count)
          self.syncManager.delete(duplicates, in: self.metadata.databaseScope)
        }
      }
      if !changes.deletedRecordIDsAndTypes.isEmpty {
        self.process(deletedRecordIDsAndTypes: changes.deletedRecordIDsAndTypes,
                     changeSet: &changeSet,
                     model: model)
      }
      if changeSet.hasPublicChanges || changeSet.hasInternalChanges {
        self.modelController.persist()
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
                       model: MovieLibraryModel) -> [CKRecord.ID] {
    var duplicates = [CKRecord.ID]()
    for rawRecord in changedRecords where rawRecord.recordType == MovieRecord.recordType {
      let movieRecord = MovieRecord(rawRecord)
      guard movieRecord.library.recordID == metadata.id else { continue }
      let cloudProperties = Movie.CloudProperties(from: movieRecord)

      // check if a movie with this tmdb identifier already exists locally
      if let existingMovie = model.movie(for: cloudProperties.tmdbID) {
        if existingMovie.id == movieRecord.id { // the underlying record changed
          let updatedMovie = Movie(cloudProperties, existingMovie.tmdbProperties)
          model.update(updatedMovie, and: movieRecord)
          if existingMovie.cloudProperties == cloudProperties {
            changeSet.hasInternalChanges = true
          } else {
            changeSet.modifications[existingMovie.tmdbID] = updatedMovie
          }
        } else { // found a new duplicate
          let existingRecord = model.record(for: existingMovie)!
          if existingRecord.rawRecord.creationDate! <= movieRecord.rawRecord.creationDate! {
            duplicates.append(movieRecord.id)
          } else {
            duplicates.append(existingRecord.id)
            model.remove(existingMovie.id)
            let olderMovie = Movie(cloudProperties, existingMovie.tmdbProperties)
            model.add(olderMovie, with: movieRecord)
            if existingMovie.cloudProperties == cloudProperties {
              changeSet.hasInternalChanges = true
            } else {
              changeSet.modifications[existingMovie.tmdbID] = olderMovie
            }
          }
        }
      } else {
        let tmdbProperties: Movie.TmdbProperties
        if let (_, fetched) = self.tmdbPropertiesProvider.tmdbProperties(for: cloudProperties.tmdbID) {
          tmdbProperties = fetched
        } else {
          tmdbProperties = Movie.TmdbProperties()
        }
        let newMovie = Movie(cloudProperties, tmdbProperties)
        model.add(newMovie, with: movieRecord)
        changeSet.insertions.append(newMovie)
      }
    }
    return duplicates
  }

  private func process(deletedRecordIDsAndTypes: [(CKRecord.ID, CKRecord.RecordType)],
                       changeSet: inout ChangeSet<TmdbIdentifier, Movie>,
                       model: MovieLibraryModel) {
    for (recordID, recordType) in deletedRecordIDsAndTypes where recordType == MovieRecord.recordType {
      if let movie = model.remove(recordID) {
        changeSet.deletions[movie.tmdbID] = movie
      }
    }
  }

  func cleanupForRemoval() {
    modelController.clear()
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
      if let model = tmdbPropertiesProvider.tmdbProperties(for: movie.tmdbID) {
        return (movie.tmdbID, model.1)
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
    modelController.initializeWithDefaultValue()
    self.modelController.access { model in
      var changeSet = ChangeSet<TmdbIdentifier, Movie>()
      for legacyMovie in legacyMovies {
        let (cloudProperties, record) = cloudData[legacyMovie.tmdbID]!
        let tmdbProperties = tmdbData[legacyMovie.tmdbID]!
        let movie = Movie(cloudProperties, tmdbProperties)
        model.add(movie, with: record)
        changeSet.insertions.append(movie)
      }
      self.modelController.persist()
      self.delegates.invoke { $0.library(self, didUpdateMovies: changeSet) }
      completion(true)
    }
  }
}
