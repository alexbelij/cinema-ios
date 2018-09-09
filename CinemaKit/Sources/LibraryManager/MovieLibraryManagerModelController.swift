import CloudKit
import os.log

class MovieLibraryManagerModel {
  var libraries: [CKRecordID: InternalMovieLibrary]
  var libraryRecords: [CKRecordID: LibraryRecord]
  var libraryRecordIDByShareRecordID: [CKRecordID: CKRecordID]
  var shareRecords: [CKRecordID: CKShare]

  init(libraries: [CKRecordID: InternalMovieLibrary],
       libraryRecords: [CKRecordID: LibraryRecord],
       shareRecords: [CKRecordID: CKShare]) {
    self.libraries = libraries
    self.libraryRecords = libraryRecords
    self.libraryRecordIDByShareRecordID = Dictionary(minimumCapacity: libraryRecords.count)
    for (libraryID, libraryRecord) in libraryRecords {
      if let shareID = libraryRecord.shareID, shareRecords[shareID] != nil {
        libraryRecordIDByShareRecordID[shareID] = libraryID
      }
    }
    self.shareRecords = shareRecords
  }

  var allLibraries: [InternalMovieLibrary] {
    return Array(libraries.values)
  }

  func library(withShareRecordID recordID: CKRecordID) -> InternalMovieLibrary? {
    guard let libraryID = libraryRecordIDByShareRecordID[recordID] else { return nil }
    return libraries[libraryID]
  }

  func library(for recordID: CKRecordID) -> InternalMovieLibrary? {
    return libraries[recordID]
  }

  func record(for recordID: CKRecordID) -> LibraryRecord? {
    return libraryRecords[recordID]
  }

  func share(for metadata: MovieLibraryMetadata) -> CKShare? {
    guard let shareRecordID = metadata.shareRecordID else { preconditionFailure("library is not shared") }
    return shareRecords[shareRecordID]
  }

  func add(_ library: InternalMovieLibrary, with record: LibraryRecord, _ share: CKShare? = nil) {
    libraries[record.id] = library
    libraryRecords[record.id] = record
    if let share = share {
      shareRecords[share.recordID] = share
    }
  }

  func setShare(_ share: CKShare?, with record: LibraryRecord) {
    guard let existingRecord = libraryRecords[record.id],
          let library = libraries[record.id] else {
      preconditionFailure("library does not exist")
    }
    let newMetadata: MovieLibraryMetadata
    if let share = share {
      precondition(share.recordID == record.shareID)
      shareRecords[share.recordID] = share
      newMetadata = MovieLibraryMetadata(from: record, share)
    } else {
      guard let shareRecordID = existingRecord.shareID else { preconditionFailure("record was not shared") }
      shareRecords.removeValue(forKey: shareRecordID)
      newMetadata = MovieLibraryMetadata(from: record)
    }
    libraryRecords[record.id] = record
    library.metadata = newMetadata
  }

  func update(_ record: LibraryRecord) {
    guard let existingRecord = libraryRecords[record.id],
          let library = libraries[record.id] else { preconditionFailure("library does not exist") }
    libraryRecords[record.id] = record
    let newMetadata: MovieLibraryMetadata
    if let shareRecordID = record.shareID, let share = shareRecords[shareRecordID] {
      precondition(existingRecord.shareID == shareRecordID)
      newMetadata = MovieLibraryMetadata(from: record, share)
    } else {
      newMetadata = MovieLibraryMetadata(from: record)
      if let shareRecordID = existingRecord.shareID {
        shareRecords.removeValue(forKey: shareRecordID)
      }
    }
    library.metadata = newMetadata
  }

  func updateShare(_ share: CKShare) {
    guard let library = self.library(withShareRecordID: share.recordID),
          let record = libraryRecords[library.metadata.id] else {
      preconditionFailure("library with given share does not exist")
    }
    shareRecords[share.recordID] = share
    library.metadata = MovieLibraryMetadata(from: record, share)
  }

  @discardableResult
  func remove(_ recordID: CKRecordID) -> InternalMovieLibrary? {
    guard let library = libraries.removeValue(forKey: recordID) else { return nil }
    libraryRecords.removeValue(forKey: recordID)
    if let shareRecordID = library.metadata.shareRecordID {
      shareRecords.removeValue(forKey: shareRecordID)
    }
    library.cleanupForRemoval()
    return library
  }
}

// swiftlint:disable:next colon
class MovieLibraryManagerModelController:
    ThreadSafeModelController<MovieLibraryManagerModel, MovieLibraryManagerError> {
  private static let logger = Logging.createLogger(category: "MovieLibraryManagerModelController")

  private let fetchManager: FetchManager
  private let libraryFactory: MovieLibraryFactory
  private let libraryRecordStore: PersistentRecordStore
  private let shareRecordStore: PersistentRecordStore

  init(fetchManager: FetchManager,
       libraryFactory: MovieLibraryFactory,
       libraryRecordStore: PersistentRecordStore,
       shareRecordStore: PersistentRecordStore) {
    self.fetchManager = fetchManager
    self.libraryFactory = libraryFactory
    self.libraryRecordStore = libraryRecordStore
    self.shareRecordStore = shareRecordStore
    super.init(label: "de.martinbauer.cinema.MovieLibraryManagerModelController")
  }

  override func makeWithDefaultValue() -> MovieLibraryManagerModel {
    fatalError("not supported")
  }

  override func loadModel() {
    if let rawLibraryRecords = libraryRecordStore.loadRecords(),
       let rawShareRecords = shareRecordStore.loadRecords(asCKShare: true) {
      os_log("loaded records from stores", log: MovieLibraryManagerModelController.logger, type: .debug)
      // swiftlint:disable:next force_cast
      makeModel(rawLibraryRecords.map { LibraryRecord($0) }, rawShareRecords.map { $0 as! CKShare })
    } else {
      os_log("loading records from cloud", log: MovieLibraryManagerModelController.logger, type: .debug)
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
        os_log("saving fetched records to stores", log: MovieLibraryManagerModelController.logger, type: .debug)
        libraryRecordStore.save(allLibraryRecords)
        shareRecordStore.save([])
        makeModel(allLibraryRecords, [])
      } else {
        os_log("there are %d shared libraries -> loading share records",
               log: MovieLibraryManagerModelController.logger,
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
        os_log("saving fetched records to stores", log: MovieLibraryManagerModelController.logger, type: .debug)
        libraryRecordStore.save(libraryRecords)
        shareRecordStore.save(shareRecords)
        makeModel(libraryRecords, shareRecords)
    }
  }

  private func makeModel(_ libraryRecords: [LibraryRecord], _ shareRecords: [CKShare]) {
    let minimumCapacity = libraryRecords.count
    var librariesDict: [CKRecordID: InternalMovieLibrary] = Dictionary(minimumCapacity: minimumCapacity)
    var libraryRecordsDict: [CKRecordID: LibraryRecord] = Dictionary(minimumCapacity: minimumCapacity)
    let shareRecordsDict = Dictionary(uniqueKeysWithValues: shareRecords.map { ($0.recordID, $0) })
    for libraryRecord in libraryRecords {
      let metadata: MovieLibraryMetadata
      if let shareRecordID = libraryRecord.shareID,
         let shareRecord = shareRecordsDict[shareRecordID] {
        metadata = MovieLibraryMetadata(from: libraryRecord, shareRecord)
      } else {
        metadata = MovieLibraryMetadata(from: libraryRecord)
      }
      librariesDict[libraryRecord.id] = libraryFactory.makeLibrary(with: metadata)
      libraryRecordsDict[libraryRecord.id] = libraryRecord
    }
    completeLoading(with: MovieLibraryManagerModel(libraries: librariesDict,
                                                   libraryRecords: libraryRecordsDict,
                                                   shareRecords: shareRecordsDict))
  }

  override func persist(_ model: MovieLibraryManagerModel) {
    os_log("saving records to stores", log: MovieLibraryManagerModelController.logger, type: .debug)
    libraryRecordStore.save(Array(model.libraryRecords.values))
    shareRecordStore.save(Array(model.shareRecords.values))
  }

  override func removePersistedModel() {
    os_log("removing stores", log: MovieLibraryManagerModelController.logger, type: .debug)
    libraryRecordStore.clear()
    shareRecordStore.clear()
  }
}

// MARK: - Fetching Libraries From Cloud

extension MovieLibraryManagerModelController {
  private func fetchPrivateLibraryRecords(
      then completion: @escaping (Result<[LibraryRecord], MovieLibraryManagerError>) -> Void) {
    fetchManager.fetch(LibraryRecord.self, inZoneWithID: deviceSyncZoneID, in: .private) { records, error in
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
    fetchManager.fetchZones(in: .shared) { zones, error in
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
      in zoneIDs: [CKRecordZoneID],
      then completion: @escaping (Result<[LibraryRecord], MovieLibraryManagerError>) -> Void) {
    let group = DispatchGroup()
    var metadataRecords = [LibraryRecord]()
    var errors = [MovieLibraryManagerError]()
    for zoneID in zoneIDs {
      group.enter()
      fetchManager.fetch(LibraryRecord.self, inZoneWithID: zoneID, in: .shared) { records, error in
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
          ? CKDatabaseScope.private
          : CKDatabaseScope.shared
      fetchManager.fetchRecord(with: shareID, in: scope) { rawRecord, error in
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