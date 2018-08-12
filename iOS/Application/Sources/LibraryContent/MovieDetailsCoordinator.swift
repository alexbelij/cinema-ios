import CinemaKit
import Dispatch
import Foundation
import UIKit

protocol MovieDetailsCoordinatorDelegate: class {
  func movieDetailsCoordinatorDidDismiss(_ coordinator: MovieDetailsCoordinator)
}

class MovieDetailsCoordinator: CustomPresentableCoordinator {
  // coordinator stuff
  var rootViewController: UIViewController {
    return movieDetailsController
  }
  weak var delegate: MovieDetailsCoordinatorDelegate?

  // other properties
  private var movieDb: MovieDbClient
  private(set) var movie: Movie

  // managed controller
  private var movieDetailsController = UIStoryboard.movieList.instantiate(MovieDetailsController.self)

  init(for movie: Movie, using movieDb: MovieDbClient) {
    self.movieDb = movieDb
    self.movie = movie
    movieDetailsController.delegate = self
    configure(for: self.movie, resetRemoteProperties: true)
    fetchRemoteData(for: self.movie.tmdbID)
  }
}

// MARK: - Remote Data Fetching

extension MovieDetailsCoordinator {
  private func fetchRemoteData(for id: TmdbIdentifier) {
    DispatchQueue.main.async {
      UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }
    let queue = DispatchQueue.global(qos: .userInitiated)
    let group = DispatchGroup()
    self.fetchRemoteValue(for: \MovieDetailsController.poster, on: queue, in: group) {
      self.movieDb.poster(for: id,
                          size: PosterSize(minWidth: Int(0.345 * UIScreen.main.bounds.size.width)),
                          purpose: .details)
    }
    self.fetchRemoteValue(for: \MovieDetailsController.certification, on: queue, in: group) {
      self.movieDb.certification(for: id)?.nilIfEmptyString
    }
    self.fetchRemoteValue(for: \MovieDetailsController.overview, on: queue, in: group) {
      self.movieDb.overview(for: id)?.nilIfEmptyString
    }
    group.notify(queue: .main) {
      UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
  }

  private func fetchRemoteValue<T>(
      for keyPath: WritableKeyPath<MovieDetailsController, MovieDetailsController.RemoteProperty<T>>,
      on queue: DispatchQueue,
      in group: DispatchGroup,
      fetchBlock: @escaping () -> T?) {
    group.enter()
    queue.async {
      if let value = fetchBlock() {
        DispatchQueue.main.async {
          self.movieDetailsController[keyPath: keyPath] = .available(value)
          group.leave()
        }
      } else {
        DispatchQueue.main.async {
          self.movieDetailsController[keyPath: keyPath] = .unavailable
        }
        group.leave()
      }
    }
  }
}

// MARK: - Configuration

extension MovieDetailsCoordinator {
  func updateNonRemoteProperties(with movie: Movie) {
    self.movie = movie
    configure(for: self.movie, resetRemoteProperties: false)
  }

  private func configure(for movie: Movie, resetRemoteProperties: Bool) {
    movieDetailsController.movieTitle = movie.fullTitle
    movieDetailsController.genreIds = movie.genreIds
    movieDetailsController.runtime = movie.runtime
    movieDetailsController.releaseDate = movie.releaseDate
    movieDetailsController.diskType = movie.diskType
    if resetRemoteProperties {
      movieDetailsController.poster = .loading
      movieDetailsController.certification = .loading
      movieDetailsController.overview = .loading
    }
  }
}

// MARK: - MovieDetailsControllerDelegate

extension MovieDetailsCoordinator: MovieDetailsControllerDelegate {
  func movieDetailsControllerDidDismiss(_ controller: MovieDetailsController) {
    self.delegate?.movieDetailsCoordinatorDidDismiss(self)
  }
}
