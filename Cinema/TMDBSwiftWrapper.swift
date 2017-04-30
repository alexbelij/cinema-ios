import UIKit.UIImage
import Dispatch
import TMDBSwift

class TMDBSwiftWrapper: MovieDbClient {

  private static let apiKey = "ace1ea1cb456b8d6fe092a0ec923e30c"

  private static let baseUrl = "https://image.tmdb.org/t/p/";

  private static let language = "de"

  func tryConnect() {
    isConnected = true
  }

  private(set) var isConnected: Bool = false
}
