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
    didSet {
      setup()
    }
  }
  private var movieDb: MovieDbClient
  private var cachedSearchResults = [ExternalMovieViewModel]()

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

    setup()
  }

  private func setup() {
    DispatchQueue.main.async {
      let movies = self.movieDb.popularMovies().lazy.filter { [library = self.library] in
        !library.containsMovie(with: $0.tmdbID)
      }
      self.popularMoviesController.movieIterator = AnyIterator(movies.makeIterator())
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
        return ExternalMovieViewModel(
            movie,
            state: self.library.containsMovie(with: movie.tmdbID) ? .addedToLibrary : .new)
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
        self.add(model.movie, withDiskType: diskType) { error in
          if error == nil {
            DispatchQueue.main.async {
              model.state = .addedToLibrary
              controller.reloadRow(forMovieWithId: model.movie.tmdbID)
              self.popularMoviesController.removeMovie(withId: model.movie.tmdbID)
            }
          } else {
            DispatchQueue.main.async {
              model.state = .new
              controller.reloadRow(forMovieWithId: model.movie.tmdbID)
              self.showAddingFailedAlert(for: model.movie)
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
        self.add(model.movie, withDiskType: diskType) { error in
          if error == nil {
            DispatchQueue.main.async {
              model.state = .addedToLibrary
              controller.reloadRow(forMovieWithId: model.movie.tmdbID)
              DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                controller.removeMovie(withId: model.movie.tmdbID)
              }
            }
          } else {
            DispatchQueue.main.async {
              model.state = .new
              controller.reloadRow(forMovieWithId: model.movie.tmdbID)
              self.showAddingFailedAlert(for: model.movie)
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

  private func add(_ item: PartialMovie,
                   withDiskType diskType: DiskType,
                   then completion: @escaping (Error?) -> Void) {
    let fullItem = Movie(tmdbID: item.tmdbID,
                         title: item.title,
                         runtime: self.movieDb.runtime(for: item.tmdbID),
                         releaseDate: self.movieDb.releaseDate(for: item.tmdbID),
                         diskType: diskType,
                         genreIds: self.movieDb.genreIds(for: item.tmdbID))
    library.add(fullItem) { result in
      switch result {
        case let .failure(error): completion(error)
        case .success: completion(nil)
      }
    }
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
