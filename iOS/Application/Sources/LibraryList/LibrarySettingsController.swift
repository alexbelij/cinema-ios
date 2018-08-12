import CinemaKit
import UIKit

class LibrarySettingsController: UITableViewController {
  var metadata: MovieLibraryMetadata! {
    didSet {
      guard metadata != nil else { preconditionFailure("metadata has not been set") }
      guard isViewLoaded else { return }
      configure(for: metadata)
    }
  }
  var canRemoveLibrary = true {
    didSet {
      guard isViewLoaded else { return }
      removeLibraryButton.isEnabled = canRemoveLibrary
    }
  }
  var onMetadataUpdate: (() -> Void)?
  var onRemoveButtonTap: (() -> Void)?

  @IBOutlet private weak var nameTextField: UITextField!
  @IBOutlet private weak var removeLibraryButton: UIButton!
  @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
  private var shouldIgnoreEdits = false
}

// MARK: - View Controller Lifecycle

extension LibrarySettingsController {
  override func viewDidLoad() {
    super.viewDidLoad()
    nameTextField.delegate = self
    removeLibraryButton.setTitle(NSLocalizedString("librarySettings.removeLibrary", comment: ""), for: .normal)
    removeLibraryButton.isEnabled = canRemoveLibrary
    guard metadata != nil else { preconditionFailure("libraryMetadata has not been set") }
    configure(for: metadata)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    if !shouldIgnoreEdits && nameTextField.text != metadata.name {
      metadata.name = nameTextField.text!
      onMetadataUpdate?()
    }
  }
}

// MARK: - Setup

extension LibrarySettingsController {
  private func configure(for metadata: MovieLibraryMetadata) {
    nameTextField.text = metadata.name
  }
}

// MARK: - UITextFieldDelegate

extension LibrarySettingsController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    nameTextField.resignFirstResponder()
    return false
  }

  @IBAction private func textFieldDidChange(_ textField: UITextField) {
    let isTextFieldEmpty = textField.text?.isEmpty ?? true
    navigationItem.setHidesBackButton(isTextFieldEmpty, animated: true)
  }
}

// MARK: - Table View

extension LibrarySettingsController {
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    switch section {
      case 0: return NSLocalizedString("librarySettings.nameSection.header", comment: "")
      default: return nil
    }
  }
}

// MARK: - User Actions

extension LibrarySettingsController {
  @IBAction private func deleteLibraryButtonTapped() {
    view.endEditing(false)
    let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
    let format = NSLocalizedString("librarySettings.removeLibrary.format", comment: "")
    let name = nameTextField.text?.nilIfEmptyString ?? metadata.name
    alert.addAction(UIAlertAction(title: .localizedStringWithFormat(format, name),
                                  style: .destructive) { _ in
      self.shouldIgnoreEdits = true
      self.onRemoveButtonTap?()
    })
    alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel))
    present(alert, animated: true)
  }
}
