import Dispatch
import Foundation
import UIKit

protocol ItemDetailsCoordinatorDelegate: class {
  func itemDetailsCoordinatorDidDismiss(_ coordinator: ItemDetailsCoordinator)
}

class ItemDetailsCoordinator: AutoPresentableCoordinator {
  // coordinator stuff
  weak var delegate: ItemDetailsCoordinatorDelegate?

  // other properties
  private let library: MediaLibrary
  private let movieDb: MovieDbClient
  private(set) var detailItem: MediaItem

  // managed controller
  private let navigationController: UINavigationController
  private var itemDetailsController: ItemDetailsController

  // child coordinator
  private var editItemCoordinator: EditItemCoordinator?

  init(navigationController: UINavigationController,
       library: MediaLibrary,
       movieDb: MovieDbClient,
       detailItem: MediaItem) {
    self.navigationController = navigationController
    self.library = library
    self.movieDb = movieDb
    self.detailItem = detailItem

    itemDetailsController = UIStoryboard.main.instantiate(ItemDetailsController.self)
    itemDetailsController.delegate = self
    configure(for: self.detailItem, resetRemoteProperties: true)
    fetchRemoteData(for: self.detailItem.id)
  }

  func presentRootViewController() {
    navigationController.pushViewController(itemDetailsController, animated: true)
  }
}

// MARK: - Remote Data Fetching

extension ItemDetailsCoordinator {
  private func fetchRemoteData(for id: Int) {
    DispatchQueue.main.async {
      UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }
    let queue = DispatchQueue.global(qos: .userInitiated)
    let group = DispatchGroup()
    self.fetchRemoteValue(for: \ItemDetailsController.poster, on: queue, in: group) {
      self.movieDb.poster(for: id, size: PosterSize(minWidth: 92))
    }
    self.fetchRemoteValue(for: \ItemDetailsController.certification, on: queue, in: group) {
      self.movieDb.certification(for: id)?.nilIfEmptyString
    }
    self.fetchRemoteValue(for: \ItemDetailsController.overview, on: queue, in: group) {
      self.movieDb.overview(for: id)?.nilIfEmptyString
    }
    group.notify(queue: .main) {
      UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
  }

  private func fetchRemoteValue<T>(
      for keyPath: WritableKeyPath<ItemDetailsController, ItemDetailsController.RemoteProperty<T>>,
      on queue: DispatchQueue,
      in group: DispatchGroup,
      fetchBlock: @escaping () -> T?) {
    group.enter()
    queue.async {
      if let value = fetchBlock() {
        DispatchQueue.main.async {
          self.itemDetailsController[keyPath: keyPath] = .available(value)
          group.leave()
        }
      } else {
        DispatchQueue.main.async {
          self.itemDetailsController[keyPath: keyPath] = .unavailable
        }
        group.leave()
      }
    }
  }
}

// MARK: - Configuration

extension ItemDetailsCoordinator {
  func updateNonRemoteProperties(with item: MediaItem) {
    self.detailItem = item
    configure(for: self.detailItem, resetRemoteProperties: false)
  }

  private func configure(for item: MediaItem, resetRemoteProperties: Bool) {
    itemDetailsController.itemTitle = item.title
    itemDetailsController.subtitle = item.subtitle
    itemDetailsController.genreIds = item.genreIds
    itemDetailsController.runtime = item.runtime
    itemDetailsController.releaseDate = item.releaseDate
    itemDetailsController.diskType = item.diskType
    if resetRemoteProperties {
      itemDetailsController.poster = .loading
      itemDetailsController.certification = .loading
      itemDetailsController.overview = .loading
    }
  }
}

// MARK: - ItemDetailsControllerDelegate

extension ItemDetailsCoordinator: ItemDetailsControllerDelegate {
  func itemDetailsControllerDidTapEdit(_ controller: ItemDetailsController) {
    editItemCoordinator = EditItemCoordinator(library: library, item: detailItem)
    editItemCoordinator!.delegate = self
    self.navigationController.present(editItemCoordinator!.rootViewController, animated: true)
  }

  func itemDetailsControllerDidDismiss(_ controller: ItemDetailsController) {
    self.delegate?.itemDetailsCoordinatorDidDismiss(self)
  }
}

extension ItemDetailsCoordinator: EditItemCoordinatorDelegate {
  func editItemCoordinator(_ coordinator: EditItemCoordinator,
                           didFinishEditingWithResult editResult: EditItemCoordinator.EditResult) {
    switch editResult {
      case let .edited(editedItem):
        updateNonRemoteProperties(with: editedItem)
        coordinator.rootViewController.dismiss(animated: true)
      case .deleted:
        coordinator.rootViewController.dismiss(animated: true) {
          self.navigationController.popViewController(animated: true)
          self.delegate?.itemDetailsCoordinatorDidDismiss(self)
        }
      case .canceled:
        coordinator.rootViewController.dismiss(animated: true)
    }
    self.editItemCoordinator = nil
  }

  func editItemCoordinator(_ coordinator: EditItemCoordinator, didFailWithError error: Error) {
    switch error {
      case MediaLibraryError.itemDoesNotExist:
        fatalError("tried to edit item which is not in library: \(detailItem)")
      default:
        DispatchQueue.main.async {
          let alert = UIAlertController(title: Utils.localizedErrorMessage(for: error),
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
