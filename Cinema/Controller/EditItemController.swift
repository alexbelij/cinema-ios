import UIKit

class EditItemController: UITableViewController {

  var item: MediaItem!
  var library: MediaLibrary!

  @IBOutlet private weak var titleTextField: UITextField!
  @IBOutlet private weak var subtitleTextField: UITextField!
  @IBOutlet private weak var deleteMovieButton: UIButton!

}

// MARK: - View Controller Lifecycle

extension EditItemController {
  override func viewDidLoad() {
    super.viewDidLoad()
    titleTextField.text = item.title
    titleTextField.delegate = self
    subtitleTextField.text = item.subtitle
    subtitleTextField.delegate = self
    deleteMovieButton.setTitle(NSLocalizedString("edit.deleteMovie", comment: ""), for: .normal)
  }
}

// MARK: - Table View

extension EditItemController {
  public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    switch section {
      case 0: return NSLocalizedString("edit.sectionHeader.title", comment: "")
      case 1: return NSLocalizedString("edit.sectionHeader.subtitle", comment: "")
      default: return nil
    }
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

// MARK: - Edit Management

extension EditItemController {
  private func acceptEdits() {
    if isValidEdit() {
      guard titleTextField.text != item.title
            || subtitleTextField.text != item.subtitle else {
        self.dismiss(animated: true)
        return
      }

      item.title = self.titleTextField.text!
      var subtitle = self.subtitleTextField.text
      if subtitle != nil && subtitle!.isEmpty {
        subtitle = nil
      }
      item.subtitle = subtitle

      DispatchQueue.global(qos: .userInitiated).async {
        self.performLibraryUpdate { try self.library.update(self.item) }
      }
    } else {
      let alertController = UIAlertController(title: NSLocalizedString("edit.noTitleAlert", comment: ""),
                                              message: nil,
                                              preferredStyle: .alert)
      alertController.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default))
      self.present(alertController, animated: true)
    }
  }

  private func isValidEdit() -> Bool {
    guard let newTitle = titleTextField.text else { return false }
    return !newTitle.isEmpty
  }

  private func performLibraryUpdate(action: @escaping () throws -> Void) {
    do {
      try action()
      DispatchQueue.main.async {
        self.dismiss(animated: true)
      }
    } catch let error {
      switch error {
        case MediaLibraryError.itemDoesNotExist:
          fatalError("updating non-existing item \(self.item)")
        default:
          DispatchQueue.main.async {
            self.showCancelOrDiscardAlert(title: Utils.localizedErrorMessage(for: error))
          }
      }
    }
  }

  private func showCancelOrDiscardAlert(title: String) {
    let alertController = UIAlertController(title: title,
                                            message: nil,
                                            preferredStyle: .alert)
    alertController.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel))
    alertController.addAction(UIAlertAction(title: NSLocalizedString("discard", comment: ""),
                                            style: .destructive) { _ in
      self.dismiss(animated: true)
    })
    self.present(alertController, animated: true)
  }
}

// MARK: - User Actions

extension EditItemController {
  @IBAction func cancelButtonClicked() {
    self.dismiss(animated: true)
  }

  @IBAction func doneButtonClicked() {
    self.acceptEdits()
  }

  @IBAction func deleteButtonClicked() {
    let alertController = UIAlertController(title: nil,
                                            message: nil,
                                            preferredStyle: .actionSheet)
    alertController.addAction(UIAlertAction(title: NSLocalizedString("edit.deleteMovie", comment: ""),
                                            style: .destructive) { _ in
      DispatchQueue.global(qos: .userInitiated).async {
        self.performLibraryUpdate { try self.library.remove(self.item) }
      }
    })
    alertController.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel))
    self.present(alertController, animated: true)
  }

  @IBAction private func dismissKeyboard() {
    self.view?.endEditing(false)
  }
}
