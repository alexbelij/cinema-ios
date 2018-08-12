import CinemaKit
import Dispatch
import Foundation
import UIKit

protocol LibraryContentCoordinatorDelegate: class {
  func libraryContentCoordinatorShowLibraryList(_ coordinator: LibraryContentCoordinator)
  func libraryContentCoordinatorDidDismiss(_ coordinator: LibraryContentCoordinator)
}

class LibraryContentCoordinator: AutoPresentableCoordinator {
  enum ContentSpecification {
    case all
    case allWith(GenreIdentifier)
  }

  // coordinator stuff
  weak var delegate: LibraryContentCoordinatorDelegate?

  // other properties
  private let dependencies: AppDependencies
  private let library: MovieLibrary
  private let content: ContentSpecification
  var dismissWhenEmpty = false
  var showsLibrarySwitch = false {
    didSet {
      if showsLibrarySwitch {
        let button = UIBarButtonItem(image: #imageLiteral(resourceName: "SwitchLibrary"),
                                     style: .done,
                                     target: self,
                                     action: #selector(showLibraryListSheet))
        movieListController.navigationItem.leftBarButtonItem = button
      } else {
        movieListController.navigationItem.leftBarButtonItem = nil
      }
    }
  }

  // managed controllers
  private let navigationController: UINavigationController
  private let movieListController = UIStoryboard.movieList.instantiate(MovieListController.self)

  // child coordinators
  private var movieDetailsCoordinator: MovieDetailsCoordinator?
  private var editMovieCoordinator: EditMovieCoordinator?

  init(navigationController: UINavigationController,
       content: ContentSpecification,
       dependencies: AppDependencies) {
    self.dependencies = dependencies
    self.library = dependencies.library
    self.content = content
    self.navigationController = navigationController
    movieListController.delegate = self
    movieListController.posterProvider = MovieDbPosterProvider(dependencies.movieDb)
    dependencies.library.delegates.add(self)
    switch content {
      case .all:
        movieListController.title = NSLocalizedString("library", comment: "")
      case let .allWith(genreId):
        movieListController.title = L10n.genreName(for: genreId)!
    }
    DispatchQueue.global(qos: .default).async {
      self.fetchListData()
    }
  }

  func presentRootViewController() {
    self.navigationController.pushViewController(movieListController, animated: true)
  }

  private func fetchListData() {
    switch content {
      case .all:
        library.fetchMovies(then: self.handleFetchedMovies)
      case let .allWith(genreId):
        library.fetchMovies(for: genreId, then: self.handleFetchedMovies)
    }
  }

  private func handleFetchedMovies(result: AsyncResult<[Movie], MovieLibraryError>) {
    switch result {
      case let .failure(error):
        DispatchQueue.main.async {
          self.movieListController.listData = .unavailable(error)
        }
      case let .success(movies):
        DispatchQueue.main.async {
          self.movieListController.listData = .available(movies)
        }
    }
  }
}

// MARK: - MovieListControllerDelegate

extension LibraryContentCoordinator: MovieListControllerDelegate {
  func movieListController(_ controller: MovieListController, didSelect movie: Movie) {
    movieDetailsCoordinator = MovieDetailsCoordinator(for: movie, using: dependencies.movieDb)
    movieDetailsCoordinator!.delegate = self
    let editButton = UIBarButtonItem(barButtonSystemItem: .edit,
                                     target: self,
                                     action: #selector(editButtonTapped))
    movieDetailsCoordinator!.rootViewController.navigationItem.rightBarButtonItem = editButton
    self.navigationController.pushViewController(movieDetailsCoordinator!.rootViewController, animated: true)
  }

  @objc
  private func editButtonTapped() {
    guard let movie = self.movieDetailsCoordinator?.movie else {
      preconditionFailure("MovieDetailsCoordinator should present movie details")
    }
    editMovieCoordinator = EditMovieCoordinator(for: movie, in: library)
    editMovieCoordinator!.delegate = self
    self.navigationController.present(editMovieCoordinator!.rootViewController, animated: true)
  }

  func movieListControllerDidDismiss(_ controller: MovieListController) {
    self.delegate?.libraryContentCoordinatorDidDismiss(self)
  }
}

// MARK: - MovieDetailsCoordinatorDelegate

extension LibraryContentCoordinator: MovieDetailsCoordinatorDelegate {
  func movieDetailsCoordinatorDidDismiss(_ coordinator: MovieDetailsCoordinator) {
    self.movieDetailsCoordinator = nil
  }
}

// MARK: - EditMovieCoordinatorDelegate

extension LibraryContentCoordinator: EditMovieCoordinatorDelegate {
  func editMovieCoordinator(_ coordinator: EditMovieCoordinator,
                            didFinishEditingWithResult editResult: EditMovieCoordinator.EditResult) {
    switch editResult {
      case let .edited(editedMovie):
        guard let movieDetailsCoordinator = self.movieDetailsCoordinator else {
          preconditionFailure("MovieDetailsCoordinator should present movie details")
        }
        movieDetailsCoordinator.updateNonRemoteProperties(with: editedMovie)
        coordinator.rootViewController.dismiss(animated: true)
      case .deleted:
        coordinator.rootViewController.dismiss(animated: true) {
          self.navigationController.popViewController(animated: true)
          self.movieDetailsCoordinator = nil
        }
      case .canceled:
        coordinator.rootViewController.dismiss(animated: true)
    }
    self.editMovieCoordinator = nil
  }

  func editMovieCoordinator(_ coordinator: EditMovieCoordinator, didFailWithError error: Error) {
    switch error {
      case MovieLibraryError.movieDoesNotExist:
        guard let movie = self.movieDetailsCoordinator?.movie else {
          preconditionFailure("MovieDetailsCoordinator should present movie details")
        }
        fatalError("tried to edit movie which is not in library: \(movie)")
      default:
        DispatchQueue.main.async {
          let alert = UIAlertController(title: NSLocalizedString("edit.failed", comment: ""),
                                        message: NSLocalizedString("error.tryAgain", comment: ""),
                                        preferredStyle: .alert)
          alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel))
          alert.addAction(UIAlertAction(title: NSLocalizedString("discard", comment: ""),
                                        style: .destructive) { _ in
            coordinator.rootViewController.dismiss(animated: true)
            self.editMovieCoordinator = nil
          })
          coordinator.rootViewController.present(alert, animated: true)
        }
    }
  }
}

// MARK: - Switching Libraries

extension LibraryContentCoordinator {
  @objc
  private func showLibraryListSheet() {
    self.delegate?.libraryContentCoordinatorShowLibraryList(self)
  }
}

// MARK: - Library Events

extension LibraryContentCoordinator: MovieLibraryDelegate {
  func library(_ library: MovieLibrary, didUpdateContent contentUpdate: MovieLibraryContentUpdate) {
    guard case var .available(listItems) = movieListController.listData else { return }

    // updated movies
    if !contentUpdate.updatedMovies.isEmpty {
      for (id, movie) in contentUpdate.updatedMovies {
        guard let index = listItems.index(where: { $0.tmdbID == id }) else { continue }
        listItems.remove(at: index)
        listItems.insert(movie, at: index)
      }
      if let movieDetailsCoordinator = self.movieDetailsCoordinator,
         let updatedMovie = contentUpdate.updatedMovies[movieDetailsCoordinator.movie.tmdbID] {
        DispatchQueue.main.async {
          movieDetailsCoordinator.updateNonRemoteProperties(with: updatedMovie)
        }
      }
    }

    // new movies
    let newMovies: [Movie]
    switch content {
      case .all:
        newMovies = contentUpdate.addedMovies
      case let .allWith(genreId):
        newMovies = contentUpdate.addedMovies.filter { $0.genreIds.contains(genreId) }
    }
    listItems.append(contentsOf: newMovies)

    // removed movies
    if !contentUpdate.removedMovies.isEmpty {
      for movie in contentUpdate.removedMovies {
        guard let index = listItems.index(of: movie) else { continue }
        listItems.remove(at: index)
      }
    }

    DispatchQueue.main.async {
      // commit changes only when controller is not being dismissed anyway
      if listItems.isEmpty && self.dismissWhenEmpty {
        self.movieListController.onViewDidAppear = { [weak self] in
          guard let `self` = self else { return }
          self.navigationController.popViewController(animated: true)
        }
      } else {
        self.movieListController.listData = .available(listItems)
      }
    }
  }
}
