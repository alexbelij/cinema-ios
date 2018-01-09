import Dispatch
import Foundation
import UIKit

protocol LibraryContentCoordinatorDelegate: class {
  func libraryContentCoordinatorDidDismiss(_ coordinator: LibraryContentCoordinator)
}

class LibraryContentCoordinator: AutoPresentableCoordinator {
  enum ContentSpecification {
    case all
    case allWithGenreId(Int)
  }

  typealias Dependencies = LibraryDependency & MovieDbDependency

  // coordinator stuff
  weak var delegate: LibraryContentCoordinatorDelegate?

  // other properties
  private let dependencies: Dependencies
  private let content: ContentSpecification
  var dismissWhenEmpty = false

  // managed controllers
  private let navigationController: UINavigationController
  private let movieListController: MovieListController

  // child coordinators
  private var itemDetailsCoordinator: ItemDetailsCoordinator?
  private var editItemCoordinator: EditItemCoordinator?

  init(navigationController: UINavigationController,
       content: ContentSpecification,
       dependencies: Dependencies) {
    self.dependencies = dependencies
    self.content = content
    self.navigationController = navigationController
    self.movieListController = UIStoryboard.movieList.instantiate(MovieListController.self)
    movieListController.delegate = self
    movieListController.posterProvider = MovieDbPosterProvider(dependencies.movieDb)
    dependencies.library.delegates.add(self)
    switch content {
      case .all:
        movieListController.items = dependencies.library.fetchAllMediaItems()
        movieListController.title = NSLocalizedString("library", comment: "")
      case let .allWithGenreId(genreId):
        movieListController.items = dependencies.library.fetchMediaItems(withGenreId: genreId)
        movieListController.title = L10n.localizedGenreName(for: genreId)!
    }
  }

  func presentRootViewController() {
    self.navigationController.pushViewController(movieListController, animated: true)
  }
}

// MARK: - MovieListControllerDelegate

extension LibraryContentCoordinator: MovieListControllerDelegate {
  func movieListController(_ controller: MovieListController, didSelect item: MediaItem) {
    itemDetailsCoordinator = ItemDetailsCoordinator(detailItem: item, dependencies: dependencies)
    itemDetailsCoordinator!.delegate = self
    let editButton = UIBarButtonItem(barButtonSystemItem: .edit,
                                     target: self,
                                     action: #selector(editButtonTapped))
    itemDetailsCoordinator!.rootViewController.navigationItem.rightBarButtonItem = editButton
    self.navigationController.pushViewController(itemDetailsCoordinator!.rootViewController, animated: true)
  }

  @objc
  private func editButtonTapped() {
    guard let detailItem = self.itemDetailsCoordinator?.detailItem else {
      preconditionFailure("ItemDetailsCoordinator should present detail item")
    }
    editItemCoordinator = EditItemCoordinator(item: detailItem, dependencies: dependencies)
    editItemCoordinator!.delegate = self
    self.navigationController.present(editItemCoordinator!.rootViewController, animated: true)
  }

  func movieListControllerDidDismiss(_ controller: MovieListController) {
    self.delegate?.libraryContentCoordinatorDidDismiss(self)
  }
}

// MARK: - ItemDetailsCoordinatorDelegate

extension LibraryContentCoordinator: ItemDetailsCoordinatorDelegate {
  func itemDetailsCoordinatorDidDismiss(_ coordinator: ItemDetailsCoordinator) {
    self.itemDetailsCoordinator = nil
  }
}

// MARK: - EditItemCoordinatorDelegate

extension LibraryContentCoordinator: EditItemCoordinatorDelegate {
  func editItemCoordinator(_ coordinator: EditItemCoordinator,
                           didFinishEditingWithResult editResult: EditItemCoordinator.EditResult) {
    switch editResult {
      case let .edited(editedItem):
        guard let itemDetailsCoordinator = self.itemDetailsCoordinator else {
          preconditionFailure("ItemDetailsCoordinator should present detail item")
        }
        itemDetailsCoordinator.updateNonRemoteProperties(with: editedItem)
        coordinator.rootViewController.dismiss(animated: true)
      case .deleted:
        coordinator.rootViewController.dismiss(animated: true) {
          self.navigationController.popViewController(animated: true)
          self.itemDetailsCoordinator = nil
        }
      case .canceled:
        coordinator.rootViewController.dismiss(animated: true)
    }
    self.editItemCoordinator = nil
  }

  func editItemCoordinator(_ coordinator: EditItemCoordinator, didFailWithError error: Error) {
    switch error {
      case MediaLibraryError.itemDoesNotExist:
        guard let detailItem = self.itemDetailsCoordinator?.detailItem else {
          preconditionFailure("ItemDetailsCoordinator should present detail item")
        }
        fatalError("tried to edit item which is not in library: \(detailItem)")
      default:
        DispatchQueue.main.async {
          let alert = UIAlertController(title: L10n.localizedErrorMessage(for: error),
                                        message: nil,
                                        preferredStyle: .alert)
          alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel))
          alert.addAction(UIAlertAction(title: NSLocalizedString("discard", comment: ""),
                                        style: .destructive) { _ in
            coordinator.rootViewController.dismiss(animated: true)
            self.editItemCoordinator = nil
          })
          coordinator.rootViewController.present(alert, animated: true)
        }
    }
  }
}

// MARK: - Library Events

extension LibraryContentCoordinator: MediaLibraryDelegate {
  func library(_ library: MediaLibrary, didUpdateContent contentUpdate: MediaLibraryContentUpdate) {
    var movieListItems = movieListController.items

    // updated movies
    if !contentUpdate.updatedItems.isEmpty {
      for (id, item) in contentUpdate.updatedItems {
        guard let index = movieListItems.index(where: { $0.id == id }) else { continue }
        movieListItems.remove(at: index)
        movieListItems.insert(item, at: index)
      }
      DispatchQueue.main.async {
        if let itemDetailsCoordinator = self.itemDetailsCoordinator,
           let updatedDetailItem = contentUpdate.updatedItems[itemDetailsCoordinator.detailItem.id] {
          self.itemDetailsCoordinator!.updateNonRemoteProperties(with: updatedDetailItem)
        }
      }
    }

    // new movies
    let newMovies: [MediaItem]
    switch content {
      case .all:
        newMovies = contentUpdate.addedItems
      case let .allWithGenreId(genreId):
        newMovies = contentUpdate.addedItems.filter { $0.genreIds.contains(genreId) }
    }
    movieListItems.append(contentsOf: newMovies)

    // removed movies
    if !contentUpdate.removedItems.isEmpty {
      for item in contentUpdate.removedItems {
        guard let index = movieListItems.index(of: item) else { continue }
        movieListItems.remove(at: index)
      }
    }

    DispatchQueue.main.async {
      // commit changes only when controller is not being dismissed anyway
      if movieListItems.isEmpty && self.dismissWhenEmpty {
        self.movieListController.onViewDidAppear = { [weak self] in
          guard let `self` = self else { return }
          self.navigationController.popViewController(animated: true)
        }
      } else {
        self.movieListController.items = movieListItems
      }
    }
  }
}
