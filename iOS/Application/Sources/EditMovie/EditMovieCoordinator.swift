import CinemaKit
import Dispatch
import UIKit

protocol EditMovieCoordinatorDelegate: class {
  func editMovieCoordinator(_ coordinator: EditMovieCoordinator,
                            didFinishEditingWith editResult: EditMovieCoordinator.EditResult)
  func editMovieCoordinator(_ coordinator: EditMovieCoordinator, didFailWith error: MovieLibraryError)
}

class EditMovieCoordinator: CustomPresentableCoordinator {
  // coordinator stuff
  var rootViewController: UIViewController {
    return navigationController
  }
  weak var delegate: EditMovieCoordinatorDelegate?

  // other properties
  private let library: MovieLibrary
  var movie: Movie {
    didSet {
      DispatchQueue.main.async {
        self.editMovieController.movie = self.movie
      }
    }
  }

  // managed controller
  private let navigationController: UINavigationController
  private let editMovieController = UIStoryboard.editMovie.instantiate(EditMovieController.self)

  enum EditResult {
    case canceled
    case edited(Movie)
    case deleted
  }

  init(for movie: Movie, in library: MovieLibrary) {
    self.library = library
    self.movie = movie
    navigationController = UINavigationController(rootViewController: editMovieController)
    editMovieController.delegate = self
    editMovieController.movie = movie
  }
}

extension EditMovieCoordinator: EditMovieControllerDelegate {
  func editMovieControllerDidCancelEditing(_ controller: EditMovieController) {
    self.delegate?.editMovieCoordinator(self, didFinishEditingWith: .canceled)
  }

  func editMovieController(_ controller: EditMovieController,
                           didFinishEditingWith editResult: EditMovieController.EditResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      switch editResult {
        case let .edited(movie):
          self.library.update(movie) { result in self.handleResult(result, for: .edited(movie)) }
        case .deleted:
          self.library.removeMovie(with: controller.movie.tmdbID) { result in
            self.handleResult(result, for: .deleted)
          }
      }
    }
  }

  private func handleResult<R>(_ result: Result<R, MovieLibraryError>, for editResult: EditResult) {
    DispatchQueue.main.async {
      self.editMovieController.stopWaitingAnimation(restoreUI: result.isFailure)
      switch result {
        case let .failure(error):
          self.delegate?.editMovieCoordinator(self, didFailWith: error)
        case .success:
          self.delegate?.editMovieCoordinator(self, didFinishEditingWith: editResult)
      }
    }
  }
}
