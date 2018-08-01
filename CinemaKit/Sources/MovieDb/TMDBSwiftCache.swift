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
  private let movieCache: Storage
  private let posterCache: Storage
  private let largePosterCache: Storage
  private let backdropCache: Storage

  init?() {
    do {
      movieCache = try Storage(diskConfig: DiskConfig(name: "MovieCache", maxSize: 10_000_000),
                               memoryConfig: MemoryConfig(expiry: .never))
      posterCache = try Storage(diskConfig: DiskConfig(name: "PosterCache", maxSize: 50_000_000),
                                memoryConfig: MemoryConfig(expiry: .never))
      largePosterCache = try Storage(diskConfig: DiskConfig(name: "LargePosterCache", maxSize: 10_000_000),
                                     memoryConfig: MemoryConfig(expiry: .never))
      backdropCache = try Storage(diskConfig: DiskConfig(name: "BackdropCache", maxSize: 50_000_000),
                                  memoryConfig: MemoryConfig(expiry: .never))
    } catch {
      os_log("unable to create cache: %{public}@",
             log: StandardTMDBSwiftCache.logger,
             type: .fault,
             String(describing: error))
      return nil
    }
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(clearExpiredData),
                                           name: .UIApplicationDidReceiveMemoryWarning,
                                           object: nil)
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(clearExpiredData),
                                           name: .UIApplicationWillTerminate,
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
      os_log("unable to clear expired data: %{public}@",
             log: StandardTMDBSwiftCache.logger,
             type: .fault,
             String(describing: error))
    }
  }

  func string(for key: String, orSupply supplier: () -> String?) -> String? {
    return cachingImpl(key: key, cache: movieCache, supplier: supplier)
  }

  func poster(for key: String, orSupply supplier: () -> UIImage?) -> UIImage? {
    let wrapper: ImageWrapper? = cachingImpl(key: key, cache: posterCache) {
      guard let image = supplier() else { return nil }
      return ImageWrapper(image: image)
    }
    return wrapper?.image
  }

  func largePoster(for key: String, orSupply supplier: () -> UIImage?) -> UIImage? {
    let wrapper: ImageWrapper? = cachingImpl(key: key, cache: largePosterCache) {
      guard let image = supplier() else { return nil }
      return ImageWrapper(image: image)
    }
    return wrapper?.image
  }

  func backdrop(for key: String, orSupply supplier: () -> UIImage?) -> UIImage? {
    let wrapper: ImageWrapper? = cachingImpl(key: key, cache: backdropCache) {
      guard let image = supplier() else { return nil }
      return ImageWrapper(image: image)
    }
    return wrapper?.image
  }

  private func cachingImpl<Element: Codable>(key: String, cache: Storage, supplier: () -> Element?) -> Element? {
    if let cachedElement = try? cache.object(ofType: Element.self, forKey: key) {
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
