import UIKit

class EditItemTableViewController: UITableViewController, UITextFieldDelegate {

  var item: MediaItem!
  var library: MediaLibrary!

  @IBOutlet private weak var titleTextField: UITextField!
  @IBOutlet private weak var subtitleTextField: UITextField!
  @IBOutlet private weak var deleteMovieButton: UIButton!

  override func viewDidLoad() {
    super.viewDidLoad()
    titleTextField.text = item.title
    titleTextField.delegate = self
    subtitleTextField.text = item.subtitle
    subtitleTextField.delegate = self
    deleteMovieButton.setTitle(NSLocalizedString("edit.deleteMovie", comment: ""), for: .normal)
  }

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
      self.deleteItem()
    })
    alertController.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel))
    self.present(alertController, animated: true)
  }

  private func acceptEdits() {
    if isValidEdit() {
      guard titleTextField.text != item.title
            || subtitleTextField.text != item.subtitle else {
        self.dismiss(animated: true)
        return
      }
      let newMediaItem = self.collectInfos()
      DispatchQueue.global(qos: .userInitiated).async {
        var libraryError: Error? = nil
        do {
          try self.library.update(newMediaItem)
        } catch let error {
          libraryError = error
        }
        DispatchQueue.main.async {
          if libraryError == nil {
            self.dismiss(animated: true)
          } else {
            switch libraryError! {
              case MediaLibraryError.itemDoesNotExist:
                fatalError("updating non-existing item \(newMediaItem)")
              case MediaLibraryError.storageError:
                self.showCancelOrDiscardAlert(title: NSLocalizedString("error.storageError", comment: ""))
              default:
                self.showCancelOrDiscardAlert(title: NSLocalizedString("error.genericError", comment: ""))
            }
          }
        }
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

  private func collectInfos() -> MediaItem {
    var subtitle = self.subtitleTextField.text
    if subtitle != nil && subtitle!.isEmpty {
      subtitle = nil
    }
    return MediaItem(id: self.item.id,
                     title: self.titleTextField.text!,
                     subtitle: subtitle,
                     runtime: self.item.runtime,
                     releaseDate: self.item.releaseDate,
                     diskType: self.item.diskType,
                     genreIds: self.item.genreIds)
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

  @IBAction private func dismissKeyboard() {
    self.view?.endEditing(false)
  }

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
      if let nextField = self.view.viewWithTag(textField.tag + 1) as? UITextField {
        nextField.becomeFirstResponder()
      } else {
        textField.resignFirstResponder()
      }
      return false
  }

  private func deleteItem() {
    DispatchQueue.global(qos: .userInitiated).async {
      var libraryError: Error? = nil
      do {
        try self.library.remove(self.item)
      } catch let error {
        libraryError = error
      }
      DispatchQueue.main.async {
        if libraryError == nil {
          self.dismiss(animated: true)
        } else {
          switch libraryError! {
            case MediaLibraryError.itemDoesNotExist:
              fatalError("updating non-existing item \(self.item)")
            case MediaLibraryError.storageError:
              self.showCancelOrDiscardAlert(title: NSLocalizedString("error.storageError", comment: ""))
            default:
              self.showCancelOrDiscardAlert(title: NSLocalizedString("error.genericError", comment: ""))
          }
        }
      }
    }
  }

  // MARK: - Table View

  public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    switch section {
      case 0: return NSLocalizedString("edit.sectionHeader.title", comment: "")
      case 1: return NSLocalizedString("edit.sectionHeader.subtitle", comment: "")
      default: return nil
    }
  }
}
