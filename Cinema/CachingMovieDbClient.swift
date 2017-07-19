import Foundation
import UIKit
import Cache

class CachingMovieDbClient: MovieDbClient {

  private var backingClient: MovieDbClient
  private let posterCache: SpecializedCache<UIImage>

  init(backingClient: MovieDbClient) {
    self.backingClient = backingClient
    posterCache = SpecializedCache<UIImage>(name: "PosterCache",
                                            config: Cache.Config(expiry: .never,
                                                                 maxDiskSize: 30 * 1000 * 1000)) // about 1000 movies
  }

  func tryConnect() {
    backingClient.tryConnect()
  }

  var storeFront: MovieDbStoreFront {
    get {
      return backingClient.storeFront
    }
    set {
      backingClient.storeFront = newValue
    }
  }

  var language: MovieDbLanguage? {
    get {
      return backingClient.language
    }
    set {
      backingClient.language = newValue
    }
  }

  var isConnected: Bool {
    return backingClient.isConnected
  }

  func poster(for id: Int, size: PosterSize) -> UIImage? {
    switch size {
      case .w92:
        let key = String(id)
        if let poster = posterCache.object(forKey: key) {
          return poster
        }
        if let poster = backingClient.poster(for: id, size: size) {
          try? posterCache.addObject(poster, forKey: key)
          return poster
        }
        return nil
      default: return backingClient.poster(for: id, size: size)
    }
  }

  func overview(for id: Int) -> String? {
    return backingClient.overview(for: id)
  }

  func certification(for id: Int) -> String? {
    return backingClient.certification(for: id)
  }

  func genres(for id: Int) -> [String] {
    return backingClient.genres(for: id)
  }

  func searchMovies(searchText: String) -> [PartialMediaItem] {
    return backingClient.searchMovies(searchText: searchText)
  }

  func runtime(for id: Int) -> Int? {
    return backingClient.runtime(for: id)
  }
}
