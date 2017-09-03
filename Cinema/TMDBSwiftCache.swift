import Cache
import UIKit.UIImage

protocol TMDBSwiftCache {

  func poster(for key: String, orSupply supplier: () -> UIImage?) -> UIImage?

}

class StandardTMDBSwiftCache: TMDBSwiftCache {

  private let posterCache: SpecializedCache<UIImage>

  init() {
    posterCache = SpecializedCache(name: "PosterCache",
                                   config: Cache.Config(expiry: .never,
                                                        maxDiskSize: 50_000_000))
  }

  func poster(for key: String, orSupply supplier: () -> UIImage?) -> UIImage? {
    return cachingImpl(key: key, cache: posterCache, supplier: supplier)
  }

  private func cachingImpl<Element>(key: String, cache: SpecializedCache<Element>, supplier: () -> Element?) -> Element?
      where Element: Cachable {
    if let cachedElement = cache.object(forKey: key) {
      return cachedElement
    }
    if let createdElement = supplier() {
      try? cache.addObject(createdElement, forKey: key)
      return createdElement
    }
    return nil
  }

}

class EmptyTMDBSwiftCache: TMDBSwiftCache {

  func poster(for key: String, orSupply supplier: () -> UIImage?) -> UIImage? {
    return supplier()
  }

}
