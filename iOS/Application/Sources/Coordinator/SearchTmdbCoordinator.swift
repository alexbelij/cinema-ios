import CinemaKit
import Dispatch
import UIKit

class SearchTmdbCoordinator: CustomPresentableCoordinator {
  typealias Dependencies = LibraryDependency & MovieDbDependency

  // coordinator stuff
  var rootViewController: UIViewController {
    return navigationController
  }

  // other properties
  private let dependencies: Dependencies
  private var library: MediaLibrary {
    return dependencies.library
  }
  private var movieDb: MovieDbClient {
    return dependencies.movieDb
  }
  private var cachedSearchResults = [SearchTmdbController.SearchResult]()

  // managed controllers
  private let navigationController: UINavigationController
  private let searchTmdbController = UIStoryboard.searchTmdb.instantiate(SearchTmdbController.self)
  private let popularMoviesController = UIStoryboard.popularMovies.instantiate(PopularMoviesController.self)

  init(dependencies: Dependencies) {
    self.dependencies = dependencies

    self.navigationController = UINavigationController(rootViewController: searchTmdbController)

    popularMoviesController.delegate = self
    let movies = movieDb.popularMovies().lazy.filter { !self.library.containsMediaItem(with: $0.tmdbID) }
    popularMoviesController.movieIterator = AnyIterator(movies.makeIterator())
    popularMoviesController.posterProvider = MovieDbPosterProvider(movieDb)

    searchTmdbController.delegate = self
    searchTmdbController.posterProvider = MovieDbPosterProvider(dependencies.movieDb)
    searchTmdbController.additionalViewController = popularMoviesController
  }
}

extension SearchTmdbCoordinator: SearchTmdbControllerDelegate {
  func searchTmdbController(_ controller: SearchTmdbController,
                            searchResultsFor searchText: String) -> [SearchTmdbController.SearchResult] {
    cachedSearchResults = self.movieDb.searchMovies(searchText: searchText).map { movie in
      if let existing = cachedSearchResults.first(where: { $0.movie.tmdbID == movie.tmdbID }) {
        return existing
      } else {
        return SearchTmdbController.SearchResult(
            movie,
            state: self.library.containsMediaItem(with: movie.tmdbID) ? .addedToLibrary : .new)
      }
    }
    return cachedSearchResults
  }

  func searchTmdbController(_ controller: SearchTmdbController,
                            didSelectSearchResult searchResult: SearchTmdbController.SearchResult) {
    self.showAddAlert(over: controller) { diskType in
      DispatchQueue.global(qos: .userInitiated).async {
        self.add(searchResult.movie, withDiskType: diskType) { error in
          if let error = error {
            DispatchQueue.main.async {
              searchResult.state = .new
              controller.reloadRow(forMovieWithId: searchResult.movie.tmdbID)
              self.showAddingFailedAlert(for: error)
            }
          } else {
            DispatchQueue.main.async {
              searchResult.state = .addedToLibrary
              controller.reloadRow(forMovieWithId: searchResult.movie.tmdbID)
              self.popularMoviesController.removeItem(searchResult.movie)
            }
          }
        }
      }
    }
  }
}

extension SearchTmdbCoordinator: PopularMoviesControllerDelegate {
  func popularMoviesController(_ controller: PopularMoviesController, didSelect movie: PartialMediaItem) {
    showAddAlert(over: controller) { diskType in
      DispatchQueue.global(qos: .userInitiated).async {
        self.add(movie, withDiskType: diskType) { error in
          if let error = error {
            DispatchQueue.main.async {
              self.showAddingFailedAlert(for: error)
            }
          } else {
            DispatchQueue.main.async {
              self.popularMoviesController.removeItem(movie)
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
    let alert = UIAlertController(title: NSLocalizedString("addItem.alert.howToAdd.title", comment: ""),
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

  private func add(_ item: PartialMediaItem,
                   withDiskType diskType: DiskType,
                   then completion: @escaping (Error?) -> Void) {
    let fullItem = MediaItem(tmdbID: item.tmdbID,
                             title: item.title,
                             runtime: self.movieDb.runtime(for: item.tmdbID),
                             releaseDate: self.movieDb.releaseDate(for: item.tmdbID),
                             diskType: diskType,
                             genreIds: self.movieDb.genreIds(for: item.tmdbID))
    do {
      try self.library.add(fullItem)
      completion(nil)
    } catch {
      completion(error)
    }
  }

  private func showAddingFailedAlert(for error: Error) {
    let alert = UIAlertController(title: NSLocalizedString("addItem.failed", comment: ""),
                                  message: L10n.errorMessage(for: error),
                                  preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default))
    rootViewController.present(alert, animated: true)
  }
}
