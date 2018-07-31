import Cache
import UIKit.UIImage

public protocol TMDBSwiftCache {

  func string(for key: String, orSupply supplier: () -> String?) -> String?
  func poster(for key: String, orSupply supplier: () -> UIImage?) -> UIImage?
  func backdrop(for key: String, orSupply supplier: () -> UIImage?) -> UIImage?

}

public class StandardTMDBSwiftCache: TMDBSwiftCache {

  private let movieCache: Storage
  private let posterCache: Storage
  private let backdropCache: Storage

  public init() {
    do {
      movieCache = try Storage(diskConfig: DiskConfig(name: "MovieCache", maxSize: 10_000_000),
                               memoryConfig: MemoryConfig(expiry: .never))
      posterCache = try Storage(diskConfig: DiskConfig(name: "PosterCache", maxSize: 50_000_000),
                                memoryConfig: MemoryConfig(expiry: .never))
      backdropCache = try Storage(diskConfig: DiskConfig(name: "BackdropCache", maxSize: 50_000_000),
                                  memoryConfig: MemoryConfig(expiry: .never))
    } catch {
      fatalError("could not create cache storage")
    }
  }

  public func string(for key: String, orSupply supplier: () -> String?) -> String? {
    return cachingImpl(key: key, cache: movieCache, supplier: supplier)
  }

  public func poster(for key: String, orSupply supplier: () -> UIImage?) -> UIImage? {
    let wrapper: ImageWrapper? = cachingImpl(key: key, cache: posterCache) {
      guard let image = supplier() else { return nil }
      return ImageWrapper(image: image)
    }
    return wrapper?.image
  }

  public func backdrop(for key: String, orSupply supplier: () -> UIImage?) -> UIImage? {
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

public class EmptyTMDBSwiftCache: TMDBSwiftCache {

  public func string(for key: String, orSupply supplier: () -> String?) -> String? {
    return supplier()
  }

  public func poster(for key: String, orSupply supplier: () -> UIImage?) -> UIImage? {
    return supplier()
  }

  public func backdrop(for key: String, orSupply supplier: () -> UIImage?) -> UIImage? {
    return supplier()
  }

}