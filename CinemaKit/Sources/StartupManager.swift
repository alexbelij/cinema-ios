import CloudKit
import Foundation
import os.log
import UIKit

struct LocalDataInvalidationFlag {
  fileprivate static let key = "ShouldResetLocalData"
  private let userDefaults: UserDefaultsProtocol

  init(userDefaults: UserDefaultsProtocol = UserDefaults.standard) {
    self.userDefaults = userDefaults
  }

  var isSet: Bool {
    return userDefaults.bool(forKey: LocalDataInvalidationFlag.key)
  }

  func set() {
    userDefaults.set(true, forKey: LocalDataInvalidationFlag.key)
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
}

public class CinemaKitStartupManager: StartupManager {
  private static let logger = Logging.createLogger(category: "CinemaKitStartupManager")
  private static let deviceSyncZoneCreatedKey = "DeviceSyncZoneCreated"
  private static let appVersionKey = "CFBundleShortVersionString"
  private static let shouldResetMovieDetailsKey = "ShouldResetMovieDetails"

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
    if let versionString = userDefaults.string(forKey: CinemaKitStartupManager.appVersionKey) {
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
    // swiftlint:disable:next force_cast
    let versionString = Bundle.main.object(forInfoDictionaryKey: CinemaKitStartupManager.appVersionKey) as! String
    return AppVersion(versionString)
  }()

  private let application: UIApplication
  private let container = CKContainer.default()
  private let userDefaults: UserDefaultsProtocol = UserDefaults.standard
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
        os_log("migrating from version %{public}@",
               log: CinemaKitStartupManager.logger,
               type: .info,
               previousVersion.description)
        clearPosterCache()
        markCurrentVersion()
      } else if previousVersion > currentVersion {
        fatalError("unsupported -> clean app data")
      }
    } else {
      os_log("app has never been launched before", log: CinemaKitStartupManager.logger, type: .info)
      markCurrentVersion()
    }
    if userDefaults.bool(forKey: LocalDataInvalidationFlag.key) {
      os_log("should reset local data", log: CinemaKitStartupManager.logger, type: .default)
      resetLocalData()
    } else if userDefaults.bool(forKey: CinemaKitStartupManager.shouldResetMovieDetailsKey) {
      os_log("should reset movie details", log: CinemaKitStartupManager.logger, type: .default)
      resetMovieDetails()
    }
    setUpDirectories()
    setUpDeviceSyncZone()
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

  private func markCurrentVersion() {
    userDefaults.set(currentVersion.description, forKey: CinemaKitStartupManager.appVersionKey)
  }

  private func resetLocalData() {
    userDefaults.removeObject(forKey: LocalDataInvalidationFlag.key)
    userDefaults.removeObject(forKey: CinemaKitStartupManager.deviceSyncZoneCreatedKey)
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
    userDefaults.removeObject(forKey: CinemaKitStartupManager.shouldResetMovieDetailsKey)
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
    setUpDeviceSyncZone(using: container.queue(withScope: .private), retryCount: defaultRetryCount) { error in
      if let error = error {
        os_log("unable to setup deviceSyncZone: %{public}@",
               log: CinemaKitStartupManager.logger,
               type: .error,
               String(describing: error))
        fail()
      } else {
        self.setUpSubscriptions()
      }
    }
  }

  private func setUpDeviceSyncZone(using queue: DatabaseOperationQueue,
                                   retryCount: Int,
                                   then completion: @escaping (CloudKitError?) -> Void) {
    if userDefaults.bool(forKey: CinemaKitStartupManager.deviceSyncZoneCreatedKey) {
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
        guard let ckerror = error as? CKError else {
          os_log("<setUpDeviceSyncZone> unhandled error: %{public}@",
                 log: CinemaKitStartupManager.logger,
                 type: .error,
                 String(describing: error))
          completion(.nonRecoverableError)
          return
        }
        if retryCount > 1, let retryAfter = ckerror.retryAfterSeconds?.rounded(.up) {
          os_log("retry setup after %.1f seconds", log: CinemaKitStartupManager.logger, type: .default, retryAfter)
          DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(Int(retryAfter))) {
            self.setUpDeviceSyncZone(using: queue,
                                     retryCount: retryCount - 1,
                                     then: completion)
          }
        } else if ckerror.code == CKError.Code.notAuthenticated {
          completion(.notAuthenticated)
        } else if ckerror.code == CKError.Code.networkFailure
                  || ckerror.code == CKError.Code.networkUnavailable
                  || ckerror.code == CKError.Code.requestRateLimited
                  || ckerror.code == CKError.Code.serviceUnavailable
                  || ckerror.code == CKError.Code.zoneBusy {
          completion(.nonRecoverableError)
        } else {
          os_log("<setUpDeviceSyncZone> unhandled CKError: %{public}@",
                 log: CinemaKitStartupManager.logger,
                 type: .error,
                 String(describing: ckerror))
          completion(.nonRecoverableError)
        }
      } else {
        os_log("device sync zone is set up", log: CinemaKitStartupManager.logger, type: .info)
        self.userDefaults.set(true, forKey: CinemaKitStartupManager.deviceSyncZoneCreatedKey)
        completion(nil)
      }
    }
    queue.add(operation)
  }

  private func setUpSubscriptions() {
    let subscriptionManager = DefaultSubscriptionManager(queueFactory: container)
    subscriptionManager.subscribeForChanges { error in
      if let error = error {
        os_log("unable to subscribe for changes: %{public}@",
               log: CinemaKitStartupManager.logger,
               type: .error,
               String(describing: error))
        fail()
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
    let syncManager = DefaultSyncManager()
    let fetchManager = DefaultFetchManager()
    let libraryFactory = DefaultMovieLibraryFactory(queueFactory: container,
                                                    fetchManager: fetchManager,
                                                    syncManager: syncManager,
                                                    tmdbWrapper: movieDb)
    let data = MovieLibraryManagerData(
        queueFactory: container,
        fetchManager: fetchManager,
        libraryFactory: libraryFactory,
        libraryRecordStore: FileBasedRecordStore(fileURL: CinemaKitStartupManager.libraryRecordStoreURL),
        shareRecordStore: FileBasedRecordStore(fileURL: CinemaKitStartupManager.shareRecordStoreURL))
    let libraryManager = DeviceSyncingLibraryManager(
        container: container,
        queueFactory: container,
        fetchManager: fetchManager,
        syncManager: syncManager,
        changesManager: DefaultChangesManager(queueFactory: container),
        shareManager: DefaultShareManager(generalOperationQueue: container, queueFactory: container),
        libraryFactory: libraryFactory,
        data: data)
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
}

private class DefaultMovieLibraryFactory: MovieLibraryFactory {
  private let queueFactory: DatabaseOperationQueueFactory
  private let fetchManager: FetchManager
  private let syncManager: SyncManager
  private let tmdbWrapper: TMDBSwiftWrapper

  init(queueFactory: DatabaseOperationQueueFactory,
       fetchManager: FetchManager,
       syncManager: SyncManager,
       tmdbWrapper: TMDBSwiftWrapper) {
    self.queueFactory = queueFactory
    self.fetchManager = fetchManager
    self.syncManager = syncManager
    self.tmdbWrapper = tmdbWrapper
  }

  func makeLibrary(with metadata: MovieLibraryMetadata) -> InternalMovieLibrary {
    let scope = metadata.isCurrentUserOwner ? CKDatabaseScope.private : CKDatabaseScope.shared
    let databaseOperationQueue = queueFactory.queue(withScope: scope)
    let movieRecordStore = FileBasedRecordStore(
        fileURL: CinemaKitStartupManager.movieRecordsDir.appendingPathComponent("\(metadata.id.recordName).plist"))
    let tmdbPropertiesStore = FileBasedTmdbPropertiesStore(
        fileURL: CinemaKitStartupManager.tmdbPropertiesDir.appendingPathComponent("\(metadata.id.recordName).json"))
    let data = MovieLibraryData(databaseOperationQueue: databaseOperationQueue,
                                fetchManager: fetchManager,
                                syncManager: syncManager,
                                tmdbPropertiesProvider: tmdbWrapper,
                                libraryID: metadata.id,
                                movieRecordStore: movieRecordStore,
                                tmdbPropertiesStore: tmdbPropertiesStore)
    return DeviceSyncingMovieLibrary(databaseOperationQueue: databaseOperationQueue,
                                     syncManager: syncManager,
                                     tmdbPropertiesProvider: tmdbWrapper,
                                     metadata: metadata,
                                     data: data)
  }
}

private func fail() -> Never {
  fatalError("error during startup")
}
