import CinemaKit
import Dispatch
import UIKit

protocol EditItemCoordinatorDelegate: class {
  func editItemCoordinator(_ coordinator: EditItemCoordinator,
                           didFinishEditingWithResult editResult: EditItemCoordinator.EditResult)
  func editItemCoordinator(_ coordinator: EditItemCoordinator, didFailWithError error: Error)
}

class EditItemCoordinator: CustomPresentableCoordinator {
  typealias Dependencies = LibraryDependency

  // coordinator stuff
  var rootViewController: UIViewController {
    return navigationController
  }
  weak var delegate: EditItemCoordinatorDelegate?

  // other properties
  private let dependencies: Dependencies
  private var library: MediaLibrary {
    return dependencies.library
  }
  private var itemToEdit: MediaItem

  // managed controller
  private let navigationController: UINavigationController
  private let editItemController = UIStoryboard.editItem.instantiate(EditItemController.self)

  enum EditResult {
    case canceled
    case edited(MediaItem)
    case deleted
  }

  init(item: MediaItem, dependencies: Dependencies) {
    self.dependencies = dependencies
    self.itemToEdit = item
    navigationController = UINavigationController(rootViewController: editItemController)
    editItemController.delegate = self
    editItemController.itemTitle = itemToEdit.title
    editItemController.subtitle = itemToEdit.subtitle
  }
}

extension EditItemCoordinator: EditItemControllerDelegate {
  func editItemController(_ controller: EditItemController,
                          shouldAcceptEdits edits: Set<EditItemController.Edit>) -> EditItemController.EditApproval {
    for edit in edits {
      switch edit {
        case let .titleChange(newTitle):
          if newTitle.isEmpty {
            return .rejected(reason: NSLocalizedString("edit.noTitleAlert", comment: ""))
          }
        case .subtitleChange:
          break
      }
    }
    return .accepted
  }

  func editItemControllerDidCancelEditing(_ controller: EditItemController) {
    self.delegate?.editItemCoordinator(self, didFinishEditingWithResult: .canceled)
  }

  func editItemController(_ controller: EditItemController,
                          didFinishEditingWithResult editResult: EditItemController.EditResult) {
    controller.navigationItem.leftBarButtonItem!.isEnabled = false
    controller.view.isUserInteractionEnabled = false
    let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
    activityIndicator.startAnimating()
    controller.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: activityIndicator)
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        switch editResult {
          case let .edited(edits):
            var item = self.itemToEdit
            self.applyEdits(edits, to: &item)
            try self.library.update(item)
            DispatchQueue.main.async {
              self.delegate?.editItemCoordinator(self, didFinishEditingWithResult: .edited(item))
            }
          case .deleted:
            try self.library.remove(self.itemToEdit)
            DispatchQueue.main.async {
              self.delegate?.editItemCoordinator(self, didFinishEditingWithResult: .deleted)
            }
        }
      } catch {
        DispatchQueue.main.async {
          self.delegate?.editItemCoordinator(self, didFailWithError: error)
        }
      }
    }
  }

  private func applyEdits(_ edits: Set<EditItemController.Edit>, to item: inout MediaItem) {
    for edit in edits {
      switch edit {
        case let .titleChange(newTitle): item.title = newTitle
        case let .subtitleChange(newSubtitle): item.subtitle = newSubtitle
      }
    }
  }
}