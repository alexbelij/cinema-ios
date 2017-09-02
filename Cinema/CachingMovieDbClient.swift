import Cache
import Foundation
import UIKit

class CachingMovieDbClient: MovieDbClient {

  private var backingClient: MovieDbClient
  private let posterCache: SpecializedCache<UIImage>

  init(backingClient: MovieDbClient) {
    self.backingClient = backingClient
    posterCache = SpecializedCache<UIImage>(name: "PosterCache",
                                            config: Cache.Config(expiry: .never,
                                                                 maxDiskSize: 50_000_000))
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
    let key = "\(id)-\(size)"
    if let poster = posterCache.object(forKey: key) {
      return poster
    }
    if let poster = backingClient.poster(for: id, size: size) {
      try? posterCache.addObject(poster, forKey: key)
      return poster
    }
    return nil
  }

  func overview(for id: Int) -> String? {
    return backingClient.overview(for: id)
  }

  func certification(for id: Int) -> String? {
    return backingClient.certification(for: id)
  }

  func genreIds(for id: Int) -> [Int] {
    return backingClient.genreIds(for: id)
  }

  func searchMovies(searchText: String) -> [PartialMediaItem] {
    return backingClient.searchMovies(searchText: searchText)
  }

  func runtime(for id: Int) -> Int? {
    return backingClient.runtime(for: id)
  }

  func popularMovies() -> PagingSequence<PartialMediaItem> {
    return backingClient.popularMovies()
  }
}
