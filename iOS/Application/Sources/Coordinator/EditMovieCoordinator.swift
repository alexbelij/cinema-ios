import CinemaKit
import Dispatch
import UIKit

protocol EditMovieCoordinatorDelegate: class {
  func editMovieCoordinator(_ coordinator: EditMovieCoordinator,
                            didFinishEditingWithResult editResult: EditMovieCoordinator.EditResult)
  func editMovieCoordinator(_ coordinator: EditMovieCoordinator, didFailWithError error: Error)
}

class EditMovieCoordinator: CustomPresentableCoordinator {
  // coordinator stuff
  var rootViewController: UIViewController {
    return navigationController
  }
  weak var delegate: EditMovieCoordinatorDelegate?

  // other properties
  private let library: MovieLibrary
  private var movieToEdit: Movie

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
    self.movieToEdit = movie
    navigationController = UINavigationController(rootViewController: editMovieController)
    editMovieController.delegate = self
    editMovieController.movieTitle = movieToEdit.title
    editMovieController.subtitle = movieToEdit.subtitle
  }
}

extension EditMovieCoordinator: EditMovieControllerDelegate {
  func editMovieController(_ controller: EditMovieController,
                           shouldAcceptEdits edits: Set<EditMovieController.Edit>) -> EditMovieController.EditApproval {
    for edit in edits {
      switch edit {
        case let .titleChange(newTitle):
          if newTitle.isEmpty {
            return .rejected(reason: NSLocalizedString("edit.noTitleAlert", comment: ""))
          }
        case .subtitleChange:
          break
      }
    }
    return .accepted
  }

  func editMovieControllerDidCancelEditing(_ controller: EditMovieController) {
    self.delegate?.editMovieCoordinator(self, didFinishEditingWithResult: .canceled)
  }

  func editMovieController(_ controller: EditMovieController,
                           didFinishEditingWithResult editResult: EditMovieController.EditResult) {
    controller.navigationItem.leftBarButtonItem!.isEnabled = false
    controller.view.isUserInteractionEnabled = false
    let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
    activityIndicator.startAnimating()
    controller.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: activityIndicator)
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        switch editResult {
          case let .edited(edits):
            var movie = self.movieToEdit
            self.applyEdits(edits, to: &movie)
            try self.library.update(movie)
            DispatchQueue.main.async {
              self.delegate?.editMovieCoordinator(self, didFinishEditingWithResult: .edited(movie))
            }
          case .deleted:
            try self.library.remove(self.movieToEdit)
            DispatchQueue.main.async {
              self.delegate?.editMovieCoordinator(self, didFinishEditingWithResult: .deleted)
            }
        }
      } catch {
        DispatchQueue.main.async {
          self.delegate?.editMovieCoordinator(self, didFailWithError: error)
        }
      }
    }
  }

  private func applyEdits(_ edits: Set<EditMovieController.Edit>, to movie: inout Movie) {
    for edit in edits {
      switch edit {
        case let .titleChange(newTitle): movie.title = newTitle
        case let .subtitleChange(newSubtitle): movie.subtitle = newSubtitle
      }
    }
  }
}
