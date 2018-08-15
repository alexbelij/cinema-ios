import CloudKit
import Foundation
import os.log
import UIKit

struct LocalCloudKitCacheInvalidationFlag {
  fileprivate static let key = "LocalCloudKitCacheIsInvalid"
  private let userDefaults: UserDefaultsProtocol

  init(userDefaults: UserDefaultsProtocol = UserDefaults.standard) {
    self.userDefaults = userDefaults
  }

  var isSet: Bool {
    return userDefaults.bool(forKey: LocalCloudKitCacheInvalidationFlag.key)
  }

  func set() {
    userDefaults.set(true, forKey: LocalCloudKitCacheInvalidationFlag.key)
  }
}

public protocol StartupManager {
  func initialize(then completion: @escaping (AppDependencies) -> Void)
}

public class CinemaKitStartupManager: StartupManager {
  private static let logger = Logging.createLogger(category: "CinemaKitStartupManager")
  private static let deviceSyncZoneCreatedKey = "DeviceSyncZoneCreated"
  private static let appVersionKey = "CFBundleShortVersionString"

  // directories
  private static let documentsDir = directoryUrl(for: .documentDirectory)
  private static let appSupportDir = directoryUrl(for: .applicationSupportDirectory)
      .appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)
  private static let libraryRecordStoreURL = appSupportDir.appendingPathComponent("Libraries.plist")
  private static let shareRecordStoreURL = appSupportDir.appendingPathComponent("Shares.plist")
  fileprivate static let movieRecordsDir = appSupportDir.appendingPathComponent("MovieRecords", isDirectory: true)

  // cinema data file
  private static let libraryDataFileURL = documentsDir.appendingPathComponent("cinema.data")
  private static let legacyLibraryDataFileURL = appSupportDir.appendingPathComponent("cinema.data")

  private lazy var previousVersion: AppVersion? = {
    if let versionString = UserDefaults.standard.string(forKey: CinemaKitStartupManager.appVersionKey) {
      return AppVersion(versionString)
    } else if FileManager.default.fileExists(atPath: CinemaKitStartupManager.libraryDataFileURL.path) {
      return "1.4.1"
    } else if FileManager.default.fileExists(atPath: CinemaKitStartupManager.legacyLibraryDataFileURL.path) {
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

  public init(using application: UIApplication) {
    self.application = application
  }

  public func initialize(then completion: @escaping (AppDependencies) -> Void) {
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
        markCurrentVersion()
      } else if previousVersion > currentVersion {
        fatalError("unsupported -> clean app data")
      }
    } else {
      os_log("app has never been launched before", log: CinemaKitStartupManager.logger, type: .info)
      markCurrentVersion()
    }
    if UserDefaults.standard.bool(forKey: LocalCloudKitCacheInvalidationFlag.key) {
      os_log("local CloudKit cache was invalidated", log: CinemaKitStartupManager.logger, type: .default)
      resetLocalCloudKitCache()
    }
    setUpDirectories()
    setUpDeviceSyncZone(then: completion)
  }

  private func markCurrentVersion() {
    UserDefaults.standard.set(currentVersion.description, forKey: CinemaKitStartupManager.appVersionKey)
  }

  private func resetLocalCloudKitCache() {
    UserDefaults.standard.removeObject(forKey: LocalCloudKitCacheInvalidationFlag.key)
    UserDefaults.standard.removeObject(forKey: CinemaKitStartupManager.deviceSyncZoneCreatedKey)
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
  }

  private func setUpDirectories() {
    os_log("setting up directories", log: CinemaKitStartupManager.logger, type: .info)
    makeDirectory(at: CinemaKitStartupManager.documentsDir)
    makeDirectory(at: CinemaKitStartupManager.appSupportDir)
    makeDirectory(at: CinemaKitStartupManager.movieRecordsDir)
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

  private func setUpDeviceSyncZone(then completion: @escaping (AppDependencies) -> Void) {
    setUpDeviceSyncZone(using: container.queue(withScope: .private), retryCount: defaultRetryCount) { error in
      if let error = error {
        os_log("unable to setup deviceSyncZone: %{public}@",
               log: CinemaKitStartupManager.logger,
               type: .error,
               String(describing: error))
        fail()
      } else {
        self.setUpSubscriptions(then: completion)
      }
    }
  }

  private func setUpDeviceSyncZone(using queue: DatabaseOperationQueue,
                                   retryCount: Int,
                                   then completion: @escaping (CloudKitError?) -> Void) {
    if UserDefaults.standard.bool(forKey: CinemaKitStartupManager.deviceSyncZoneCreatedKey) {
      completion(nil)
      return
    }
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
        UserDefaults.standard.set(true, forKey: CinemaKitStartupManager.deviceSyncZoneCreatedKey)
        completion(nil)
      }
    }
    queue.add(operation)
  }

  private func setUpSubscriptions(then completion: @escaping (AppDependencies) -> Void) {
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
        let dependencies = self.makeDependencies(with: subscriptionManager)
        os_log("finished initializing CinemaKit", log: CinemaKitStartupManager.logger, type: .default)
        completion(dependencies)
      }
    }
  }

  private func makeDependencies(with subscriptionManager: DefaultSubscriptionManager) -> AppDependencies {
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
        subscriptionManager: subscriptionManager,
        changesManager: DefaultChangesManager(queueFactory: container),
        shareManager: DefaultShareManager(generalOperationQueue: container, queueFactory: container),
        libraryFactory: libraryFactory,
        data: data)
    return AppDependencies(libraryManager: libraryManager,
                           movieDb: movieDb,
                           notificationCenter: NotificationCenter.default)
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
    let data = MovieLibraryData(databaseOperationQueue: databaseOperationQueue,
                                fetchManager: fetchManager,
                                syncManager: syncManager,
                                tmdbPropertiesProvider: tmdbWrapper,
                                libraryID: metadata.id,
                                movieRecordStore: movieRecordStore)
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
