import Foundation
import UIKit

protocol EditItemControllerDelegate: class {
  func editItemController(_ controller: EditItemController,
                          shouldAcceptEdits edits: Set<EditItemController.Edit>) -> EditItemController.EditApproval
  func editItemControllerDidCancelEditing(_ controller: EditItemController)
  func editItemController(_ controller: EditItemController,
                          didFinishEditingWithResult editResult: EditItemController.EditResult)
}

class EditItemController: UITableViewController {
  weak var delegate: EditItemControllerDelegate?

  var itemTitle: String = "" {
    didSet {
      self.loadViewIfNeeded()
      self.titleTextField.text = itemTitle
    }
  }
  @IBOutlet private weak var titleTextField: UITextField!

  var subtitle: String? {
    didSet {
      self.loadViewIfNeeded()
      self.subtitleTextField.text = subtitle
    }
  }
  @IBOutlet private weak var subtitleTextField: UITextField!

  @IBOutlet private weak var deleteMovieButton: UIButton!

  enum Edit: Hashable {
    case titleChange(String)
    case subtitleChange(String?)

    var hashValue: Int {
      switch self {
        case .titleChange: return 0
        case .subtitleChange: return 1
      }
    }
  }

  enum EditResult {
    case edited(Set<Edit>)
    case deleted
  }

  enum EditApproval {
    case accepted
    case rejected(reason: String)
  }
}

// MARK: - View Controller Lifecycle

extension EditItemController {
  override func viewDidLoad() {
    super.viewDidLoad()
    titleTextField.delegate = self
    subtitleTextField.delegate = self
    deleteMovieButton.setTitle(NSLocalizedString("edit.deleteMovie", comment: ""), for: .normal)

    reassign(property: \EditItemController.itemTitle)
    reassign(property: \EditItemController.subtitle)
  }

  private func reassign<Type>(property: ReferenceWritableKeyPath<EditItemController, Type>) {
    let value = self[keyPath: property]
    self[keyPath: property] = value
  }
}

// MARK: - Table View

extension EditItemController {
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    switch section {
      case 0: return NSLocalizedString("edit.sectionHeader.title", comment: "")
      case 1: return NSLocalizedString("edit.sectionHeader.subtitle", comment: "")
      default: return nil
    }
  }
}

// MARK: - Edit Management

extension EditItemController {
  private var allEdits: Set<Edit> {
    var edits = [Edit]()
    let newTitle = self.titleTextField.text ?? ""
    if newTitle != itemTitle {
      edits.append(.titleChange(newTitle))
    }
    let newSubtitle = self.subtitleTextField.text?.nilIfEmptyString
    if newSubtitle != subtitle {
      edits.append(.subtitleChange(newSubtitle))
    }
    return Set(edits)
  }
}

// MARK: - UITextFieldDelegate

extension EditItemController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    if let nextField = self.view.viewWithTag(textField.tag + 1) as? UITextField {
      nextField.becomeFirstResponder()
    } else {
      textField.resignFirstResponder()
    }
    return false
  }
}

// MARK: - User Actions

extension EditItemController {
  @IBAction private func cancelButtonClicked() {
    delegate?.editItemControllerDidCancelEditing(self)
  }

  @IBAction private func doneButtonClicked() {
    guard let delegate = self.delegate else { return }
    let edits = self.allEdits
    if edits.isEmpty {
      delegate.editItemControllerDidCancelEditing(self)
    } else {
      switch delegate.editItemController(self, shouldAcceptEdits: edits) {
        case .accepted:
          delegate.editItemController(self, didFinishEditingWithResult: .edited(edits))
        case let .rejected(reason):
          let alert = UIAlertController(title: NSLocalizedString("edit.rejected.title", comment: ""),
                                        message: reason,
                                        preferredStyle: .alert)
          alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default))
          self.present(alert, animated: true)
      }
    }
  }

  @IBAction private func deleteButtonClicked() {
    let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
    alert.addAction(UIAlertAction(title: NSLocalizedString("edit.deleteMovie", comment: ""),
                                  style: .destructive) { _ in
      self.delegate?.editItemController(self, didFinishEditingWithResult: .deleted)
    })
    alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel))
    self.present(alert, animated: true)
  }

  @IBAction private func dismissKeyboard() {
    self.view?.endEditing(false)
  }
}
