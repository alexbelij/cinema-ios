import UIKit.UIImage

protocol MovieDbClient {

  func tryConnect()

  var isConnected: Bool { get }

}

public enum PosterSize : String {
  case w92, w154, w185, w342, w500, w780, original
}
