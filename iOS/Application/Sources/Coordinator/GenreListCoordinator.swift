import CinemaKit
import Dispatch
import Foundation
import UIKit

class GenreListCoordinator: CustomPresentableCoordinator {
  typealias Dependencies = LibraryDependency & MovieDbDependency

  // coordinator stuff
  var rootViewController: UIViewController {
    return navigationController
  }

  // other properties
  private let dependencies: Dependencies

  // other properties
  private let backdropSize: BackdropSize

  // managed controller
  private let navigationController: UINavigationController
  private let genreListController = UIStoryboard.genreList.instantiate(GenreListController.self)

  // child coordinator
  private var libraryContentCoordinator: LibraryContentCoordinator?

  init(dependencies: Dependencies) {
    self.dependencies = dependencies
    navigationController = UINavigationController(rootViewController: genreListController)
    self.backdropSize = BackdropSize(minWidth: Int(genreListController.view.bounds.width))
    self.genreListController.delegate = self
    self.dependencies.library.delegates.add(self)
    DispatchQueue.global(qos: .default).async {
      self.fetchListData()
    }
  }

  private func fetchListData() {
    let items = dependencies.library.fetchAllMediaItems()
    let imageProvider = RandomMovieGenreImageProvider(for: items,
                                                      movieDb: dependencies.movieDb,
                                                      backdropSize: self.backdropSize)
    let ids = Array(Set(items.flatMap { $0.genreIds }))
    DispatchQueue.main.async {
      self.genreListController.genreImageProvider = imageProvider
      self.genreListController.listData = .available(ids)
    }
  }
}

// MARK: - GenreListControllerDelegate

extension GenreListCoordinator: GenreListControllerDelegate {
  func genreListController(_ controller: GenreListController,
                           didSelectGenre genreId: GenreIdentifier) {
    self.libraryContentCoordinator = LibraryContentCoordinator(navigationController: navigationController,
                                                               content: .allWith(genreId),
                                                               dependencies: dependencies)
    self.libraryContentCoordinator!.dismissWhenEmpty = true
    self.libraryContentCoordinator!.presentRootViewController()
  }
}

// MARK: - Library Events

extension GenreListCoordinator: MediaLibraryDelegate {
  func library(_ library: MediaLibrary, didUpdateContent contentUpdate: MediaLibraryContentUpdate) {
    let updatedGenreIds: [GenreIdentifier]
    var updatedGenreImageProvider: GenreImageProvider? = nil

    // When a movie has been removed from the library, we have to check,
    // if there are still other movies with the same genre id, otherwise we can remove it.
    // The easiest way is to query the entire library again.
    // But if no movies have been deleted (the most common use case) we can simplify
    // the process by adding only the new genre ids to the already computed ones.
    if contentUpdate.removedItems.isEmpty,
       case let .available(genreListItems) = genreListController.listData {
      var existingGenreIds = Set(genreListItems)
      contentUpdate.addedItems.flatMap { $0.genreIds }.forEach { existingGenreIds.insert($0) }
      updatedGenreIds = Array(existingGenreIds)
      // swiftlint:disable:next force_cast
      (self.genreListController.genreImageProvider as! RandomMovieGenreImageProvider)
          .updateWithNewItems(contentUpdate.addedItems)
    } else {
      let items = dependencies.library.fetchAllMediaItems()
      updatedGenreIds = Array(Set(items.flatMap { $0.genreIds }))
      updatedGenreImageProvider = RandomMovieGenreImageProvider(for: items,
                                                                movieDb: self.dependencies.movieDb,
                                                                backdropSize: self.backdropSize)
    }

    // commit changes
    DispatchQueue.main.async {
      self.genreListController.listData = .available(updatedGenreIds)
      if let provider = updatedGenreImageProvider {
        self.genreListController.genreImageProvider = provider
      }
    }
  }
}

// MARK: - Genre Image Provider

private class RandomMovieGenreImageProvider: GenreImageProvider {
  private let movieDb: MovieDbClient
  private var genreGroups = [GenreIdentifier: [MediaItem]]()
  private let maxRetries = 2
  var backdropSize: BackdropSize

  init(for items: [MediaItem], movieDb: MovieDbClient, backdropSize: BackdropSize) {
    self.movieDb = movieDb
    self.backdropSize = backdropSize
    updateWithNewItems(items)
  }

  func updateWithNewItems(_ items: [MediaItem]) {
    for item in items {
      for genreId in item.genreIds {
        if genreGroups[genreId] == nil {
          genreGroups[genreId] = [item]
        } else {
          genreGroups[genreId]!.append(item)
        }
      }
    }
  }

  func genreImage(for genreId: GenreIdentifier) -> UIImage? {
    guard let mediaItems = genreGroups[genreId] else { return nil }
    for _ in 0..<maxRetries {
      let randomIndex = Int(arc4random_uniform(UInt32(mediaItems.count)))
      if let backdrop = movieDb.backdrop(for: mediaItems[randomIndex].tmdbID, size: backdropSize) {
        return backdrop
      }
    }
    return nil
  }
}
