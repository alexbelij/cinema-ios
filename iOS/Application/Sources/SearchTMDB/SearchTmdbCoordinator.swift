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
      setup()
    }
  }
  private var movieDb: MovieDbClient
  private var cachedSearchResults = [ExternalMovieViewModel]()
  private var tmdbIDsInLibrary: Set<TmdbIdentifier>?

  // managed controllers
  private let navigationController: UINavigationController
  private let searchTmdbController = UIStoryboard.searchTmdb.instantiate(SearchTmdbController.self)
  private let popularMoviesController = UIStoryboard.popularMovies.instantiate(PopularMoviesController.self)

  init(for library: MovieLibrary, using movieDb: MovieDbClient) {
    self.library = library
    self.movieDb = movieDb

    self.navigationController = UINavigationController(rootViewController: searchTmdbController)

    popularMoviesController.delegate = self
    popularMoviesController.posterProvider = MovieDbPosterProvider(movieDb)

    searchTmdbController.delegate = self
    searchTmdbController.posterProvider = MovieDbPosterProvider(movieDb)
    searchTmdbController.additionalViewController = popularMoviesController

    library.delegates.add(self)
    setup()
  }

  private func setup() {
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
          switch result {
            case .failure:
              DispatchQueue.main.async {
                model.state = .new
                controller.reloadRow(forMovieWithId: model.movie.tmdbID)
                self.showAddingFailedAlert(for: model.movie)
              }
            case .success:
              DispatchQueue.main.async {
                model.state = .addedToLibrary
                controller.reloadRow(forMovieWithId: model.movie.tmdbID)
                self.popularMoviesController.removeMovie(withId: model.movie.tmdbID)
              }
          }
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
          switch result {
            case .failure:
              DispatchQueue.main.async {
                model.state = .new
                controller.reloadRow(forMovieWithId: model.movie.tmdbID)
                self.showAddingFailedAlert(for: model.movie)
              }
            case .success:
              DispatchQueue.main.async {
                model.state = .addedToLibrary
                controller.reloadRow(forMovieWithId: model.movie.tmdbID)
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                  controller.removeMovie(withId: model.movie.tmdbID)
                }
              }
          }
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

  private func showAddingFailedAlert(for movie: PartialMovie) {
    let format = NSLocalizedString("addMovie.failed", comment: "")
    let alert = UIAlertController(title: .localizedStringWithFormat(format, movie.title),
                                  message: NSLocalizedString("error.tryAgain", comment: ""),
                                  preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default))
    rootViewController.present(alert, animated: true)
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
