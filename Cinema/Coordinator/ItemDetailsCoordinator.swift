import Dispatch
import Foundation
import UIKit

protocol ItemDetailsCoordinatorDelegate: class {
  func itemDetailsCoordinatorDidDismiss(_ coordinator: ItemDetailsCoordinator)
}

class ItemDetailsCoordinator: CustomPresentableCoordinator {
  typealias Dependencies = MovieDbDependency

  // coordinator stuff
  var rootViewController: UIViewController {
    return itemDetailsController
  }
  weak var delegate: ItemDetailsCoordinatorDelegate?

  // other properties
  private let dependencies: Dependencies
  private var movieDb: MovieDbClient {
    return dependencies.movieDb
  }
  private(set) var detailItem: MediaItem

  // managed controller
  private var itemDetailsController: ItemDetailsController

  init(detailItem: MediaItem, dependencies: Dependencies) {
    self.dependencies = dependencies
    self.detailItem = detailItem

    itemDetailsController = UIStoryboard.movieList.instantiate(ItemDetailsController.self)
    itemDetailsController.delegate = self
    configure(for: self.detailItem, resetRemoteProperties: true)
    fetchRemoteData(for: self.detailItem.id)
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
  func itemDetailsControllerDidDismiss(_ controller: ItemDetailsController) {
    self.delegate?.itemDetailsCoordinatorDidDismiss(self)
  }
}
