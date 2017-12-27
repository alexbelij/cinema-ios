import Dispatch
import Foundation
import UIKit

class LibraryContentCoordinator: AutoPresentableCoordinator {
  typealias Dependencies = LibraryDependency & MovieDbDependency

  // other properties
  private let dependencies: Dependencies

  // managed controllers
  private let navigationController: UINavigationController
  private let movieListController: MovieListController

  // child coordinators
  private var itemDetailsCoordinator: ItemDetailsCoordinator?
  private var editItemCoordinator: EditItemCoordinator?

  init(navigationController: UINavigationController, title: String, dependencies: Dependencies) {
    self.dependencies = dependencies
    self.navigationController = navigationController
    self.movieListController = UIStoryboard.movieList.instantiate(MovieListController.self)
    movieListController.delegate = self
    movieListController.title = title
    let posterProvider = MovieDbPosterProvider(dependencies.movieDb)
    movieListController.cellConfiguration = StandardMediaItemCellConfig(posterProvider: posterProvider)
    movieListController.items = dependencies.library.mediaItems { _ in true }
    dependencies.library.delegates.add(self)
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
    DispatchQueue.global(qos: .background).async {
      let items = library.mediaItems { _ in true }
      DispatchQueue.main.async {
        self.movieListController.items = items
      }
    }
  }
}

class StandardMediaItemCellConfig: MediaItemCellConfig {
  private let posterProvider: PosterProvider

  init(posterProvider: PosterProvider) {
    self.posterProvider = posterProvider
  }

  func registerCells(in cellRegistering: CellRegistering) {
    cellRegistering.registerNibCell(MovieListTableCell.self, bundle: nil)
  }

  func cell(for item: MovieListItem, cellDequeuing: CellDequeuing) -> UITableViewCell {
    let cell = cellDequeuing.dequeueReusableCell(MovieListTableCell.self)
    cell.configure(for: item, posterProvider: posterProvider)
    return cell
  }
}
