import CinemaKit
import CloudKit
import Dispatch
import MobileCoreServices
import os.log
import UIKit

protocol LibraryListCoordinatorDelegate: class {
  func libraryListCoordinatorDidFinish(_ coordinator: LibraryListCoordinator)
}

class LibraryListCoordinator: NSObject, CustomPresentableCoordinator {
  private static let logger = Logging.createLogger(category: "LibraryListCoordinator")
  var rootViewController: UIViewController {
    return navigationController
  }
  weak var delegate: LibraryListCoordinatorDelegate?
  private let dependencies: AppDependencies
  private let libraryManager: MovieLibraryManager
  private let notificationCenter: NotificationCenter
  private var libraryMetadataForCloudSharingController: MovieLibraryMetadata?
  private var sharingCallback: CloudSharingControllerCallback?
  private var pendingInvitations = Set<String>()

  // managed controller
  private let navigationController: UINavigationController
  private let libraryListController: LibraryListController
  private var librarySettingsController: LibrarySettingsController?

  init(dependencies: AppDependencies) {
    self.dependencies = dependencies
    self.libraryManager = dependencies.libraryManager
    self.notificationCenter = dependencies.notificationCenter
    self.libraryListController = UIStoryboard.libraryList.instantiate(LibraryListController.self)
    self.navigationController = UINavigationController(rootViewController: libraryListController)
    super.init()
    self.libraryListController.onDoneButtonTap = { [weak self] in
      self?.libraryListControllerDidTabDoneButton()
    }
    self.libraryListController.onSelection = { [weak self] metadata in
      self?.libraryListControllerDidSelect(metadata)
    }
    self.libraryListController.onAddLibraryButtonTap = { [weak self] in
      self?.libraryListControllerDidTapAddLibraryButton()
    }
    self.libraryManager.delegates.add(self)
    DispatchQueue.global(qos: .userInitiated).async {
      self.loadLibraries()
    }
  }
}

// MARK: - Data Loading

extension LibraryListCoordinator {
  private func loadLibraries() {
    libraryManager.fetchLibraries { result in
      switch result {
        case let .failure(error):
          switch error {
            case let .globalError(event):
              self.notificationCenter.post(event.notification)
            case .nonRecoverableError:
              fatalError("unable to load libraries")
            case .libraryDoesNotExist, .permissionFailure:
              fatalError("should not occur")
          }
        case let .success(libraries):
          DispatchQueue.main.async {
            self.libraryListController.setLibraries(libraries.map { $0.metadata })
          }
      }
    }
  }
}

// MARK: - Library List Controller Actions

extension LibraryListCoordinator {
  private func libraryListControllerDidTabDoneButton() {
    delegate?.libraryListCoordinatorDidFinish(self)
  }

  private func libraryListControllerDidSelect(_ metadata: MovieLibraryMetadata) {
    librarySettingsController = LibrarySettingsController(for: metadata)
    librarySettingsController!.onMetadataUpdate = { [weak self] metadata in
      guard let `self` = self else { return }
      self.updateMetadata(metadata)
    }
    librarySettingsController!.onShareButtonTap = { [weak self] in
      guard let `self` = self else { return }
      self.showCloudSharingController(for: self.librarySettingsController!.metadata)
    }
    librarySettingsController!.onRemoveLibrary = { [weak self] in
      guard let `self` = self else { return }
      self.removeLibrary(with: self.librarySettingsController!.metadata)
    }
    librarySettingsController!.onDisappear = { [weak self] in
      guard let `self` = self else { return }
      self.librarySettingsController = nil
    }
    librarySettingsController!.metadata = metadata
    self.navigationController.pushViewController(librarySettingsController!, animated: true)
  }

  private func libraryListControllerDidTapAddLibraryButton() {
    let alert = UIAlertController(title: NSLocalizedString("addLibrary.title", comment: ""),
                                  message: nil,
                                  preferredStyle: .alert)
    alert.addTextField { textField in
      textField.placeholder = NSLocalizedString("addLibrary.name.placeholder", comment: "")
      textField.autocapitalizationType = .words
    }
    alert.addAction(UIAlertAction(title: NSLocalizedString("save", comment: ""), style: .default) { _ in
      self.addLibrary(withName: alert.textFields!.first!.text ?? "")
    })
    alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel))
    self.rootViewController.present(alert, animated: true)
  }

  private func addLibrary(withName name: String) {
    if name.isEmpty { return }
    let metadata = MovieLibraryMetadata(name: name)
    self.libraryListController.showPlaceholder(for: metadata)
    DispatchQueue.global(qos: .userInitiated).async {
      self.libraryManager.addLibrary(with: metadata) { result in
        DispatchQueue.main.async {
          switch result {
            case let .failure(error):
              switch error {
                case let .globalError(event):
                  self.notificationCenter.post(event.notification)
                case .nonRecoverableError:
                  self.libraryListController.removeItem(for: metadata)
                  self.rootViewController.presentErrorAlert()
                case .libraryDoesNotExist, .permissionFailure:
                  fatalError("should not occur: \(error)")
              }
            case .success:
              self.libraryListController.showLibrary(with: metadata)
          }
        }
      }
    }
  }
}

// MARK: - Library Settings Controller Actions

extension LibraryListCoordinator {
  private func updateMetadata(_ metadata: MovieLibraryMetadata) {
    libraryListController.showPlaceholder(for: metadata)
    let originalMetadata = librarySettingsController!.metadata
    DispatchQueue.global(qos: .userInitiated).async {
      self.libraryManager.updateLibrary(with: metadata) { result in
        DispatchQueue.main.async {
          switch result {
            case let .failure(error):
              switch error {
                case let .globalError(event):
                  self.notificationCenter.post(event.notification)
                case .permissionFailure:
                  self.libraryListController.showLibrary(with: originalMetadata)
                  self.rootViewController.presentPermissionFailureAlert {
                    self.notificationCenter.post(ApplicationWideEvent.shouldFetchChanges.notification)
                  }
                case .nonRecoverableError:
                  self.libraryListController.showLibrary(with: originalMetadata)
                  self.rootViewController.presentErrorAlert()
                case .libraryDoesNotExist:
                  self.libraryListController.removeItem(for: metadata)
              }
            case .success:
              self.libraryListController.showLibrary(with: metadata)
          }
        }
      }
    }
  }

  private func showCloudSharingController(for metadata: MovieLibraryMetadata) {
    libraryMetadataForCloudSharingController = metadata
    libraryManager.prepareCloudSharingController(forLibraryWith: metadata) { result in
      switch result {
        case let .failure(error):
          switch error {
            case let .globalError(event):
              self.notificationCenter.post(event.notification)
            case .nonRecoverableError:
              DispatchQueue.main.async {
                self.rootViewController.presentErrorAlert()
              }
            case .libraryDoesNotExist:
              DispatchQueue.main.async {
                self.navigationController.popViewController(animated: true)
              }
            case .permissionFailure:
              fatalError("should not occur: \(error)")
          }
        case let .success(parameters):
          DispatchQueue.main.async {
            let sharingController: UICloudSharingController
            switch parameters {
              case let .hasNotBeenShared(preparationHandler, callback):
                sharingController = UICloudSharingController { _, closure in
                  preparationHandler(closure)
                }
                self.sharingCallback = callback
                sharingController.availablePermissions = [.allowPrivate, .allowReadOnly]
              case let .hasBeenShared(share, container, callback):
                sharingController = UICloudSharingController(share: share, container: container)
                self.sharingCallback = callback
                sharingController.availablePermissions = [.allowPrivate, .allowReadWrite, .allowReadOnly]
            }
            sharingController.delegate = self
            self.librarySettingsController!.present(sharingController, animated: true)
          }
      }
    }
  }

  private func removeLibrary(with metadata: MovieLibraryMetadata) {
    libraryListController.showPlaceholder(for: metadata)
    navigationController.popToViewController(self.libraryListController, animated: true)
    librarySettingsController = nil
    DispatchQueue.global(qos: .userInitiated).async {
      self.libraryManager.removeLibrary(with: metadata.id) { result in
        DispatchQueue.main.async {
          switch result {
            case let .failure(error):
              switch error {
                case let .globalError(event):
                  self.notificationCenter.post(event.notification)
                case .nonRecoverableError:
                  self.libraryListController.showLibrary(with: metadata)
                  self.rootViewController.presentErrorAlert()
                case .permissionFailure, .libraryDoesNotExist:
                  fatalError("should not occur: \(error)")
              }
            case .success:
              self.libraryListController.removeItem(for: metadata)
          }
        }
      }
    }
  }
}

// MARK: - Cloud Sharing Controller Delegate

extension LibraryListCoordinator: UICloudSharingControllerDelegate {
  func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
    os_log("sharing failed with error %{public}@",
           log: LibraryListCoordinator.logger,
           type: .error,
           String(describing: error))
    DispatchQueue.main.async {
      self.rootViewController.presentErrorAlert()
    }
  }

  func itemTitle(for csc: UICloudSharingController) -> String? {
    return libraryMetadataForCloudSharingController!.name
  }

  func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
    return NSDataAsset(name: "LibraryThumbnail")!.data
  }

  func itemType(for csc: UICloudSharingController) -> String? {
    return kUTTypeDatabase as String
  }

  func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
    sharingCallback!.didStopSharingLibrary(with: libraryMetadataForCloudSharingController!)
  }

  func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
    libraryManager.fetchChanges { result in
      if case let .failure(error) = result {
        switch error {
          case let .globalError(event):
            self.notificationCenter.post(event.notification)
          case .nonRecoverableError:
            os_log("unable to fetch changes after sharing controller did save share",
                   log: LibraryListCoordinator.logger,
                   type: .error)
          case .permissionFailure, .libraryDoesNotExist:
            fatalError("should not occur: \(error)")
        }
      }
    }
  }
}

// MARK: - Responding to library changes

extension LibraryListCoordinator: MovieLibraryManagerDelegate {
  func libraryManager(_ libraryManager: MovieLibraryManager,
                      didUpdateLibraries changeSet: ChangeSet<CKRecordID, MovieLibrary>) {
    DispatchQueue.main.async {
      for library in changeSet.insertions {
        self.libraryListController.showLibrary(with: library.metadata)
      }
      for (id, library) in changeSet.modifications {
        self.libraryListController.showLibrary(with: library.metadata)
        if let settingsController = self.librarySettingsController, settingsController.metadata.id == id {
          settingsController.metadata = library.metadata
        }
      }
      for (id, library) in changeSet.deletions {
        self.libraryListController.removeItem(for: library.metadata)
        if let settingsController = self.librarySettingsController, settingsController.metadata.id == id {
          if let sharingController = self.navigationController.presentedViewController,
             sharingController is UICloudSharingController {
            sharingController.dismiss(animated: true)
          }
          self.navigationController.popToViewController(self.libraryListController, animated: true)
        }
      }
    }
  }

  func libraryManager(_ libraryManager: MovieLibraryManager,
                      willAcceptSharedLibraryWith title: String,
                      continuation: @escaping () -> Void) {
    DispatchQueue.main.async {
      self.pendingInvitations.insert(title)
      self.libraryListController.setInvitation(title)
      continuation()
    }
  }

  func libraryManager(_ libraryManager: MovieLibraryManager,
                      didAcceptSharedLibrary library: MovieLibrary,
                      with title: String) {
    DispatchQueue.main.async {
      if self.pendingInvitations.contains(title) {
        self.pendingInvitations.remove(title)
        self.libraryListController.replaceInvitation(with: title, by: library.metadata)
      } else {
        self.libraryListController.showLibrary(with: library.metadata)
      }
    }
  }
}
