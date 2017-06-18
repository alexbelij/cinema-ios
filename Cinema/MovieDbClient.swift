import UIKit.UIImage

protocol MovieDbClient {

  func tryConnect()

  var storeFront: MovieDbStoreFront { get set }

  var language: MovieDbLanguage? { get set }

  var isConnected: Bool { get }

  func poster(for id: Int, size: PosterSize) -> UIKit.UIImage?

  func overview(for id: Int) -> String?

  func certification(for id: Int) -> String?

  func genres(for id: Int) -> [String]

  func searchMovies(searchText: String) -> [PartialMediaItem]

  func runtime(for id: Int) -> Int?

}

enum MovieDbStoreFront {
  case germany

  var language: String {
    switch self {
      case .germany: return "de"
    }
  }

  var country: String {
    switch self {
      case .germany: return "DE"
    }
  }
}

enum MovieDbLanguage: String {
  case en, de
}

public enum PosterSize: String {
  case w92, w154, w185, w342, w500, w780, original
}
