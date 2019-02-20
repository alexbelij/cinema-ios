import Cache
import os.log
import UIKit.UIImage

protocol TMDBSwiftCache {
  func string(for key: String, orSupply supplier: () -> String?) -> String?
  func poster(for key: String, orSupply supplier: () -> UIImage?) -> UIImage?
  func largePoster(for key: String, orSupply supplier: () -> UIImage?) -> UIImage?
  func backdrop(for key: String, orSupply supplier: () -> UIImage?) -> UIImage?
}

class StandardTMDBSwiftCache: TMDBSwiftCache {
  private static let logger = Logging.createLogger(category: "TMDB-Cache")
  private let movieCache: Storage<String>
  private let posterCache: Storage<UIImage>
  private let largePosterCache: Storage<UIImage>
  private let backdropCache: Storage<UIImage>
  private let errorReporter: ErrorReporter

  init?(errorReporter: ErrorReporter = CrashlyticsErrorReporter.shared) {
    self.errorReporter = errorReporter
    do {
      movieCache = try Storage(diskConfig: DiskConfig(name: "MovieCache", maxSize: 10_000_000),
                               memoryConfig: MemoryConfig(expiry: .never),
                               transformer: TransformerFactory.forCodable(ofType: String.self))
      posterCache = try Storage(diskConfig: DiskConfig(name: "PosterCache", maxSize: 50_000_000),
                                memoryConfig: MemoryConfig(expiry: .never),
                                transformer: TransformerFactory.forImage())
      largePosterCache = try Storage(diskConfig: DiskConfig(name: "LargePosterCache", maxSize: 10_000_000),
                                     memoryConfig: MemoryConfig(expiry: .never),
                                     transformer: TransformerFactory.forImage())
      backdropCache = try Storage(diskConfig: DiskConfig(name: "BackdropCache", maxSize: 50_000_000),
                                  memoryConfig: MemoryConfig(expiry: .never),
                                  transformer: TransformerFactory.forImage())
    } catch {
      errorReporter.report(error)
      return nil
    }
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(clearExpiredData),
                                           name: UIApplication.didReceiveMemoryWarningNotification,
                                           object: nil)
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(clearExpiredData),
                                           name: UIApplication.willTerminateNotification,
                                           object: nil)
  }

  @objc
  private func clearExpiredData() {
    do {
      os_log("clearing expired data", log: StandardTMDBSwiftCache.logger, type: .info)
      try movieCache.removeExpiredObjects()
      try posterCache.removeExpiredObjects()
      try largePosterCache.removeExpiredObjects()
      try backdropCache.removeExpiredObjects()
    } catch {
      errorReporter.report(error)
    }
  }

  func string(for key: String, orSupply supplier: () -> String?) -> String? {
    return cachingImpl(key: key, cache: movieCache, supplier: supplier)
  }

  func poster(for key: String, orSupply supplier: () -> UIImage?) -> UIImage? {
    return cachingImpl(key: key, cache: posterCache, supplier: supplier)
  }

  func largePoster(for key: String, orSupply supplier: () -> UIImage?) -> UIImage? {
    return cachingImpl(key: key, cache: largePosterCache, supplier: supplier)
  }

  func backdrop(for key: String, orSupply supplier: () -> UIImage?) -> UIImage? {
    return cachingImpl(key: key, cache: backdropCache, supplier: supplier)
  }

  private func cachingImpl<Element>(key: String, cache: Storage<Element>, supplier: () -> Element?) -> Element? {
    if let cachedElement = try? cache.object(forKey: key) {
      return cachedElement
    }
    if let createdElement = supplier() {
      try? cache.setObject(createdElement, forKey: key)
      return createdElement
    }
    return nil
  }
}

class DummyTMDBSwiftCache: TMDBSwiftCache {
  func string(for key: String, orSupply supplier: () -> String?) -> String? {
    return supplier()
  }

  func poster(for key: String, orSupply supplier: () -> UIImage?) -> UIImage? {
    return supplier()
  }

  func largePoster(for key: String, orSupply supplier: () -> UIImage?) -> UIImage? {
    return supplier()
  }

  func backdrop(for key: String, orSupply supplier: () -> UIImage?) -> UIImage? {
    return supplier()
  }
}
