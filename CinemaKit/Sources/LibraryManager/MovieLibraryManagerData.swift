import CloudKit
import os.log

class MovieLibraryManagerDataObject {
  var libraries: [CKRecord.ID: InternalMovieLibrary]
  var libraryRecords: [CKRecord.ID: LibraryRecord]
  var shareRecords: [CKRecord.ID: CKShare]

  init(libraries: [CKRecord.ID: InternalMovieLibrary],
       libraryRecords: [CKRecord.ID: LibraryRecord],
       shareRecords: [CKRecord.ID: CKShare]) {
    self.libraries = libraries
    self.libraryRecords = libraryRecords
    self.shareRecords = shareRecords
  }
}

class MovieLibraryManagerData: LazyData<MovieLibraryManagerDataObject, MovieLibraryManagerError> {
  private static let logger = Logging.createLogger(category: "MovieLibraryManagerData")

  private let queueFactory: DatabaseOperationQueueFactory
  private let fetchManager: FetchManager
  private let libraryFactory: MovieLibraryFactory
  private let libraryRecordStore: PersistentRecordStore
  private let shareRecordStore: PersistentRecordStore

  init(queueFactory: DatabaseOperationQueueFactory,
       fetchManager: FetchManager,
       libraryFactory: MovieLibraryFactory,
       libraryRecordStore: PersistentRecordStore,
       shareRecordStore: PersistentRecordStore) {
    self.queueFactory = queueFactory
    self.fetchManager = fetchManager
    self.libraryFactory = libraryFactory
    self.libraryRecordStore = libraryRecordStore
    self.shareRecordStore = shareRecordStore
    super.init(label: "de.martinbauer.cinema.MovieLibraryManagerData")
  }

  override func loadData() {
    if let rawLibraryRecords = libraryRecordStore.loadRecords(),
       let rawShareRecords = shareRecordStore.loadRecords(asCKShare: true) {
      os_log("loaded records from stores", log: MovieLibraryManagerData.logger, type: .debug)
      // swiftlint:disable:next force_cast
      makeData(rawLibraryRecords.map { LibraryRecord($0) }, rawShareRecords.map { $0 as! CKShare })
    } else {
      os_log("loading records from cloud", log: MovieLibraryManagerData.logger, type: .debug)
      fetchLibraryRecords()
    }
  }

  private func fetchLibraryRecords() {
    let group = DispatchGroup()
    group.enter()
    var privateLibraries: Result<[LibraryRecord], MovieLibraryManagerError>!
    self.fetchPrivateLibraryRecords {
      privateLibraries = $0
      group.leave()
    }
    group.enter()
    var sharedLibraries: Result<[LibraryRecord], MovieLibraryManagerError>!
    self.fetchSharedZones {
      sharedLibraries = $0
      group.leave()
    }
    group.notify(queue: DispatchQueue.global()) {
      self.didFetchLibraryRecords(privateLibraries, sharedLibraries)
    }
  }

  private func didFetchLibraryRecords(_ privateLibrariesResult: Result<[LibraryRecord], MovieLibraryManagerError>,
                                      _ sharedLibrariesResult: Result<[LibraryRecord], MovieLibraryManagerError>) {
    if case let .success(privateLibraryRecords) = privateLibrariesResult,
       case let .success(sharedLibraryRecords) = sharedLibrariesResult {
      let allLibraryRecords = privateLibraryRecords + sharedLibraryRecords
      let libraryRecordsWithShareID = allLibraryRecords.filter { $0.shareID != nil }
      if libraryRecordsWithShareID.isEmpty {
        os_log("saving fetched records to stores", log: MovieLibraryManagerData.logger, type: .debug)
        libraryRecordStore.save(allLibraryRecords)
        shareRecordStore.save([])
        makeData(allLibraryRecords, [])
      } else {
        os_log("there are %d shared libraries -> loading share records",
               log: MovieLibraryManagerData.logger,
               type: .debug,
               libraryRecordsWithShareID.count)
        fetchShareRecords(for: libraryRecordsWithShareID) { result in
          self.didFetchShareRecords(result, allLibraryRecords)
        }
      }
    } else if case let .failure(error) = privateLibrariesResult {
      abortLoading(with: error)
    } else if case let .failure(error) = sharedLibrariesResult {
      abortLoading(with: error)
    }
  }

  private func didFetchShareRecords(_ shareRecordsResult: Result<[CKShare], MovieLibraryManagerError>,
                                    _ libraryRecords: [LibraryRecord]) {
    switch shareRecordsResult {
      case let .failure(error):
        abortLoading(with: error)
      case let .success(shareRecords):
        os_log("saving fetched records to stores", log: MovieLibraryManagerData.logger, type: .debug)
        libraryRecordStore.save(libraryRecords)
        shareRecordStore.save(shareRecords)
        makeData(libraryRecords, shareRecords)
    }
  }

  private func makeData(_ libraryRecords: [LibraryRecord], _ shareRecords: [CKShare]) {
    let minimumCapacity = libraryRecords.count
    var librariesDict: [CKRecord.ID: InternalMovieLibrary] = Dictionary(minimumCapacity: minimumCapacity)
    var libraryRecordsDict: [CKRecord.ID: LibraryRecord] = Dictionary(minimumCapacity: minimumCapacity)
    let shareRecordsDict = Dictionary(uniqueKeysWithValues: shareRecords.map { ($0.recordID, $0) })
    for libraryRecord in libraryRecords {
      let currentUserCanModify: Bool
      if let shareRecordID = libraryRecord.shareID {
        if let shareRecord = shareRecordsDict[shareRecordID] {
          currentUserCanModify = shareRecord.currentUserParticipant?.permission == .readWrite
        } else {
          os_log("found library record without corresponding CKShare -> reloading",
                 log: MovieLibraryManagerData.logger,
                 type: .default)
          clear()
          fetchLibraryRecords()
          return
        }
      } else {
        currentUserCanModify = true
      }
      let metadata = MovieLibraryMetadata(from: libraryRecord, currentUserCanModify: currentUserCanModify)
      librariesDict[libraryRecord.id] = libraryFactory.makeLibrary(with: metadata)
      libraryRecordsDict[libraryRecord.id] = libraryRecord
    }
    completeLoading(with: MovieLibraryManagerDataObject(libraries: librariesDict,
                                                        libraryRecords: libraryRecordsDict,
                                                        shareRecords: shareRecordsDict))
  }

  override func persist(_ data: MovieLibraryManagerDataObject) {
    os_log("saving records to stores", log: MovieLibraryManagerData.logger, type: .debug)
    libraryRecordStore.save(Array(data.libraryRecords.values))
    shareRecordStore.save(Array(data.shareRecords.values))
  }

  override func clear() {
    os_log("removing stores", log: MovieLibraryManagerData.logger, type: .debug)
    libraryRecordStore.clear()
    shareRecordStore.clear()
  }
}

// MARK: - Fetching Libraries From Cloud

extension MovieLibraryManagerData {
  private func fetchPrivateLibraryRecords(
      then completion: @escaping (Result<[LibraryRecord], MovieLibraryManagerError>) -> Void) {
    fetchManager.fetch(LibraryRecord.self,
                       inZoneWithID: deviceSyncZoneID,
                       using: queueFactory.queue(withScope: .private)) { records, error in
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

  private func fetchSharedZones(
      then completion: @escaping (Result<[LibraryRecord], MovieLibraryManagerError>) -> Void) {
    fetchManager.fetchZones(using: queueFactory.queue(withScope: .shared)) { zones, error in
      if let error = error {
        switch error {
          case .notAuthenticated:
            completion(.failure(.globalError(.notAuthenticated)))
          case .nonRecoverableError:
            completion(.failure(.nonRecoverableError))
          case .conflict, .itemNoLongerExists, .userDeletedZone, .zoneNotFound, .permissionFailure:
            fatalError("should not occur: \(error)")
        }
      } else if let zones = zones {
        let zoneIDs = Array(zones.keys)
        if zoneIDs.isEmpty {
          completion(.success([]))
        } else {
          self.fetchSharedLibraryRecords(in: zoneIDs, then: completion)
        }
      }
    }
  }

  private func fetchSharedLibraryRecords(
      in zoneIDs: [CKRecordZone.ID],
      then completion: @escaping (Result<[LibraryRecord], MovieLibraryManagerError>) -> Void) {
    let group = DispatchGroup()
    var metadataRecords = [LibraryRecord]()
    var errors = [MovieLibraryManagerError]()
    for zoneID in zoneIDs {
      group.enter()
      fetchManager.fetch(LibraryRecord.self,
                         inZoneWithID: zoneID,
                         using: queueFactory.queue(withScope: .shared)) { records, error in
        if let error = error {
          switch error {
            case .zoneNotFound:
              // owner of library stopped sharing
              break
            case .notAuthenticated:
              errors.append(.globalError(.notAuthenticated))
            case .nonRecoverableError:
              errors.append(.nonRecoverableError)
            case .conflict, .itemNoLongerExists, .userDeletedZone, .permissionFailure:
              fatalError("should not occur: \(error)")
          }
        } else if let records = records {
          metadataRecords.append(contentsOf: records)
        }
        group.leave()
      }
    }
    group.notify(queue: DispatchQueue.global()) {
      if errors.isEmpty {
        completion(.success(metadataRecords))
      } else {
        completion(.failure(errors.first!))
      }
    }
  }

  private func fetchShareRecords(
      for records: [LibraryRecord],
      then completion: @escaping (Result<[CKShare], MovieLibraryManagerError>) -> Void) {
    let group = DispatchGroup()
    var shareRecords = [CKShare]()
    var errors = [MovieLibraryManagerError]()
    for record in records {
      group.enter()
      guard let shareID = record.shareID else { fatalError("record is not shared") }
      let scope = shareID.zoneID.ownerName == CKCurrentUserDefaultName
          ? CKDatabase.Scope.private
          : CKDatabase.Scope.shared
      fetchManager.fetchRecord(with: shareID, using: queueFactory.queue(withScope: scope)) { rawRecord, error in
        if let error = error {
          switch error {
            case .zoneNotFound:
              // owner of library stopped sharing
              break
            case .notAuthenticated:
              errors.append(.globalError(.notAuthenticated))
            case .nonRecoverableError:
              errors.append(.nonRecoverableError)
            case .conflict, .itemNoLongerExists, .userDeletedZone, .permissionFailure:
              fatalError("should not occur: \(error)")
          }
        } else if let shareRecord = rawRecord as? CKShare {
          shareRecords.append(shareRecord)
        }
        group.leave()
      }
    }
    group.notify(queue: DispatchQueue.global()) {
      if let error = errors.first {
        completion(.failure(error))
      } else {
        completion(.success(shareRecords))
      }
    }
  }
}
