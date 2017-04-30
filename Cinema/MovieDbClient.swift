import UIKit.UIImage

protocol MovieDbClient {

  func tryConnect()

  var isConnected: Bool { get }

  func poster(for id: Int, size: PosterSize) -> UIKit.UIImage?

  func overview(for id: Int) -> String?

  func certification(for id: Int) -> String?

}

public enum PosterSize: String {
  case w92, w154, w185, w342, w500, w780, original
}
