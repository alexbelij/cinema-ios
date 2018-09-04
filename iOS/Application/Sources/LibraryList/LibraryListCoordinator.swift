import CinemaKit
import CloudKit
import Dispatch
import UIKit

class LibraryListCoordinator: CustomPresentableCoordinator {
  var rootViewController: UIViewController {
    return navigationController
  }
  private let dependencies: AppDependencies
  private let libraryManager: MovieLibraryManager
  private let notificationCenter: NotificationCenter

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
            case .libraryDoesNotExist:
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
    self.navigationController.dismiss(animated: true)
  }

  private func libraryListControllerDidSelect(_ metadata: MovieLibraryMetadata) {
    librarySettingsController = UIStoryboard.libraryList.instantiate(LibrarySettingsController.self)
    librarySettingsController!.onMetadataUpdate = { [weak self] metadata in
      guard let `self` = self else { return }
      self.updateMetadata(metadata)
    }
    librarySettingsController!.onRemoveLibrary = { [weak self] in
      guard let `self` = self else { return }
      self.removeLibrary(with: self.librarySettingsController!.metadata!)
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
                case .libraryDoesNotExist:
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
    let originalMetadata = librarySettingsController!.metadata!
    DispatchQueue.global(qos: .userInitiated).async {
      self.libraryManager.updateLibrary(with: metadata) { result in
        DispatchQueue.main.async {
          switch result {
            case let .failure(error):
              switch error {
                case let .globalError(event):
                  self.notificationCenter.post(event.notification)
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
                case .libraryDoesNotExist:
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
          self.navigationController.popToViewController(self.libraryListController, animated: true)
        }
      }
    }
  }
}