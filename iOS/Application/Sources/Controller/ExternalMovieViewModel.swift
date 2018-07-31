import CinemaKit
import UIKit

final class ExternalMovieViewModel {
  enum ImageState {
    case unknown
    case loading
    case available(UIImage)
    case unavailable
  }

  enum LibraryState {
    case new
    case updateInProgress
    case addedToLibrary
  }

  let movie: PartialMediaItem
  var poster: ImageState
  var state: LibraryState

  init(_ movie: PartialMediaItem, state: LibraryState) {
    self.movie = movie
    self.state = state
    self.poster = .unknown
  }
}
