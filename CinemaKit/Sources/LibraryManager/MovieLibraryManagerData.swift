import CloudKit
import os.log

class MovieLibraryManagerDataObject {
  var libraries: [CKRecordID: InternalMovieLibrary]
  var libraryRecords: [CKRecordID: LibraryRecord]

  init(libraries: [CKRecordID: InternalMovieLibrary],
       libraryRecords: [CKRecordID: LibraryRecord]) {
    self.libraries = libraries
    self.libraryRecords = libraryRecords
  }
}

class MovieLibraryManagerData: RecordData<MovieLibraryManagerDataObject, MovieLibraryManagerError> {
  private static let logger = Logging.createLogger(category: "MovieLibraryManagerData")

  private let queueFactory: DatabaseOperationQueueFactory
  private let fetchManager: FetchManager
  private let libraryFactory: MovieLibraryFactory
  private let libraryRecordStore: PersistentRecordStore

  init(queueFactory: DatabaseOperationQueueFactory,
       fetchManager: FetchManager,
       libraryFactory: MovieLibraryFactory,
       libraryRecordStore: PersistentRecordStore) {
    self.queueFactory = queueFactory
    self.fetchManager = fetchManager
    self.libraryFactory = libraryFactory
    self.libraryRecordStore = libraryRecordStore
    super.init(label: "de.martinbauer.cinema.MovieLibraryManagerData")
  }

  override func loadData() {
    if let rawLibraryRecords = libraryRecordStore.loadRecords() {
      os_log("loaded records from store", log: MovieLibraryManagerData.logger, type: .debug)
      makeData(rawLibraryRecords.map { LibraryRecord($0) })
    } else {
      os_log("loading records from cloud", log: MovieLibraryManagerData.logger, type: .debug)
      fetchLibraryRecords()
    }
  }

  private func fetchLibraryRecords() {
    self.fetchPrivateLibraryRecords { result in
      self.didFetchLibraryRecords(result)
    }
  }

  private func didFetchLibraryRecords(_ privateLibrariesResult: Result<[LibraryRecord], MovieLibraryManagerError>) {
    if case let .success(privateLibraryRecords) = privateLibrariesResult {
      os_log("saving fetched records to store", log: MovieLibraryManagerData.logger, type: .debug)
      libraryRecordStore.save(privateLibraryRecords)
      makeData(privateLibraryRecords)
    } else if case let .failure(error) = privateLibrariesResult {
      abortLoading(with: error)
    }
  }

  private func makeData(_ libraryRecords: [LibraryRecord]) {
    let minimumCapacity = libraryRecords.count
    var librariesDict: [CKRecordID: InternalMovieLibrary] = Dictionary(minimumCapacity: minimumCapacity)
    var libraryRecordsDict: [CKRecordID: LibraryRecord] = Dictionary(minimumCapacity: minimumCapacity)
    for libraryRecord in libraryRecords {
      let metadata = MovieLibraryMetadata(from: libraryRecord)
      librariesDict[libraryRecord.id] = libraryFactory.makeLibrary(with: metadata)
      libraryRecordsDict[libraryRecord.id] = libraryRecord
    }
    completeLoading(with: MovieLibraryManagerDataObject(libraries: librariesDict,
                                                        libraryRecords: libraryRecordsDict))
  }

  override func persist(_ data: MovieLibraryManagerDataObject) {
    os_log("saving records to store", log: MovieLibraryManagerData.logger, type: .debug)
    libraryRecordStore.save(Array(data.libraryRecords.values))
  }

  override func clear() {
    os_log("removing store", log: MovieLibraryManagerData.logger, type: .debug)
    libraryRecordStore.clear()
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
          case .conflict, .itemNoLongerExists, .zoneNotFound:
            fatalError("should not occur: \(error)")
        }
      } else if let records = records {
        completion(.success(records))
      }
    }
  }
}
