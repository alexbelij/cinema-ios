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

  // managed controller
  private let navigationController: UINavigationController
  private let genreListController: GenreListController

  // child coordinator
  private var libraryContentCoordinator: LibraryContentCoordinator?

  init(dependencies: Dependencies) {
    self.dependencies = dependencies
    // swiftlint:disable force_cast
    navigationController = UIStoryboard.genreList.instantiateInitialViewController() as! UINavigationController
    genreListController = navigationController.topViewController as! GenreListController
    // swiftlint:enable force_cast
    self.genreListController.delegate = self
    self.dependencies.library.delegates.add(self)
    DispatchQueue.global(qos: .background).async {
      let ids = self.fetchGenreIdsFromLibrary()
      DispatchQueue.main.async {
        self.genreListController.genreIds = ids
      }
    }
  }

  private func fetchGenreIdsFromLibrary() -> [Int] {
    return Array(Set(dependencies.library.mediaItems { _ in true }.flatMap { $0.genreIds }))
  }
}

// MARK: - GenreListControllerDelegate

extension GenreListCoordinator: GenreListControllerDelegate {
  func genreListController(_ controller: GenreListController,
                           didSelectGenre genreId: Int) {
    self.libraryContentCoordinator = LibraryContentCoordinator(navigationController: navigationController,
                                                               title: L10n.localizedGenreName(for: genreId)!,
                                                               contentFilter: { $0.genreIds.contains(genreId) },
                                                               dependencies: dependencies)
    self.libraryContentCoordinator!.presentRootViewController()
  }
}

// MARK: - Library Events

extension GenreListCoordinator: MediaLibraryDelegate {
  func library(_ library: MediaLibrary, didUpdateContent contentUpdate: MediaLibraryContentUpdate) {
    let updatedGenreIds: [Int]

    // When a movie has been removed from the library, we have to check,
    // if there are still other movies with the same genre id, otherwise we can remove it.
    // The easiest way is to query the entire library again.
    // But if no movies have been deleted (the most common use case) we can simplify
    // the process by adding only the new genre ids to the already computed ones.
    if contentUpdate.removedItems.isEmpty {
      var existingGenreIds = Set(genreListController.genreIds ?? [])
      contentUpdate.addedItems.flatMap { $0.genreIds }.forEach { existingGenreIds.insert($0) }
      updatedGenreIds = Array(existingGenreIds)
    } else {
      updatedGenreIds = fetchGenreIdsFromLibrary()
    }

    // commit changes
    DispatchQueue.main.async {
      self.genreListController.genreIds = updatedGenreIds
    }
  }
}
