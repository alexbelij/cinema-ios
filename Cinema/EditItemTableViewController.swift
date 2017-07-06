import UIKit

class EditItemTableViewController: UITableViewController {

  var item: MediaItem!
  var library: MediaLibrary!

  @IBOutlet weak var titleTextField: UITextField!
  @IBOutlet weak var subtitleTextField: UITextField!

  override func viewDidLoad() {
    super.viewDidLoad()
    titleTextField.text = item.title
    subtitleTextField.text = item.subtitle
  }

  @IBAction func cancelButtonClicked() {
    self.dismiss(animated: true)
  }

  @IBAction func doneButtonClicked() {
    self.acceptEdits()
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
    return MediaItem(id: self.item!.id,
                     title: self.titleTextField.text!,
                     subtitle: subtitle,
                     runtime: self.item!.runtime,
                     year: self.item!.year,
                     diskType: self.item!.diskType)
  }

  private func showCancelOrDiscardAlert(title: String) {
    let alertController = UIAlertController(title: title,
                                            message: nil,
                                            preferredStyle: .alert)
    alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
    alertController.addAction(UIAlertAction(title: NSLocalizedString("Discard", comment: ""), style: .destructive,
                                            handler: { _ in
                                              self.dismiss(animated: true)
                                            }))
    self.present(alertController, animated: true)
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
