import CinemaKit
import Dispatch
import UIKit

class SearchTmdbCoordinator: CustomPresentableCoordinator {
  // coordinator stuff
  var rootViewController: UIViewController {
    return navigationController
  }

  // other properties
  var library: MovieLibrary {
    willSet {
      library.delegates.remove(self)
    }
    didSet {
      library.delegates.add(self)
      setupPopularMovies()
    }
  }
  private let movieDb: MovieDbClient
  private let notificationCenter: NotificationCenter
  private var cachedSearchResults = [ExternalMovieViewModel]()
  private var tmdbIDsInLibrary: Set<TmdbIdentifier>?

  // managed controllers
  private let navigationController: UINavigationController
  private let searchTmdbController = UIStoryboard.searchTmdb.instantiate(SearchTmdbController.self)
  private let popularMoviesController = UIStoryboard.popularMovies.instantiate(PopularMoviesController.self)

  init(for library: MovieLibrary, dependencies: AppDependencies) {
    self.library = library
    self.movieDb = dependencies.movieDb
    self.notificationCenter = dependencies.notificationCenter

    self.navigationController = UINavigationController(rootViewController: searchTmdbController)

    popularMoviesController.delegate = self
    popularMoviesController.posterProvider = MovieDbPosterProvider(movieDb)

    searchTmdbController.delegate = self
    searchTmdbController.posterProvider = MovieDbPosterProvider(movieDb)
    searchTmdbController.additionalViewController = popularMoviesController

    self.library.delegates.add(self)
    setupPopularMovies()
  }

  private func setupPopularMovies() {
    library.fetchMovies { result in
      switch result {
        case .failure: break
        case let .success(movies):
          DispatchQueue.main.async {
            self.tmdbIDsInLibrary = Set(movies.map { $0.tmdbID })
            let movies = self.movieDb.popularMovies().lazy.filter { [set = self.tmdbIDsInLibrary] in
              !(set?.contains($0.tmdbID) ?? false)
            }
            self.popularMoviesController.movieIterator = AnyIterator(movies.makeIterator())
          }
      }
    }
  }
}

extension SearchTmdbCoordinator: SearchTmdbControllerDelegate {
  func searchTmdbController(_ controller: SearchTmdbController,
                            searchResultsFor searchText: String) -> [ExternalMovieViewModel] {
    cachedSearchResults = self.movieDb.searchMovies(searchText: searchText).map { movie in
      if let existing = cachedSearchResults.first(where: { $0.movie.tmdbID == movie.tmdbID }) {
        return existing
      } else {
        let hasBeenAdded = self.tmdbIDsInLibrary?.contains(movie.tmdbID) ?? false
        return ExternalMovieViewModel(movie, state: hasBeenAdded ? .addedToLibrary : .new)
      }
    }
    return cachedSearchResults
  }

  func searchTmdbController(_ controller: SearchTmdbController, didSelect model: ExternalMovieViewModel) {
    self.showAddAlert(over: controller) { diskType in
      DispatchQueue.main.async {
        model.state = .updateInProgress
        controller.reloadRow(forMovieWithId: model.movie.tmdbID)
      }
      DispatchQueue.global(qos: .userInitiated).async {
        self.library.addMovie(with: model.tmdbID, diskType: diskType) { result in
          self.handleAddResult(result, for: model)
        }
      }
    }
  }

  private func handleAddResult(_ result: Result<Movie, MovieLibraryError>, for model: ExternalMovieViewModel) {
    switch result {
      case let .failure(error):
        switch error {
          case .detailsFetchError:
            fatalError("not implemented")
          case let .globalError(event):
            notificationCenter.post(event.notification)
          case .nonRecoverableError:
            DispatchQueue.main.async {
              model.state = .new
              self.searchTmdbController.reloadRow(forMovieWithId: model.movie.tmdbID)
              self.popularMoviesController.reloadRow(forMovieWithId: model.movie.tmdbID)
              self.rootViewController.presentErrorAlert()
            }
          case .movieDoesNotExist:
            fatalError("should not occur: \(error)")
        }
      case .success:
        DispatchQueue.main.async {
          model.state = .addedToLibrary
          self.searchTmdbController.reloadRow(forMovieWithId: model.movie.tmdbID)
          DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            self.popularMoviesController.removeMovie(withId: model.movie.tmdbID)
          }
        }
    }
  }
}

extension SearchTmdbCoordinator: PopularMoviesControllerDelegate {
  func popularMoviesController(_ controller: PopularMoviesController, didSelect model: ExternalMovieViewModel) {
    showAddAlert(over: controller) { diskType in
      DispatchQueue.main.async {
        model.state = .updateInProgress
        controller.reloadRow(forMovieWithId: model.movie.tmdbID)
      }
      DispatchQueue.global(qos: .userInitiated).async {
        self.library.addMovie(with: model.tmdbID, diskType: diskType) { result in
          self.handleAddResult(result, for: model)
        }
      }
    }
  }
}

extension SearchTmdbCoordinator {
  private func showAddAlert(over controller: UIViewController,
                            then completion: @escaping (DiskType) -> Void) {
    let alert = UIAlertController(title: NSLocalizedString("addMovie.alert.howToAdd.title", comment: ""),
                                  message: nil,
                                  preferredStyle: .alert)
    for diskType in [DiskType.dvd, .bluRay] {
      alert.addAction(UIAlertAction(title: diskType.localizedName, style: .default) { _ in
        completion(diskType)
      })
    }
    alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel))
    controller.present(alert, animated: true)
  }
}

extension SearchTmdbCoordinator: MovieLibraryDelegate {
  func libraryDidUpdateMetadata(_ library: MovieLibrary) {
  }

  func library(_ library: MovieLibrary, didUpdateMovies changeSet: ChangeSet<TmdbIdentifier, Movie>) {
    DispatchQueue.main.async {
      if self.tmdbIDsInLibrary == nil { return }
      for movie in changeSet.insertions {
        self.tmdbIDsInLibrary!.insert(movie.tmdbID)
        self.popularMoviesController.removeMovie(withId: movie.tmdbID)
      }
      for (tmdbID, _) in changeSet.deletions {
        self.tmdbIDsInLibrary!.remove(tmdbID)
      }
    }
  }
}
