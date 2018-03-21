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

  // managed controllers
  private let navigationController: UINavigationController
  private let popularMoviesController: PopularMoviesController

  init(dependencies: Dependencies) {
    self.dependencies = dependencies

    // swiftlint:disable:next force_cast
    self.navigationController = UIStoryboard.searchTmdb.instantiateInitialViewController() as! UINavigationController

    popularMoviesController = UIStoryboard.popularMovies.instantiate(PopularMoviesController.self)
    popularMoviesController.delegate = self
    let movies = movieDb.popularMovies().lazy.filter { !self.library.containsMediaItem(with: $0.tmdbID) }
    popularMoviesController.movieIterator = AnyIterator(movies.makeIterator())
    popularMoviesController.posterProvider = MovieDbPosterProvider(movieDb)

    // swiftlint:disable:next force_cast
    let searchTmdbController = navigationController.topViewController! as! SearchTmdbController
    searchTmdbController.delegate = self
    searchTmdbController.additionalViewController = popularMoviesController
  }
}

extension SearchTmdbCoordinator: SearchTmdbControllerDelegate {
  func searchTmdbController(_ controller: SearchTmdbController,
                            searchResultsFor searchText: String) -> [SearchTmdbController.SearchResult] {
    return self.movieDb.searchMovies(searchText: searchText).map { movie in
      SearchTmdbController.SearchResult(item: movie,
                                        hasBeenAddedToLibrary: self.library.containsMediaItem(with: movie.tmdbID))
    }
  }

  func searchTmdbController(_ controller: SearchTmdbController,
                            didSelectSearchResult searchResult: SearchTmdbController.SearchResult) {
    self.showAddAlert(for: searchResult.item, over: controller)
  }
}

extension SearchTmdbCoordinator: PopularMoviesControllerDelegate {
  func popularMoviesController(_ controller: PopularMoviesController, didSelect movie: PartialMediaItem) {
    showAddAlert(for: movie, over: controller)
  }
}

extension SearchTmdbCoordinator {
  private func showAddAlert(for item: PartialMediaItem, over controller: UIViewController) {
    let alert = UIAlertController(title: NSLocalizedString("addItem.alert.howToAdd.title", comment: ""),
                                  message: nil,
                                  preferredStyle: .alert)
    for diskType in [DiskType.dvd, .bluRay] {
      alert.addAction(UIAlertAction(title: diskType.localizedName, style: .default) { _ in
        self.showLibraryUpdateController(for: item, diskType: diskType, over: controller)
      })
    }
    alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel))
    controller.present(alert, animated: true)
  }

  private func showLibraryUpdateController(for item: PartialMediaItem,
                                           diskType: DiskType,
                                           over controller: UIViewController) {
    let libraryUpdateController = UIStoryboard.searchTmdb.instantiate(LibraryUpdateController.self)
    DispatchQueue.global(qos: .userInitiated).async {
      if let poster = self.movieDb.poster(for: item.tmdbID, size: PosterSize(minWidth: 185)) {
        DispatchQueue.main.async {
          libraryUpdateController.poster = poster
        }
      }
    }
    controller.present(libraryUpdateController, animated: true)
    DispatchQueue.global(qos: .userInitiated).async {
      let fullItem = MediaItem(tmdbID: item.tmdbID,
                               title: item.title,
                               runtime: self.movieDb.runtime(for: item.tmdbID),
                               releaseDate: item.releaseDate,
                               diskType: diskType,
                               genreIds: self.movieDb.genreIds(for: item.tmdbID))
      do {
        try self.library.add(fullItem)
        DispatchQueue.main.async {
          libraryUpdateController.endUpdate(result: .success(addedItemTitle: item.title))
          DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            libraryUpdateController.dismiss(animated: true) {
              self.popularMoviesController.removeItem(item)
            }
          }
        }
      } catch let error {
        DispatchQueue.main.async {
          libraryUpdateController.endUpdate(result: .failure(error))
          DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            libraryUpdateController.dismiss(animated: true)
          }
        }
      }
    }
  }
}
