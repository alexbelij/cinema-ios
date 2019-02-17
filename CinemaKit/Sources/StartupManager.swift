import CloudKit
import Foundation
import os.log
import UIKit

struct LocalDataInvalidationFlag {
  fileprivate static let key = UserDefaultsKey<Bool>("ShouldResetLocalData")

  private let userDefaults: UserDefaultsProtocol

  init(userDefaults: UserDefaultsProtocol) {
    self.userDefaults = userDefaults
  }

  var isSet: Bool {
    return userDefaults.get(for: LocalDataInvalidationFlag.key)
  }

  func set() {
    userDefaults.set(true, for: LocalDataInvalidationFlag.key)
  }
}

public protocol StartupManager {
  func initialize(handler: @escaping (StartupProgress) -> Void)
}

public enum StartupProgress {
  case settingUpCloudEnvironment
  case foundLegacyData((Bool) -> Void)
  case migrationFailed
  case ready(AppDependencies)
  case failed
}

public class CinemaKitStartupManager: StartupManager {
  private static let logger = Logging.createLogger(category: "CinemaKitStartupManager")
  private static let deviceSyncZoneCreatedKey = UserDefaultsKey<Bool>("DeviceSyncZoneCreated")
  private static let appVersionKey = UserDefaultsKey<String>("CFBundleShortVersionString")
  private static let shouldResetMovieDetailsKey = UserDefaultsKey<Bool>("ShouldResetMovieDetails")

  // directories
  private static let documentsDir = directoryUrl(for: .documentDirectory)
  private static let appSupportDir = directoryUrl(for: .applicationSupportDirectory)
      .appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)
  private static let libraryRecordStoreURL = appSupportDir.appendingPathComponent("Libraries.plist")
  private static let shareRecordStoreURL = appSupportDir.appendingPathComponent("Shares.plist")
  fileprivate static let movieRecordsDir = appSupportDir.appendingPathComponent("MovieRecords", isDirectory: true)
  fileprivate static let tmdbPropertiesDir = appSupportDir.appendingPathComponent("TmdbProperties", isDirectory: true)
  private static let cachesDir = directoryUrl(for: .cachesDirectory)
  private static let posterCacheDir = cachesDir.appendingPathComponent("PosterCache", isDirectory: true)

  // cinema data file
  private static let legacyLibraryDataFileURL12 = appSupportDir.appendingPathComponent("cinema.data")
  private static let legacyLibraryDataFileURL141 = documentsDir.appendingPathComponent("cinema.data")

  private lazy var previousVersion: AppVersion? = {
    if let versionString = userDefaults.get(for: CinemaKitStartupManager.appVersionKey) {
      return AppVersion(versionString)
    } else if FileManager.default.fileExists(atPath: CinemaKitStartupManager.legacyLibraryDataFileURL141.path) {
      return "1.4.1"
    } else if FileManager.default.fileExists(atPath: CinemaKitStartupManager.legacyLibraryDataFileURL12.path) {
      return "1.2"
    } else {
      return nil
    }
  }()
  private lazy var currentVersion: AppVersion = {
    let key = CinemaKitStartupManager.appVersionKey.rawKey
    // swiftlint:disable:next force_cast
    let versionString = Bundle.main.object(forInfoDictionaryKey: key) as! String
    return AppVersion(versionString)
  }()

  private let application: UIApplication
  private let container = CKContainer.default()
  private let userDefaults = StandardUserDefaults()
  private let migratedLibraryName: String
  private var progressHandler: ((StartupProgress) -> Void)!

  public init(using application: UIApplication, migratedLibraryName: String) {
    self.application = application
    self.migratedLibraryName = migratedLibraryName
  }

  public func initialize(handler: @escaping (StartupProgress) -> Void) {
    self.progressHandler = handler
    os_log("initializing CinemaKit", log: CinemaKitStartupManager.logger, type: .default)
    if let previousVersion = previousVersion {
      os_log("app has been launched before (version %{public}@)",
             log: CinemaKitStartupManager.logger,
             type: .info,
             previousVersion.description)
      if previousVersion < currentVersion {
        migrate(from: previousVersion)
        markCurrentVersion()
      } else if previousVersion > currentVersion {
        fatalError("going back from \(previousVersion) to \(currentVersion) is not supported -> clear app data")
      }
    } else {
      os_log("app has never been launched before", log: CinemaKitStartupManager.logger, type: .info)
      markCurrentVersion()
    }
    if userDefaults.get(for: LocalDataInvalidationFlag.key) {
      os_log("should reset local data", log: CinemaKitStartupManager.logger, type: .default)
      resetLocalData()
    } else if userDefaults.get(for: CinemaKitStartupManager.shouldResetMovieDetailsKey) {
      os_log("should reset movie details", log: CinemaKitStartupManager.logger, type: .default)
      resetMovieDetails()
    }
    setUpDirectories()
    setUpDeviceSyncZone()
  }

  private func markCurrentVersion() {
    userDefaults.set(currentVersion.description, for: CinemaKitStartupManager.appVersionKey)
  }

  private func resetLocalData() {
    userDefaults.removeValue(for: LocalDataInvalidationFlag.key)
    userDefaults.removeValue(for: CinemaKitStartupManager.deviceSyncZoneCreatedKey)
    do {
      let fileManager = FileManager.default
      try fileManager.removeItem(at: FileBasedSubscriptionStore.fileURL)
      try fileManager.removeItem(at: FileBasedServerChangeTokenStore.fileURL)
      try fileManager.removeItem(at: CinemaKitStartupManager.libraryRecordStoreURL)
      try fileManager.removeItem(at: CinemaKitStartupManager.shareRecordStoreURL)
      try fileManager.removeItem(at: CinemaKitStartupManager.movieRecordsDir)
    } catch {
      os_log("unable to remove local data: %{public}@",
             log: CinemaKitStartupManager.logger,
             type: .fault,
             String(describing: error))
      fatalError("unable to remove local data")
    }
    resetMovieDetails()
  }

  private func resetMovieDetails() {
    userDefaults.removeValue(for: CinemaKitStartupManager.shouldResetMovieDetailsKey)
    do {
      let fileManager = FileManager.default
      try fileManager.removeItem(at: CinemaKitStartupManager.tmdbPropertiesDir)
    } catch {
      os_log("unable to remove local data: %{public}@",
             log: CinemaKitStartupManager.logger,
             type: .fault,
             String(describing: error))
      fatalError("unable to remove local data")
    }
  }

  private func setUpDirectories() {
    os_log("setting up directories", log: CinemaKitStartupManager.logger, type: .info)
    makeDirectory(at: CinemaKitStartupManager.documentsDir)
    makeDirectory(at: CinemaKitStartupManager.appSupportDir)
    makeDirectory(at: CinemaKitStartupManager.movieRecordsDir)
    makeDirectory(at: CinemaKitStartupManager.tmdbPropertiesDir)
  }

  private func makeDirectory(at url: URL) {
    if FileManager.default.fileExists(atPath: url.path) { return }
    do {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    } catch {
      os_log("unable to create directory at %{public}@: %{public}@",
             log: CinemaKitStartupManager.logger,
             type: .fault,
             url.path,
             String(describing: error))
    }
  }

  private func setUpDeviceSyncZone() {
    setUpDeviceSyncZone(using: container.database(with: .private), retryCount: defaultRetryCount) { error in
      if let error = error {
        os_log("unable to setup deviceSyncZone: %{public}@",
               log: CinemaKitStartupManager.logger,
               type: .error,
               String(describing: error))
        self.fail()
      } else {
        self.setUpSubscriptions()
      }
    }
  }

  private func setUpDeviceSyncZone(using queue: DatabaseOperationQueue,
                                   retryCount: Int,
                                   then completion: @escaping (CloudKitError?) -> Void) {
    if userDefaults.get(for: CinemaKitStartupManager.deviceSyncZoneCreatedKey) {
      completion(nil)
      return
    }
    progressHandler!(StartupProgress.settingUpCloudEnvironment)
    os_log("creating modify record zones operation to set up zone",
           log: CinemaKitStartupManager.logger,
           type: .default)
    let zone = CKRecordZone(zoneID: deviceSyncZoneID)
    let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)
    operation.modifyRecordZonesCompletionBlock = { _, _, error in
      if let error = error?.singlePartialError(forKey: deviceSyncZoneID) {
        if let retryAfter = error.retryAfterSeconds, retryCount > 1 {
          os_log("retry setup after %.1f seconds", log: CinemaKitStartupManager.logger, type: .default, retryAfter)
          DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(retryAfter)) {
            self.setUpDeviceSyncZone(using: queue,
                                     retryCount: retryCount - 1,
                                     then: completion)
          }
          return
        }
        switch error.ckerrorCode {
          case .notAuthenticated?:
            completion(.notAuthenticated)
          default:
            os_log("<setUpDeviceSyncZone> unhandled error: %{public}@",
                   log: CinemaKitStartupManager.logger,
                   type: .error,
                   String(describing: error))
            completion(.nonRecoverableError)
        }
      } else {
        os_log("device sync zone is set up", log: CinemaKitStartupManager.logger, type: .info)
        self.userDefaults.set(true, for: CinemaKitStartupManager.deviceSyncZoneCreatedKey)
        completion(nil)
      }
    }
    queue.add(operation)
  }

  private func setUpSubscriptions() {
    let subscriptionManager = DefaultSubscriptionManager(
        privateDatabaseOperationQueue: container.database(with: .private),
        sharedDatabaseOperationQueue: container.database(with: .shared),
        dataInvalidationFlag: LocalDataInvalidationFlag(userDefaults: userDefaults))
    subscriptionManager.subscribeForChanges { error in
      if let error = error {
        os_log("unable to subscribe for changes: %{public}@",
               log: CinemaKitStartupManager.logger,
               type: .error,
               String(describing: error))
        self.fail()
      } else {
        DispatchQueue.main.async {
          self.application.registerForRemoteNotifications()
        }
        self.makeDependencies()
      }
    }
  }

  private func makeDependencies() {
    // MovieDb Client
    let language = MovieDbLanguage(rawValue: Locale.current.languageCode ?? "en") ?? .en
    let country = MovieDbCountry(rawValue: Locale.current.regionCode ?? "US") ?? .unitedStates
    let movieDb = TMDBSwiftWrapper(language: language, country: country)

    // Library Manager
    let dataInvalidationFlag = LocalDataInvalidationFlag(userDefaults: userDefaults)
    let syncManager = DefaultSyncManager(privateDatabaseOperationQueue: container.database(with: .private),
                                         sharedDatabaseOperationQueue: container.database(with: .shared),
                                         dataInvalidationFlag: dataInvalidationFlag)
    let fetchManager = DefaultFetchManager(privateDatabaseOperationQueue: container.database(with: .private),
                                           sharedDatabaseOperationQueue: container.database(with: .shared),
                                           dataInvalidationFlag: dataInvalidationFlag)
    let libraryFactory = DefaultMovieLibraryFactory(fetchManager: fetchManager,
                                                    syncManager: syncManager,
                                                    tmdbWrapper: movieDb)
    let modelController = MovieLibraryManagerModelController(
        fetchManager: fetchManager,
        libraryFactory: libraryFactory,
        libraryRecordStore: FileBasedRecordStore(fileURL: CinemaKitStartupManager.libraryRecordStoreURL),
        shareRecordStore: FileBasedRecordStore(fileURL: CinemaKitStartupManager.shareRecordStoreURL))
    let libraryManager = DeviceSyncingLibraryManager(
        containerProvider: DefaultCKContainerProvider(with: container),
        fetchManager: fetchManager,
        syncManager: syncManager,
        changesManager: DefaultChangesManager(privateDatabaseOperationQueue: container.database(with: .private),
                                              sharedDatabaseOperationQueue: container.database(with: .shared),
                                              dataInvalidationFlag: dataInvalidationFlag),
        shareManager: DefaultShareManager(generalOperationQueue: container,
                                          privateDatabaseOperationQueue: container.database(with: .private),
                                          dataInvalidationFlag: dataInvalidationFlag),
        libraryFactory: libraryFactory,
        modelController: modelController,
        dataInvalidationFlag: dataInvalidationFlag)
    let dependencies = AppDependencies(libraryManager: libraryManager,
                                       movieDb: movieDb,
                                       notificationCenter: NotificationCenter.default,
                                       userDefaults: userDefaults)
    checkForMigration(dependencies)
  }

  private func checkForMigration(_ dependencies: AppDependencies) {
    os_log("looking for legacy library file", log: CinemaKitStartupManager.logger, type: .info)
    let legacyURLs = [CinemaKitStartupManager.legacyLibraryDataFileURL141,
                      CinemaKitStartupManager.legacyLibraryDataFileURL12]
    if let dataFileURL = legacyURLs.first(where: { url in FileManager.default.fileExists(atPath: url.path) }) {
      os_log("found legacy library data file", log: CinemaKitStartupManager.logger, type: .info)
      progressHandler(StartupProgress.foundLegacyData { shouldMigrate in
        self.handleMigration(shouldMigrate: shouldMigrate, dataFileURL: dataFileURL, dependencies: dependencies)
      })
    } else {
      os_log("no legacy library data file found", log: CinemaKitStartupManager.logger, type: .info)
      finishStartup(dependencies)
    }
  }

  private func handleMigration(shouldMigrate: Bool, dataFileURL: URL, dependencies: AppDependencies) {
    if shouldMigrate {
      dependencies.internalLibraryManager.migrateLegacyLibrary(with: self.migratedLibraryName,
                                                               at: dataFileURL) { success in
        if success {
          os_log("migration of legacy data succeeded", log: CinemaKitStartupManager.logger, type: .info)
          self.removeLegacyDataFile(at: dataFileURL)
          self.finishStartup(dependencies)
        } else {
          os_log("migration of legacy data failed", log: CinemaKitStartupManager.logger, type: .info)
          self.progressHandler(StartupProgress.migrationFailed)
        }
      }
    } else {
      self.removeLegacyDataFile(at: dataFileURL)
      self.finishStartup(dependencies)
    }
  }

  private func removeLegacyDataFile(at url: URL) {
    os_log("removing legacy data file", log: CinemaKitStartupManager.logger, type: .info)
    do {
      try FileManager.default.removeItem(at: url)
    } catch {
      os_log("unable to remove legacy data file: %{public}@",
             log: CinemaKitStartupManager.logger,
             type: .fault,
             String(describing: error))
    }
  }

  private func finishStartup(_ dependencies: AppDependencies) {
    os_log("finished initializing CinemaKit", log: CinemaKitStartupManager.logger, type: .default)
    self.progressHandler!(StartupProgress.ready(dependencies))
  }

  private func fail() {
    progressHandler!(StartupProgress.failed)
  }
}

private struct DefaultCKContainerProvider: CKContainerProvider {
  let container: CKContainer

  init(with container: CKContainer) {
    self.container = container
  }
}

private class DefaultMovieLibraryFactory: MovieLibraryFactory {
  private let fetchManager: FetchManager
  private let syncManager: SyncManager
  private let tmdbWrapper: TMDBSwiftWrapper

  init(fetchManager: FetchManager,
       syncManager: SyncManager,
       tmdbWrapper: TMDBSwiftWrapper) {
    self.fetchManager = fetchManager
    self.syncManager = syncManager
    self.tmdbWrapper = tmdbWrapper
  }

  func makeLibrary(with metadata: MovieLibraryMetadata) -> InternalMovieLibrary {
    let movieRecordStore = FileBasedRecordStore(
        fileURL: CinemaKitStartupManager.movieRecordsDir.appendingPathComponent("\(metadata.id.recordName).plist"))
    let tmdbPropertiesStore = FileBasedTmdbPropertiesStore(
        fileURL: CinemaKitStartupManager.tmdbPropertiesDir.appendingPathComponent("\(metadata.id.recordName).json"))
    let modelController = MovieLibraryModelController(databaseScope: metadata.databaseScope,
                                                      fetchManager: fetchManager,
                                                      syncManager: syncManager,
                                                      tmdbPropertiesProvider: tmdbWrapper,
                                                      libraryID: metadata.id,
                                                      movieRecordStore: movieRecordStore,
                                                      tmdbPropertiesStore: tmdbPropertiesStore)
    return DeviceSyncingMovieLibrary(metadata: metadata,
                                     modelController: modelController,
                                     tmdbPropertiesProvider: tmdbWrapper,
                                     syncManager: syncManager)
  }
}

// MARK: - migration

extension CinemaKitStartupManager {
  private func migrate(from previousVersion: AppVersion) {
    os_log("migrating from version %{public}@",
           log: CinemaKitStartupManager.logger,
           type: .info,
           previousVersion.description)
    if previousVersion < "2.0" {
      clearPosterCache()
    }
    if previousVersion < "2.0.2" {
      renamePrimaryLibraryKey()
    }
  }

  private func clearPosterCache() {
    do {
      os_log("clearing poster cache", log: CinemaKitStartupManager.logger, type: .default)
      try FileManager.default.removeItem(at: CinemaKitStartupManager.posterCacheDir)
    } catch {
      os_log("unable to clear poster cache: %{public}@",
             log: CinemaKitStartupManager.logger,
             type: .fault,
             String(describing: error))
    }
  }

  private func renamePrimaryLibraryKey() {
    if let primaryLibrary = UserDefaults.standard.string(forKey: "primaryLibrary") {
      os_log("renaming user defaults key", log: CinemaKitStartupManager.logger, type: .default)
      UserDefaults.standard.removeObject(forKey: "primaryLibrary")
      UserDefaults.standard.set(primaryLibrary, forKey: "PrimaryLibrary")
    }
  }
}
