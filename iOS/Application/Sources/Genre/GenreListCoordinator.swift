import CinemaKit
import Dispatch
import Foundation
import UIKit

class GenreListCoordinator: CustomPresentableCoordinator {
  // coordinator stuff
  var rootViewController: UIViewController {
    return navigationController
  }

  // other properties
  private let dependencies: AppDependencies
  var library: MovieLibrary {
    willSet {
      library.delegates.remove(self)
    }
    didSet {
      setup()
    }
  }
  private let movieDb: MovieDbClient
  private let notificationCenter: NotificationCenter

  // other properties
  private let backdropSize: BackdropSize

  // managed controller
  private let navigationController: UINavigationController
  private let genreListController = UIStoryboard.genreList.instantiate(GenreListController.self)

  // child coordinator
  private var libraryContentCoordinator: LibraryContentCoordinator?

  init(for library: MovieLibrary, dependencies: AppDependencies) {
    self.dependencies = dependencies
    self.library = library
    self.movieDb = dependencies.movieDb
    self.notificationCenter = dependencies.notificationCenter
    navigationController = UINavigationController(rootViewController: genreListController)
    self.backdropSize = BackdropSize(minWidth: Int(genreListController.view.bounds.width))
    self.genreListController.delegate = self
    setup()
  }

  private func setup() {
    self.library.delegates.add(self)
    DispatchQueue.global(qos: .default).async {
      self.fetchListData()
    }
  }

  private func fetchListData() {
    library.fetchMovies { result in
      switch result {
        case let .failure(error):
          switch error {
            case let .globalError(event):
              self.notificationCenter.post(event.notification)
            case .nonRecoverableError:
              DispatchQueue.main.async {
                self.genreListController.listData = .unavailable
              }
            case .tmdbDetailsCouldNotBeFetched, .movieDoesNotExist, .permissionFailure:
              fatalError("should not occur: \(error)")
          }
        case let .success(movies):
          DispatchQueue.main.async {
            let imageProvider = RandomMovieGenreImageProvider(for: movies,
                                                              movieDb: self.movieDb,
                                                              backdropSize: self.backdropSize)
            let ids = Array(Set(movies.flatMap { $0.genreIds }))
            DispatchQueue.main.async {
              self.genreListController.genreImageProvider = imageProvider
              self.genreListController.listData = .available(ids)
            }
          }
      }
    }
  }
}

// MARK: - GenreListControllerDelegate

extension GenreListCoordinator: GenreListControllerDelegate {
  func genreListController(_ controller: GenreListController,
                           didSelectGenre genreId: GenreIdentifier) {
    self.libraryContentCoordinator = LibraryContentCoordinator(for: library,
                                                               displaying: .allWith(genreId),
                                                               navigationController: navigationController,
                                                               dependencies: dependencies)
    self.libraryContentCoordinator!.delegate = self
    self.libraryContentCoordinator!.dismissWhenEmpty = true
    self.libraryContentCoordinator!.presentRootViewController()
  }
}

// MARK: - LibraryContentCoordinatorDelegate

extension GenreListCoordinator: LibraryContentCoordinatorDelegate {
  func libraryContentCoordinatorShowLibraryList(_ coordinator: LibraryContentCoordinator) {
    fatalError("library can not be switched here")
  }

  func libraryContentCoordinatorDidDismiss(_ coordinator: LibraryContentCoordinator) {
    libraryContentCoordinator = nil
  }
}

// MARK: - Library Events

extension GenreListCoordinator: MovieLibraryDelegate {
  func libraryDidUpdateMetadata(_ library: MovieLibrary) {
  }

  func library(_ library: MovieLibrary, didUpdateMovies changeSet: ChangeSet<TmdbIdentifier, Movie>) {
    DispatchQueue.global().async {
      self.update(with: changeSet)
    }
  }

  // When a movie has been removed from the library, we have to check,
  // if there are still other movies with the same genre id, otherwise we can remove it.
  // The easiest way is to query the entire library again.
  // But if no movies have been deleted (the most common use case) we can simplify
  // the process by adding only the new genre ids to the already computed ones.
  private func update(with changeSet: ChangeSet<TmdbIdentifier, Movie>) {
    if changeSet.deletions.isEmpty {
      DispatchQueue.main.sync {
        if case let .available(genreListItems) = genreListController.listData {
          var existingGenreIds = Set(genreListItems)
          changeSet.insertions.flatMap { $0.genreIds }.forEach { existingGenreIds.insert($0) }
          let updatedGenreIds = Array(existingGenreIds)
          // swiftlint:disable:next force_cast
          (self.genreListController.genreImageProvider as! RandomMovieGenreImageProvider)
              .updateWithNewMovies(changeSet.insertions)
          self.genreListController.listData = .available(updatedGenreIds)
        }
      }
    } else {
      self.fetchListData()
    }
  }
}

// MARK: - Genre Image Provider

private class RandomMovieGenreImageProvider: GenreImageProvider {
  private let movieDb: MovieDbClient
  private var genreGroups = [GenreIdentifier: [Movie]]()
  private let maxRetries = 2
  var backdropSize: BackdropSize

  init(for movies: [Movie], movieDb: MovieDbClient, backdropSize: BackdropSize) {
    self.movieDb = movieDb
    self.backdropSize = backdropSize
    updateWithNewMovies(movies)
  }

  func updateWithNewMovies(_ movies: [Movie]) {
    for movies in movies {
      for genreId in movies.genreIds {
        if genreGroups[genreId] == nil {
          genreGroups[genreId] = [movies]
        } else {
          genreGroups[genreId]!.append(movies)
        }
      }
    }
  }

  func genreImage(for genreId: GenreIdentifier) -> UIImage? {
    guard let movies = genreGroups[genreId] else { return nil }
    for _ in 0..<maxRetries {
      let randomIndex = Int(arc4random_uniform(UInt32(movies.count)))
      if let backdrop = movieDb.backdrop(for: movies[randomIndex].tmdbID, size: backdropSize) {
        return backdrop
      }
    }
    return nil
  }
}
