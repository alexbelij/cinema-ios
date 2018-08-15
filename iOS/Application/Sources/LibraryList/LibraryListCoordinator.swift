import CinemaKit
import Dispatch
import UIKit

class LibraryListCoordinator: CustomPresentableCoordinator {
  var rootViewController: UIViewController {
    return navigationController
  }
  private let dependencies: AppDependencies
  private let libraryManager: MovieLibraryManager

  // managed controller
  private let navigationController: UINavigationController
  private let libraryListController: LibraryListController

  init(dependencies: AppDependencies) {
    self.dependencies = dependencies
    self.libraryManager = dependencies.libraryManager
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
    let settingsController = UIStoryboard.libraryList.instantiate(LibrarySettingsController.self)
    settingsController.onMetadataUpdate = { [weak self] in
      self?.librarySettingsControllerDidUpdateMetadata(settingsController)
    }
    settingsController.onRemoveButtonTap = { [weak self] in
      self?.librarySettingsControllerDidTapRemoveButton(settingsController)
    }
    settingsController.metadata = metadata
    settingsController.canRemoveLibrary = libraryManager.libraryCount > 1
    self.navigationController.pushViewController(settingsController, animated: true)
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
    self.libraryListController.addPlaceholder(for: metadata)
    DispatchQueue.global(qos: .userInitiated).async {
      self.libraryManager.addLibrary(with: metadata) { result in
        DispatchQueue.main.async {
          switch result {
            case .success:
              self.libraryListController.hidePlaceholder(for: metadata)
          }
        }
      }
    }
  }
}

// MARK: - Library Settings Controller Actions

extension LibraryListCoordinator {
  private func librarySettingsControllerDidUpdateMetadata(_ controller: LibrarySettingsController) {
    let metadata = controller.metadata!
    libraryListController.showPlaceholder(for: metadata)
    DispatchQueue.global(qos: .userInitiated).async {
      self.libraryManager.updateLibrary(with: metadata) { result in
        switch result {
          case .success:
            DispatchQueue.main.async {
              self.libraryListController.hidePlaceholder(for: metadata)
            }
        }
      }
    }
  }

  private func librarySettingsControllerDidTapRemoveButton(_ controller: LibrarySettingsController) {
    let metadata = controller.metadata!
    libraryListController.showPlaceholder(for: metadata)
    navigationController.popViewController(animated: true)
    DispatchQueue.global(qos: .userInitiated).async {
      self.libraryManager.removeLibrary(with: metadata.id) { result in
        DispatchQueue.main.async {
          switch result {
            case .success:
              self.libraryListController.removePlaceholder(for: metadata)
          }
        }
      }
    }
  }
}
